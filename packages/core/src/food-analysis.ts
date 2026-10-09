import type { Analysis, EnergyUnit, Food, FoodAnalysisResult, FoodWarningCode } from './models.js';
import { model } from './generated/model.js';
const f = model.food;
/** v1 label conversion: per-100 g ÷ 100, per-kg ÷ 1000, kJ additionally ÷ 4.184. */
export function labelKcalPerGram(energyPerUnit: number, unit: EnergyUnit): number {
  return energyPerUnit / (unit.endsWith('/kg') ? 1000 : 100) / (unit.startsWith('kJ') ? model.units.kjPerKcal : 1);
}
export function moistureUsed(analysis: Analysis): number { return analysis.moisture ?? f.assumedDryMoisture; }
export function nfe(analysis: Analysis): number {
  return Math.max(0, 100 - moistureUsed(analysis) - analysis.protein - analysis.fat - analysis.fibre - analysis.ash);
}
/** ME4 in kcal/100 g as fed: FEDIAF/NRC 4-step for prepared foods, the fresh-food equation otherwise (ENGINE.md §4). */
export function meKcalPer100g(analysis: Analysis): number {
  const { protein: p, fat, fibre } = analysis, carb = nfe(analysis), m = moistureUsed(analysis);
  if (analysis.kind === 'fresh') return f.freshProtein * p + f.freshFat * fat + f.freshNfe * carb;
  const ge = f.geProtein * p + f.geFat * fat + f.geCarbohydrate * (carb + fibre);
  const fibreDM = fibre / (100 - m) * 100;
  const digestibility = f.digestibilityIntercept - f.digestibilityFibreSlope * fibreDM;
  return ge * digestibility / 100 - f.proteinCorrection * p;
}
export function atwaterKcalPer100g(analysis: Analysis): number {
  return f.atwaterProtein * analysis.protein + f.atwaterFat * analysis.fat + f.atwaterNfe * nfe(analysis);
}
/** Per-food analysis; null when the food has no analysis. Assumes a validated food. */
export function analyseFood(food: Food): FoodAnalysisResult | null {
  const a = food.analysis;
  if (!a) return null;
  const m = moistureUsed(a), carb = nfe(a), me = meKcalPer100g(a), atwater = atwaterKcalPer100g(a);
  const dm = (x: number) => x / (100 - m) * 100;
  const shares = [f.atwaterProtein * a.protein, f.atwaterFat * a.fat, f.atwaterNfe * carb];
  const shareTotal = shares[0]! + shares[1]! + shares[2]!;
  const share = (x: number) => shareTotal > 0 ? x / shareTotal * 100 : 0;
  const warnings: FoodWarningCode[] = [];
  if (a.moisture === null) warnings.push('assumed-moisture');
  if (Math.abs(atwater - me) / me > f.atwaterDisagreementFraction) warnings.push('atwater-disagreement');
  if (food.energySource !== 'analysis' && food.energyPerUnit !== null
      && Math.abs(labelKcalPerGram(food.energyPerUnit, food.energyUnit) * 100 - me) / me > f.labelMismatchFraction)
    warnings.push('label-energy-mismatch');
  return {
    method: a.kind === 'fresh' ? 'fediaf-fresh' : 'fediaf-4-step', moisture: m, nfe: carb,
    meKcalPer100g: me, atwaterKcalPer100g: atwater,
    dryMatter: { protein: dm(a.protein), fat: dm(a.fat), fibre: dm(a.fibre), ash: dm(a.ash), nfe: dm(carb) },
    proteinGPer1000kcal: a.protein / me * 1000, fatGPer1000kcal: a.fat / me * 1000, carbGPer100kcal: carb / me * 100,
    energySharePercent: { protein: share(shares[0]!), fat: share(shares[1]!), carbohydrate: share(shares[2]!) },
    warnings: warnings.sort(),
  };
}
