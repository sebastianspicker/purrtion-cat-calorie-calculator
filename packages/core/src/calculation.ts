import type { Activity, BalanceByFood, CalculateOptions, Cat, CatResult, Food, EnergyUnit, Plan, PlanResult, WarningCode } from './models.js';
import { PlanError, parsePlan } from './validation.js';
import { isISODate } from './dates.js';
import { analyseFood, labelKcalPerGram, meKcalPer100g } from './food-analysis.js';
import { estimateEnergy, rer, stageOf } from './estimator.js';
import { trendFor, trendStops, weightSeries } from './trend.js';
import { checkNutrition, type FoodIntake } from './nutrition.js';
import { model } from './generated/model.js';
export const KJ_PER_KCAL = model.units.kjPerKcal;
/** All internal arithmetic uses kcal and grams, with no intermediate rounding. Analysis-sourced energy uses ME4 (ENGINE.md §4). */
export function kcalPerGram(food: Pick<Food, 'energyPerUnit' | 'energyUnit'> & Partial<Pick<Food, 'energySource' | 'analysis'>>): number {
  if (food.energySource === 'analysis' && food.analysis) return meKcalPer100g(food.analysis) / 100;
  if (food.energyPerUnit === null) throw new RangeError('Food energy is missing');
  return labelKcalPerGram(food.energyPerUnit, food.energyUnit);
}
export function energyInUnit(food: Pick<Food, 'energyPerUnit' | 'energyUnit'> & Partial<Pick<Food, 'energySource' | 'analysis'>>, unit: EnergyUnit): number {
  return kcalPerGram(food) * (unit.endsWith('/kg') ? 1000 : 100) * (unit.startsWith('kJ') ? KJ_PER_KCAL : 1);
}
/** Largest remainder allocation: rounded activity grams sum exactly to each cat’s rounded ration. */
export function allocateRounded(totalGrams: number, activities: Activity[]): number[] {
  if (!Number.isFinite(totalGrams) || totalGrams < 0 || totalGrams > 1_000_000 || !activities.length
      || activities.some(a => !Number.isFinite(a.sharePercent) || a.sharePercent < 0 || a.sharePercent > 100)
      || Math.abs(activities.reduce((n, a) => n + a.sharePercent, 0) - 100) > 1e-6)
    throw new RangeError('A nonnegative amount and activity shares totaling 100% are required');
  const total = Math.round(totalGrams);
  const raw = activities.map(a => total * a.sharePercent / 100);
  const portions = raw.map(Math.floor);
  const remaining = total - portions.reduce((a, b) => a + b, 0);
  const order = raw.map((value, index) => ({ index, remainder: value - Math.floor(value) }))
    .sort((a, b) => b.remainder - a.remainder || a.index - b.index);
  for (let n = 0; n < remaining; n++) {
    const item = order[n % order.length];
    if (item) portions[item.index] = (portions[item.index] ?? 0) + 1;
  }
  return portions;
}
function calculateCat(cat: Cat, plan: Plan, foods: Map<string, Food>, asOf: string): CatResult {
  const balance = foods.get(cat.balanceFoodId)!; // References were validated at the public boundary.
  const warnings = new Set<WarningCode>();
  const intake: FoodIntake[] = [];
  let fixedGrams = 0, fixedKcal = 0, complementaryKcal = cat.extraKcal;
  const inspect = (food: Food, consumedKcal: number): void => {
    if (consumedKcal <= 0) return;
    // Energy computed from an analysis is an estimate too (SCIENCE.md §10.2).
    if (food.energySource === 'estimate' || food.energySource === 'analysis') warnings.add('estimated-energy');
    if (food.completeness === 'unknown') warnings.add('unknown-completeness');
    if (food.completeness === 'complementary') complementaryKcal += consumedKcal;
  };
  for (const meal of cat.meals) {
    const food = foods.get(meal.foodId)!;
    const calories = meal.grams * kcalPerGram(food);
    fixedGrams += meal.grams; fixedKcal += calories; inspect(food, calories);
    intake.push({ food, grams: meal.grams });
  }
  const remaining = cat.targetKcal - fixedKcal - cat.extraKcal;
  const balanceKcal = Math.max(0, remaining);
  const balanceGramsExact = balanceKcal / kcalPerGram(balance);
  const balanceGramsRounded = Math.round(balanceGramsExact);
  inspect(balance, balanceGramsRounded * kcalPerGram(balance));
  intake.push({ food: balance, grams: balanceGramsRounded });
  if (balanceGramsRounded > 0 && balance.completeness === 'complementary') warnings.add('complementary-balance-food');
  if (cat.targetSource === 'provisional') warnings.add('provisional-target');
  if (complementaryKcal > cat.targetKcal * model.allocation.extrasMaxFraction + 1e-8) warnings.add('extras-over-10-percent');
  if (remaining < -1e-8) warnings.add('over-budget');
  const rounded = allocateRounded(balanceGramsExact, plan.activities);
  const roundedDailyKcal = fixedKcal + cat.extraKcal + balanceGramsRounded * kcalPerGram(balance);
  const series = weightSeries(cat, asOf);
  const estimate = estimateEnergy(cat, asOf, trendStops(cat, series, stageOf(cat, asOf)));
  return { id: cat.id, fixedGrams, fixedKcal, extraKcal: cat.extraKcal, balanceFoodId: balance.id, balanceKcal,
    balanceGramsExact, balanceGramsRounded, overBudgetKcal: Math.max(0, -remaining), roundedDailyKcal,
    rerKcal: rer(cat.weightKg), warnings: [...warnings].sort(),
    activities: plan.activities.map((a, i) => ({ ...a, exactGrams: balanceGramsExact * a.sharePercent / 100, roundedGrams: rounded[i] ?? 0 })),
    estimate, trend: trendFor(cat, asOf, estimate, series),
    nutrition: checkNutrition(cat, estimate, intake, roundedDailyKcal - cat.extraKcal),
  };
}
/** Validates the plan and calculates every cat. `asOf` (YYYY-MM-DD) keeps the core pure and deterministic. Never changes `targetKcal`. */
export function calculatePlan(input: unknown, options: CalculateOptions): PlanResult {
  if (!options || !isISODate(options.asOf)) throw new PlanError('asOf', 'expected a valid date in the form YYYY-MM-DD');
  const plan = parsePlan(input), asOf = options.asOf;
  const foods = new Map(plan.foods.map(f => [f.id, f]));
  const cats = plan.cats.map(cat => calculateCat(cat, plan, foods, asOf));
  const balanceByFood: BalanceByFood[] = [];
  for (const c of cats) {
    let entry = balanceByFood.find(b => b.foodId === c.balanceFoodId);
    if (!entry) balanceByFood.push(entry = { foodId: c.balanceFoodId, gramsExact: 0, gramsRounded: 0 });
    entry.gramsExact += c.balanceGramsExact; entry.gramsRounded += c.balanceGramsRounded;
  }
  return { cats, foods: plan.foods.map(f => ({ id: f.id, kcalPerGram: kcalPerGram(f), analysis: analyseFood(f) })), totals: {
    fixedGrams: cats.reduce((n, c) => n + c.fixedGrams, 0),
    fixedKcal: cats.reduce((n, c) => n + c.fixedKcal, 0),
    targetKcal: plan.cats.reduce((n, c) => n + c.targetKcal, 0),
    balanceGramsExact: cats.reduce((n, c) => n + c.balanceGramsExact, 0),
    // Sum the containers that people actually prepare. Do not round the exact household sum instead.
    balanceGramsRounded: cats.reduce((n, c) => n + c.balanceGramsRounded, 0),
    roundedDailyKcal: cats.reduce((n, c) => n + c.roundedDailyKcal, 0),
    balanceByFood,
  } };
}
