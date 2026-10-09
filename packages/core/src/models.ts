/** Portable v2 contract (docs/ENGINE.md). No UI, browser APIs, storage, network, or hidden defaults. */
export const energyUnits = ['kcal/100g', 'kJ/100g', 'kcal/kg', 'kJ/kg'] as const;
export type EnergyUnit = typeof energyUnits[number];
export type Goal = 'loss' | 'maintain' | 'gain';
export type TargetSource = 'provisional' | 'owner' | 'veterinarian';
export type Completeness = 'complete' | 'complementary' | 'unknown';
export type FoodType = 'wet' | 'dry';
export type EnergySource = 'label' | 'estimate' | 'analysis';
export type LifeStageClaim = 'adult' | 'growth' | 'all' | 'unknown';
export interface Analysis {
  protein: number; fat: number; fibre: number; ash: number;
  /** Percent as fed; null only for dry foods (the engine then assumes the model default). */
  moisture: number | null; kind: 'prepared' | 'fresh';
}
export interface Food {
  id: string; name: string; type: FoodType;
  /** Null only when energySource is 'analysis'. */
  energyPerUnit: number | null; energyUnit: EnergyUnit;
  energySource: EnergySource; completeness: Completeness; lifeStageClaim: LifeStageClaim;
  analysis: Analysis | null; note: string;
}
export interface Meal { id: string; label: string; foodId: string; grams: number }
export const chronicMedicalFlags = ['ckd', 'diabetes', 'hyperthyroid', 'gi', 'pancreatitis', 'urinary', 'cancer', 'prescription-diet', 'other'] as const;
export const acuteMedicalFlags = ['hepatic-lipidosis', 'hospitalised', 'not-eating', 'clinical-signs'] as const;
export const medicalFlags = [...chronicMedicalFlags, ...acuteMedicalFlags] as const;
export type MedicalFlag = typeof medicalFlags[number];
export type Sex = 'female' | 'male' | 'unknown';
export type Neutered = 'yes' | 'no' | 'unknown';
export type Lifestyle = 'sedentary' | 'typical' | 'active';
export type MuscleCondition = 'normal' | 'mild' | 'moderate' | 'severe';
export type ReproductionStatus = 'none' | 'gestation' | 'lactation';
/** Where a stored ideal weight comes from (ENGINE.md §1, D3). */
export type IdealWeightSource = 'veterinarian' | 'estimate';
export interface Reproduction {
  status: ReproductionStatus; litterSize: number | null; lactationWeek: number | null; preBreedingWeightKg: number | null;
}
export interface Profile {
  birthDate: string | null; approxAgeYears: number | null;
  sex: Sex; neutered: Neutered; neuteredDate: string | null;
  lifestyle: Lifestyle | null; bcs: number | null; mcs: MuscleCondition | null;
  idealWeightKg: number | null;
  /** Null if and only if `idealWeightKg` is null. */
  idealWeightSource: IdealWeightSource | null;
  expectedAdultWeightKg: number | null;
  reproduction: Reproduction; medical: MedicalFlag[]; endOfLife: boolean;
  verifiedIntakeKcal: number | null;
}
/** Optional picture for a cat; display names are `icon.*` in shared/messages.json. Keep identical to Swift `CatIcon`. */
export const catIcons = ['moon', 'scale', 'dango', 'stripes', 'bolt', 'paw', 'fish', 'yarn', 'star', 'heart', 'leaf', 'bow'] as const;
export type CatIcon = typeof catIcons[number];
export interface WeightEntry { id: string; date: string; weightKg: number; bcs: number | null }
export interface Cat {
  id: string; name: string; icon: CatIcon | null; weightKg: number; goal: Goal;
  targetKcal: number; targetSource: TargetSource; extraKcal: number;
  balanceFoodId: string; meals: Meal[]; profile: Profile; weightLog: WeightEntry[];
}
export interface Activity { id: string; label: string; sharePercent: number }
export interface Plan {
  schemaVersion: 2; name: string; foods: Food[]; cats: Cat[]; activities: Activity[];
}

/** Legacy v1 documents. Accepted by the decoders and migrated (ENGINE.md §9). */
export interface FoodV1 {
  id: string; name: string; type: FoodType;
  energyPerUnit: number; energyUnit: EnergyUnit;
  energySource: 'label' | 'estimate'; completeness: Completeness; note: string;
}
export interface CatV1 {
  id: string; name: string; weightKg: number; goal: Goal;
  targetKcal: number; targetSource: TargetSource; extraKcal: number;
  dryFoodId: string; meals: Meal[];
}
export interface PlanV1 {
  schemaVersion: 1; name: string; foods: FoodV1[]; cats: CatV1[]; activities: Activity[];
}

export type WarningCode = 'estimated-energy' | 'provisional-target' | 'unknown-completeness'
  | 'complementary-balance-food' | 'extras-over-10-percent' | 'over-budget';
export interface ActivityPortion {
  id: string; label: string; sharePercent: number; exactGrams: number; roundedGrams: number;
}

export type EstimateStatus = 'ok' | 'reference-only' | 'needs-input' | 'refer';
export type Stage = 'neonate' | 'kitten' | 'adult' | 'senior' | 'gestation' | 'lactation' | 'end-of-life';
export type LifeStageLabel = 'kitten' | 'young-adult' | 'mature-adult' | 'senior';
export type EquationId = 'adult-fediaf' | 'weight-loss-aaha' | 'adult-gain' | 'kitten-nrc' | 'kitten-fediaf-band'
  | 'gestation-fediaf' | 'lactation-fediaf';
export type ReferCode = 'neonate' | 'end-of-life' | 'acute-medical' | 'bcs-low' | 'mcs-severe'
  | 'rapid-weight-change' | 'kitten-not-growing' | 'verified-intake-below-floor';
export type InputCode = 'age' | 'neutered' | 'bcs' | 'mcs' | 'litter-size' | 'lactation-week';
export type NoteCode = 'loss-not-indicated' | 'gain-not-indicated' | 'senior-wider-range' | 'overweight-consider-loss'
  | 'clamped-high' | 'recently-neutered' | 'medical-vet-plan' | 'diabetes-low-carb-info' | 'kitten-adult-weight-unknown'
  | 'kitten-weigh-weekly' | 'kitten-transition' | 'growth-complete' | 'pre-breeding-weight-assumed' | 'free-choice-recommended' | 'reproduction-vet' | 'weaning-transition';
export interface IdealWeight { kg: number; lowKg: number; highKg: number; source: 'veterinarian' | 'estimate' | 'bcs-estimate' | 'current' }
export interface EstimateComparison {
  targetToStartRatio: number; belowRange: boolean; aboveRange: boolean; differsOver30Percent: boolean; belowFloor: boolean;
}
export interface EnergyEstimate {
  status: EstimateStatus; stage: Stage | null; lifeStageLabel: LifeStageLabel | null; ageMonths: number | null;
  rerKcal: number; idealWeight: IdealWeight | null; equation: EquationId | null; coefficient: number | null;
  weightUsedKg: number | null; startKcal: number | null; lowKcal: number | null; highKcal: number | null;
  floorKcal: number | null; referenceBand: { lowKcal: number; highKcal: number } | null;
  reasons: ReferCode[]; missing: InputCode[]; notes: NoteCode[]; comparison: EstimateComparison | null;
}

export type FoodWarningCode = 'assumed-moisture' | 'atwater-disagreement' | 'label-energy-mismatch';
export type FoodAnalysisMethod = 'fediaf-4-step' | 'fediaf-fresh';
export interface FoodAnalysisResult {
  method: FoodAnalysisMethod; moisture: number; nfe: number;
  meKcalPer100g: number; atwaterKcalPer100g: number;
  dryMatter: { protein: number; fat: number; fibre: number; ash: number; nfe: number };
  proteinGPer1000kcal: number; fatGPer1000kcal: number; carbGPer100kcal: number;
  energySharePercent: { protein: number; fat: number; carbohydrate: number };
  warnings: FoodWarningCode[];
}
export interface FoodResult { id: string; kcalPerGram: number; analysis: FoodAnalysisResult | null }

export type SuggestionAction = 'switch-to-maintenance' | 'increase' | 'decrease' | 'hold' | 'none' | 'refer';
export type SuggestionReason = 'ideal-weight-reached' | 'loss-too-fast' | 'on-track' | 'slow-recheck-2-weeks' | 'plateau'
  | 'at-floor' | 'gaining' | 'losing' | 'stable' | 'ideal-condition-reached' | 'gain-too-fast' | 'not-gaining';
export interface Suggestion { action: SuggestionAction; reason: SuggestionReason; suggestedKcal: number | null }
export interface Trend {
  entries: number; latestKg: number | null; ratePercentPerWeek: number | null; change28dPercent: number | null;
  suggestion: Suggestion | null; nextWeighInDays: number;
}

export type NutritionWarningCode = 'protein-below-minimum' | 'protein-below-5g-per-kg-ibw'
  | 'carb-above-diabetic-threshold' | 'growth-claim-missing';
export type NutritionNoteCode = 'ckd-protein-vet';
export type NutritionResult =
  | { status: 'ok'; kcal: number; proteinG: number; proteinPer1000: number; minProteinPer1000: number;
      carbPercentME: number; warnings: NutritionWarningCode[]; notes: NutritionNoteCode[] }
  | { status: 'incomplete-data'; missingFoodIds: string[] }
  | { status: 'not-applicable' };

export interface CatResult {
  id: string; fixedGrams: number; fixedKcal: number; extraKcal: number;
  balanceFoodId: string; balanceKcal: number; balanceGramsExact: number; balanceGramsRounded: number;
  overBudgetKcal: number; roundedDailyKcal: number; rerKcal: number;
  warnings: WarningCode[]; activities: ActivityPortion[];
  estimate: EnergyEstimate; trend: Trend; nutrition: NutritionResult;
}
export interface BalanceByFood { foodId: string; gramsExact: number; gramsRounded: number }
export interface PlanTotals {
  fixedGrams: number; fixedKcal: number; targetKcal: number;
  balanceGramsExact: number; balanceGramsRounded: number; roundedDailyKcal: number;
  balanceByFood: BalanceByFood[];
}
export interface PlanResult { cats: CatResult[]; foods: FoodResult[]; totals: PlanTotals }
export interface CalculateOptions { asOf: string }
