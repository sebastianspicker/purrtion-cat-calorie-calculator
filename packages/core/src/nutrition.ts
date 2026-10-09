import type { Cat, EnergyEstimate, Food, NutritionNoteCode, NutritionResult, NutritionWarningCode } from './models.js';
import { atwaterKcalPer100g, nfe } from './food-analysis.js';
import { model } from './generated/model.js';
const n = model.nutrition;

/** Grams eaten per food: fixed meals plus the rounded balance ration. */
export interface FoodIntake { food: Food; grams: number }
/** Nutrient checks for one cat (ENGINE.md §7). `kcal` is energy from foods, i.e. rounded daily kcal minus extras. */
export function checkNutrition(cat: Cat, estimate: EnergyEstimate, intake: FoodIntake[], kcal: number): NutritionResult {
  if (estimate.status !== 'ok' && estimate.status !== 'reference-only') return { status: 'not-applicable' };
  const used = intake.filter(item => item.grams > 0);
  const missingFoodIds = [...new Set(used.filter(item => !item.food.analysis).map(item => item.food.id))].sort();
  if (missingFoodIds.length || kcal <= 0) return { status: 'incomplete-data', missingFoodIds };
  // Carbohydrate share on the Atwater basis in numerator and denominator (D6).
  let proteinG = 0, carbAtwater = 0, atwater = 0;
  for (const { food, grams } of used) {
    proteinG += grams * food.analysis!.protein / 100;
    carbAtwater += grams * model.food.atwaterNfe * nfe(food.analysis!);
    atwater += grams * atwaterKcalPer100g(food.analysis!);
  }
  const stage = estimate.stage, growth = stage === 'kitten' || stage === 'gestation' || stage === 'lactation';
  const weight = estimate.weightUsedKg ?? cat.weightKg;
  const minProteinPer1000 = stage === 'kitten' ? n.growthMinProteinPer1000
    : stage === 'gestation' || stage === 'lactation' ? n.reproductionMinProteinPer1000
    : Math.max(n.adultMinProteinPer1000, n.proteinRequirementPer1000 / (kcal / Math.pow(weight, model.mer.exponent)));
  const proteinPer1000 = proteinG / kcal * 1000, carbPercentME = atwater > 0 ? carbAtwater / atwater * 100 : 0;
  const ckd = cat.profile.medical.includes('ckd');
  const warnings: NutritionWarningCode[] = [], notes: NutritionNoteCode[] = [];
  // Protein for a CKD cat is the veterinarian's decision: the minimum is shown, not checked.
  if (proteinPer1000 < minProteinPer1000 && !ckd) warnings.push('protein-below-minimum');
  if (estimate.equation === 'weight-loss-aaha' && proteinG < n.lossProteinGPerKgIdeal * estimate.idealWeight!.kg)
    warnings.push('protein-below-5g-per-kg-ibw');
  if (cat.profile.medical.includes('diabetes') && carbPercentME > n.diabeticCarbPercentMe) warnings.push('carb-above-diabetic-threshold');
  if (growth && used.some(item => item.food.lifeStageClaim !== 'growth' && item.food.lifeStageClaim !== 'all'))
    warnings.push('growth-claim-missing');
  if (ckd) notes.push('ckd-protein-vet');
  return { status: 'ok', kcal, proteinG, proteinPer1000, minProteinPer1000, carbPercentME, warnings: warnings.sort(), notes };
}
