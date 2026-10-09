import { catIcons, energyUnits, medicalFlags, type Activity, type Analysis, type Cat, type CatV1, type Food, type FoodV1, type Meal,
  type Plan, type PlanV1, type Profile, type Reproduction, type WeightEntry } from './models.js';
import { isISODate } from './dates.js';
import { labelKcalPerGram, meKcalPer100g, moistureUsed } from './food-analysis.js';

export class PlanError extends Error {
  constructor(public readonly path: string, detail: string) {
    super(`${path}: ${detail}`); this.name = 'PlanError';
  }
}
function record(value: unknown, path: string): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new PlanError(path, 'expected an object');
  return value as Record<string, unknown>;
}
/** Control characters (U+0000–U+001F, U+007F) and bidirectional overrides/isolates (U+202A–U+202E, U+2066–U+2069) can spoof or break displayed text. */
const FORBIDDEN_SINGLE_LINE = /[\u0000-\u001F\u007F\u202A-\u202E\u2066-\u2069]/;
/** Multi-line text may additionally contain tab (U+0009) and line feed (U+000A). */
const FORBIDDEN_MULTI_LINE = /[\u0000-\u0008\u000B-\u001F\u007F\u202A-\u202E\u2066-\u2069]/;
function text(value: unknown, path: string, max = 120, allowEmpty = false, multiline = false): string {
  if (typeof value !== 'string' || (!allowEmpty && !value.trim()) || value.length > max)
    throw new PlanError(path, `expected ${allowEmpty ? '0' : '1'}–${max} characters`);
  if ((multiline ? FORBIDDEN_MULTI_LINE : FORBIDDEN_SINGLE_LINE).test(value))
    throw new PlanError(path, 'must not contain control or bidirectional formatting characters');
  return value;
}
function id(value: unknown, path: string): string {
  const result = text(value, path, 64);
  if (!/^[A-Za-z0-9][A-Za-z0-9_-]*$/.test(result)) throw new PlanError(path, 'use letters, numbers, hyphens, or underscores');
  return result;
}
function number(value: unknown, path: string, min: number, max: number): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max)
    throw new PlanError(path, `expected a finite number between ${min} and ${max}`);
  return value;
}
function integer(value: unknown, path: string, min: number, max: number): number {
  const result = number(value, path, min, max);
  if (!Number.isInteger(result)) throw new PlanError(path, `expected a whole number between ${min} and ${max}`);
  return result;
}
function choice<const T extends readonly string[]>(value: unknown, path: string, options: T): T[number] {
  if (typeof value !== 'string' || !options.includes(value)) throw new PlanError(path, `expected ${options.join(', ')}`);
  return value as T[number];
}
function date(value: unknown, path: string): string {
  if (!isISODate(value)) throw new PlanError(path, 'expected a valid date in the form YYYY-MM-DD');
  return value;
}
function boolean(value: unknown, path: string): boolean {
  if (typeof value !== 'boolean') throw new PlanError(path, 'expected true or false');
  return value;
}
/** Nullable fields accept a missing key or null (ENGINE.md §1). */
function nullable<T>(value: unknown, path: string, read: (value: unknown, path: string) => T): T | null {
  return value === undefined || value === null ? null : read(value, path);
}
function list<T>(value: unknown, path: string, min: number, max: number, read: (item: unknown, path: string) => T): T[] {
  if (!Array.isArray(value) || value.length < min || value.length > max) throw new PlanError(path, `expected ${min}–${max} entries`);
  return value.map((item: unknown, index: number) => read(item, `${path}[${index}]`));
}
function unique(items: { id: string }[], path: string): void {
  if (new Set(items.map(item => item.id)).size !== items.length) throw new PlanError(path, 'IDs must be unique within this list');
}
const percent = (value: unknown, path: string) => number(value, path, 0, 100);
const weight = (value: unknown, path: string) => number(value, path, 0.1, 40);
const bcs = (value: unknown, path: string) => integer(value, path, 1, 9);
function analysis(value: unknown, path: string, type: Food['type']): Analysis {
  const o = record(value, path);
  const result: Analysis = {
    protein: percent(o.protein, `${path}.protein`), fat: percent(o.fat, `${path}.fat`),
    fibre: percent(o.fibre, `${path}.fibre`), ash: percent(o.ash, `${path}.ash`),
    moisture: nullable(o.moisture, `${path}.moisture`, percent), kind: choice(o.kind, `${path}.kind`, ['prepared', 'fresh']),
  };
  if (result.moisture === null && type !== 'dry') throw new PlanError(`${path}.moisture`, 'moisture may only be omitted for dry food');
  if (moistureUsed(result) >= 100) throw new PlanError(`${path}.moisture`, 'moisture must be below 100%');
  if (moistureUsed(result) + result.protein + result.fat + result.fibre + result.ash > 100 + 1e-9)
    throw new PlanError(path, 'constituents must not add up to more than 100%');
  return result;
}
function food(value: unknown, path: string): Food {
  const o = record(value, path);
  const type = choice(o.type, `${path}.type`, ['wet', 'dry']);
  const energySource = choice(o.energySource, `${path}.energySource`, ['label', 'estimate', 'analysis']);
  const result: Food = {
    id: id(o.id, `${path}.id`), name: text(o.name, `${path}.name`), type,
    energyPerUnit: nullable(o.energyPerUnit, `${path}.energyPerUnit`, (v, p) => number(v, p, 0.001, 50000)),
    energyUnit: choice(o.energyUnit, `${path}.energyUnit`, energyUnits), energySource,
    completeness: choice(o.completeness, `${path}.completeness`, ['complete', 'complementary', 'unknown']),
    lifeStageClaim: choice(o.lifeStageClaim, `${path}.lifeStageClaim`, ['adult', 'growth', 'all', 'unknown']),
    analysis: nullable(o.analysis, `${path}.analysis`, (v, p) => analysis(v, p, type)),
    note: text(o.note, `${path}.note`, 1000, true, true),
  };
  if (energySource === 'analysis' && !result.analysis) throw new PlanError(`${path}.analysis`, 'required when energy comes from the analysis');
  if (energySource !== 'analysis' && result.energyPerUnit === null) throw new PlanError(`${path}.energyPerUnit`, 'required unless energy comes from the analysis');
  return result;
}
function meal(value: unknown, path: string): Meal {
  const o = record(value, path);
  return { id: id(o.id, `${path}.id`), label: text(o.label, `${path}.label`),
    foodId: id(o.foodId, `${path}.foodId`), grams: number(o.grams, `${path}.grams`, 0, 1000) };
}
function reproduction(value: unknown, path: string): Reproduction {
  const o = record(value, path);
  return { status: choice(o.status, `${path}.status`, ['none', 'gestation', 'lactation']),
    litterSize: nullable(o.litterSize, `${path}.litterSize`, (v, p) => integer(v, p, 1, 12)),
    lactationWeek: nullable(o.lactationWeek, `${path}.lactationWeek`, (v, p) => integer(v, p, 1, 12)),
    preBreedingWeightKg: nullable(o.preBreedingWeightKg, `${path}.preBreedingWeightKg`, weight) };
}
function profile(value: unknown, path: string): Profile {
  const o = record(value, path);
  const medical = list(o.medical, `${path}.medical`, 0, medicalFlags.length, (v, p) => choice(v, p, medicalFlags));
  if (new Set(medical).size !== medical.length) throw new PlanError(`${path}.medical`, 'flags must be unique');
  const idealWeightKg = nullable(o.idealWeightKg, `${path}.idealWeightKg`, weight);
  const source = nullable(o.idealWeightSource, `${path}.idealWeightSource`, (v, p) => choice(v, p, ['veterinarian', 'estimate']));
  if (idealWeightKg === null && source !== null) throw new PlanError(`${path}.idealWeightSource`, 'must be null when there is no ideal weight');
  return {
    birthDate: nullable(o.birthDate, `${path}.birthDate`, date),
    approxAgeYears: nullable(o.approxAgeYears, `${path}.approxAgeYears`, (v, p) => number(v, p, 0, 30)),
    sex: choice(o.sex, `${path}.sex`, ['female', 'male', 'unknown']),
    neutered: choice(o.neutered, `${path}.neutered`, ['yes', 'no', 'unknown']),
    neuteredDate: nullable(o.neuteredDate, `${path}.neuteredDate`, date),
    lifestyle: nullable(o.lifestyle, `${path}.lifestyle`, (v, p) => choice(v, p, ['sedentary', 'typical', 'active'])),
    bcs: nullable(o.bcs, `${path}.bcs`, bcs),
    mcs: nullable(o.mcs, `${path}.mcs`, (v, p) => choice(v, p, ['normal', 'mild', 'moderate', 'severe'])),
    // Documents written before the source existed: a stored ideal weight counts as the veterinarian's (ENGINE.md §9).
    idealWeightKg, idealWeightSource: idealWeightKg === null ? null : source ?? 'veterinarian',
    expectedAdultWeightKg: nullable(o.expectedAdultWeightKg, `${path}.expectedAdultWeightKg`, weight),
    reproduction: reproduction(o.reproduction, `${path}.reproduction`), medical,
    endOfLife: boolean(o.endOfLife, `${path}.endOfLife`),
    verifiedIntakeKcal: nullable(o.verifiedIntakeKcal, `${path}.verifiedIntakeKcal`, (v, p) => number(v, p, 1, 3000)),
  };
}
function weightEntry(value: unknown, path: string): WeightEntry {
  const o = record(value, path);
  return { id: id(o.id, `${path}.id`), date: date(o.date, `${path}.date`), weightKg: weight(o.weightKg, `${path}.weightKg`),
    bcs: nullable(o.bcs, `${path}.bcs`, bcs) };
}
function cat(value: unknown, path: string): Cat {
  const o = record(value, path);
  const meals = list(o.meals, `${path}.meals`, 0, 24, meal); unique(meals, `${path}.meals`);
  const weightLog = list(o.weightLog, `${path}.weightLog`, 0, 1000, weightEntry); unique(weightLog, `${path}.weightLog`);
  return {
    id: id(o.id, `${path}.id`), name: text(o.name, `${path}.name`),
    icon: nullable(o.icon, `${path}.icon`, (v, p) => choice(v, p, catIcons)),
    weightKg: weight(o.weightKg, `${path}.weightKg`),
    goal: choice(o.goal, `${path}.goal`, ['loss', 'maintain', 'gain']),
    targetKcal: number(o.targetKcal, `${path}.targetKcal`, 1, 3000),
    targetSource: choice(o.targetSource, `${path}.targetSource`, ['provisional', 'owner', 'veterinarian']),
    extraKcal: number(o.extraKcal, `${path}.extraKcal`, 0, 3000),
    balanceFoodId: id(o.balanceFoodId, `${path}.balanceFoodId`), meals,
    profile: profile(o.profile, `${path}.profile`), weightLog,
  };
}
function activity(value: unknown, path: string): Activity {
  const o = record(value, path);
  return { id: id(o.id, `${path}.id`), label: text(o.label, `${path}.label`),
    sharePercent: number(o.sharePercent, `${path}.sharePercent`, 0, 100) };
}
function activities(value: unknown): Activity[] {
  const result = list(value, 'activities', 1, 12, activity); unique(result, 'activities');
  if (Math.abs(result.reduce((sum, a) => sum + a.sharePercent, 0) - 100) > 1e-6)
    throw new PlanError('activities', 'shares must add up to 100%');
  return result;
}
function checkDensity(kcalPerGram: number, name: string): void {
  if (!(kcalPerGram >= 0.01 && kcalPerGram <= 10)) throw new PlanError(`food ${name}`, 'energy must be between 0.01 and 10 kcal/g; check the unit');
}

function foodV1(value: unknown, path: string): FoodV1 {
  const o = record(value, path);
  return {
    id: id(o.id, `${path}.id`), name: text(o.name, `${path}.name`),
    type: choice(o.type, `${path}.type`, ['wet', 'dry']),
    energyPerUnit: number(o.energyPerUnit, `${path}.energyPerUnit`, 0.001, 50000),
    energyUnit: choice(o.energyUnit, `${path}.energyUnit`, energyUnits),
    energySource: choice(o.energySource, `${path}.energySource`, ['label', 'estimate']),
    completeness: choice(o.completeness, `${path}.completeness`, ['complete', 'complementary', 'unknown']),
    note: text(o.note, `${path}.note`, 1000, true, true),
  };
}
function catV1(value: unknown, path: string): CatV1 {
  const o = record(value, path);
  const meals = list(o.meals, `${path}.meals`, 0, 24, meal); unique(meals, `${path}.meals`);
  return {
    id: id(o.id, `${path}.id`), name: text(o.name, `${path}.name`),
    weightKg: weight(o.weightKg, `${path}.weightKg`),
    goal: choice(o.goal, `${path}.goal`, ['loss', 'maintain', 'gain']),
    targetKcal: number(o.targetKcal, `${path}.targetKcal`, 1, 3000),
    targetSource: choice(o.targetSource, `${path}.targetSource`, ['provisional', 'owner', 'veterinarian']),
    extraKcal: number(o.extraKcal, `${path}.extraKcal`, 0, 3000),
    dryFoodId: id(o.dryFoodId, `${path}.dryFoodId`), meals,
  };
}
/** Validates a legacy v1 document with the v1 rules (dry food must be dry, meals must be wet). */
function parsePlanV1(o: Record<string, unknown>): PlanV1 {
  const foods = list(o.foods, 'foods', 1, 100, foodV1); unique(foods, 'foods');
  const cats = list(o.cats, 'cats', 1, 50, catV1); unique(cats, 'cats');
  const acts = activities(o.activities);
  const lookup = new Map(foods.map(f => [f.id, f]));
  for (const f of foods) checkDensity(labelKcalPerGram(f.energyPerUnit, f.energyUnit), f.name);
  for (const c of cats) {
    if (lookup.get(c.dryFoodId)?.type !== 'dry') throw new PlanError(`cat ${c.name}`, 'dry food must reference a dry food in the library');
    for (const m of c.meals) if (lookup.get(m.foodId)?.type !== 'wet')
      throw new PlanError(`meal ${m.label}`, 'meal must reference a wet food in the library');
  }
  return { schemaVersion: 1, name: text(o.name, 'name'), foods, cats, activities: acts };
}
/** The all-null/unknown profile used for migrated and newly created cats (ENGINE.md §9). */
export function defaultProfile(): Profile {
  return { birthDate: null, approxAgeYears: null, sex: 'unknown', neutered: 'unknown', neuteredDate: null,
    lifestyle: null, bcs: null, mcs: null, idealWeightKg: null, idealWeightSource: null, expectedAdultWeightKg: null,
    reproduction: { status: 'none', litterSize: null, lactationWeek: null, preBreedingWeightKg: null },
    medical: [], endOfLife: false, verifiedIntakeKcal: null };
}
/** Migrates a validated v1 plan to v2 (ENGINE.md §9). Allocation results are unchanged. */
export function migrateV1(plan: PlanV1): Plan {
  return {
    schemaVersion: 2, name: plan.name,
    foods: plan.foods.map(f => ({ id: f.id, name: f.name, type: f.type, energyPerUnit: f.energyPerUnit, energyUnit: f.energyUnit,
      energySource: f.energySource, completeness: f.completeness, lifeStageClaim: 'unknown', analysis: null, note: f.note })),
    cats: plan.cats.map(c => ({ id: c.id, name: c.name, icon: null, weightKg: c.weightKg, goal: c.goal, targetKcal: c.targetKcal,
      targetSource: c.targetSource, extraKcal: c.extraKcal, balanceFoodId: c.dryFoodId,
      meals: c.meals.map(m => ({ ...m })), profile: defaultProfile(), weightLog: [] })),
    activities: plan.activities.map(a => ({ ...a })),
  };
}
/** Validates untrusted imports (v1 or v2), removes unknown fields, migrates v1, and returns fresh v2 value objects. */
export function parsePlan(value: unknown): Plan {
  const o = record(value, 'plan');
  if (o.schemaVersion === 1) return parsePlan(migrateV1(parsePlanV1(o)));
  if (o.schemaVersion !== 2) throw new PlanError('schemaVersion', 'only versions 1 and 2 are supported');
  const foods = list(o.foods, 'foods', 1, 100, food); unique(foods, 'foods');
  const cats = list(o.cats, 'cats', 1, 50, cat); unique(cats, 'cats');
  const acts = activities(o.activities);
  const lookup = new Map(foods.map(f => [f.id, f]));
  for (const f of foods) {
    if (f.energyPerUnit !== null) checkDensity(labelKcalPerGram(f.energyPerUnit, f.energyUnit), f.name);
    if (f.analysis) checkDensity(meKcalPer100g(f.analysis) / 100, f.name);
  }
  for (const c of cats) {
    if (!lookup.has(c.balanceFoodId)) throw new PlanError(`cat ${c.name}`, 'balance food must reference a food in the library');
    for (const m of c.meals) if (!lookup.has(m.foodId)) throw new PlanError(`meal ${m.label}`, 'meal must reference a food in the library');
  }
  return { schemaVersion: 2, name: text(o.name, 'name'), foods, cats, activities: acts };
}
export const MAX_IMPORT_BYTES = 1_048_576;
export function parsePlanJSON(json: string): Plan {
  if (new TextEncoder().encode(json).byteLength > MAX_IMPORT_BYTES) throw new PlanError('file', 'maximum size is 1 MiB');
  let value: unknown;
  try { value = JSON.parse(json); } catch { throw new PlanError('file', 'invalid JSON'); }
  return parsePlan(value);
}
