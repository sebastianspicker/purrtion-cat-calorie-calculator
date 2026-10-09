import type { Cat, EnergyEstimate, EquationId, IdealWeight, InputCode, LifeStageLabel, NoteCode, Profile, ReferCode, Stage, WeightEntry } from './models.js';
import { acuteMedicalFlags, chronicMedicalFlags } from './models.js';
import { daysBetween } from './dates.js';
import { model } from './generated/model.js';
const { units, age, bcs: bcsModel } = model;

/** RER = 70 × w^0.75. A reference, not a feeding recommendation. */
export function rer(weightKg: number): number {
  if (!Number.isFinite(weightKg) || weightKg <= 0) throw new RangeError('Weight must be positive and finite');
  return model.rer.factor * Math.pow(weightKg, model.rer.exponent);
}
/** MER(k, w) = k × w^0.67 */
export function mer(k: number, weightKg: number): number { return k * Math.pow(weightKg, model.mer.exponent); }

const byDateThenId = (a: WeightEntry, b: WeightEntry): number =>
  a.date < b.date ? -1 : a.date > b.date ? 1 : a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
/** Weight-log entries dated on or before `asOf`, sorted by date then id. */
export function weightEntriesAsOf(cat: Cat, asOf: string): WeightEntry[] {
  return cat.weightLog.filter(e => daysBetween(e.date, asOf) >= 0).sort(byDateThenId);
}
/** Age in days on `asOf`; null when unknown or when the birth date lies after `asOf`. */
export function ageInDays(profile: Profile, asOf: string): number | null {
  if (profile.birthDate !== null) { const days = daysBetween(profile.birthDate, asOf); return days < 0 ? null : days; }
  return profile.approxAgeYears === null ? null : profile.approxAgeYears * units.daysPerYear;
}
/** The profile BCS (the owner's current assessment) when set; otherwise the BCS of the latest weight-log entry
 * dated on or before `asOf` that has one. */
export function effectiveBcs(cat: Cat, asOf: string): number | null {
  return cat.profile.bcs ?? weightEntriesAsOf(cat, asOf).filter(e => e.bcs !== null).at(-1)?.bcs ?? null;
}
/** Reaching an estimated adult weight does not establish maturity; the growth estimate needs review. */
export function hasReachedExpectedAdultWeight(cat: Cat, asOf: string): boolean {
  const days = ageInDays(cat.profile, asOf), adult = cat.profile.expectedAdultWeightKg;
  return days !== null && days >= age.neonateMaxDays && days / units.daysPerMonth < age.kittenMaxMonths
    && adult !== null && cat.weightKg >= adult;
}
export function stageOf(cat: Cat, asOf: string): Stage | null {
  const p = cat.profile, days = ageInDays(p, asOf);
  if (p.endOfLife) return 'end-of-life';
  if (p.reproduction.status !== 'none') return p.reproduction.status;
  if (days === null) return null;
  if (days < age.neonateMaxDays) return 'neonate';
  if (days / units.daysPerMonth < age.kittenMaxMonths) return 'kitten';
  return Math.floor(days / units.daysPerYear) >= age.seniorMinYears ? 'senior' : 'adult';
}
function lifeStageLabel(years: number): LifeStageLabel {
  return years < age.youngAdultMinYears ? 'kitten' : years < age.matureAdultMinYears ? 'young-adult'
    : years < age.seniorLabelMinYears ? 'mature-adult' : 'senior';
}
export function isRecentlyNeutered(profile: Profile, asOf: string): boolean {
  if (profile.neuteredDate === null) return false;
  const days = daysBetween(profile.neuteredDate, asOf);
  return days >= 0 && days <= age.recentNeuterMaxDays;
}
/** Lifestyle coefficient k; a missing lifestyle defaults from neuter status (neutered → typical, otherwise active). */
export function lifestyleK(profile: Profile): number {
  return model.mer[profile.lifestyle ?? (profile.neutered === 'yes' ? 'typical' : 'active')];
}
/** A stored ideal weight is used as-is (D3); otherwise it is derived from the effective BCS, else the current weight. */
export function idealWeightOf(cat: Cat, bcs: number | null): IdealWeight {
  const stored = cat.profile.idealWeightKg, bw = cat.weightKg, iw = model.idealWeight;
  if (stored !== null) return cat.profile.idealWeightSource === 'estimate'
    ? { kg: stored, lowKg: stored * (1 - iw.rangeFraction), highKg: stored * (1 + iw.rangeFraction), source: 'estimate' }
    : { kg: stored, lowKg: stored, highKg: stored, source: 'veterinarian' };
  if (bcs !== null && bcs >= bcsModel.overweightMin) {
    const kg = bw / (1 + iw.fractionPerBcsUnit * (bcs - bcsModel.ideal));
    return { kg, lowKg: kg * (1 - iw.rangeFraction), highKg: kg * (1 + iw.rangeFraction), source: 'bcs-estimate' };
  }
  return { kg: bw, lowKg: bw, highKg: bw, source: 'current' };
}
/** Weight used by the maintenance and gain equations (D2): the ideal weight when it is below the current weight. */
export function weightUsed(bw: number, ibw: number): number { return ibw < bw ? ibw : bw; }
/** Piecewise-linear FEDIAF kitten band multiplier between the band centres (D4). */
export function kittenBandMultiplier(months: number, values: readonly number[]): number {
  const centres = model.kitten.bandCentreMonths;
  if (months <= centres[0]!) return values[0]!;
  for (let i = 0; i < centres.length - 1; i++) {
    const c0 = centres[i]!, c1 = centres[i + 1]!;
    if (months <= c1) return values[i]! + (months - c0) / (c1 - c0) * (values[i + 1]! - values[i]!);
  }
  return values[values.length - 1]!;
}
const clamp01 = (x: number): number => Math.min(1, Math.max(0, x));
/** Weight-loss start (D1); null when a verified intake lies below the floor (refer). */
export function weightLossStartKcal(ibwKg: number, k: number, verifiedIntakeKcal: number | null, floorKcal: number): number | null {
  const loss = model.loss;
  if (verifiedIntakeKcal === null) return Math.max(floorKcal, loss.startFactor * Math.min(rer(ibwKg), mer(k, ibwKg)));
  return verifiedIntakeKcal < floorKcal ? null : Math.max(floorKcal, loss.verifiedIntakeFactor * verifiedIntakeKcal);
}
/** Maintenance start at weight w: MER(k, w), capped at 1.4 × RER(BW), never below the floor. */
export function maintainStartKcal(cat: Cat, weightKg: number, floorKcal: number): { kcal: number; clamped: boolean } {
  const raw = mer(lifestyleK(cat.profile), weightKg), cap = model.maintain.maxRerMultiple * rer(cat.weightKg);
  return { kcal: Math.max(Math.min(raw, cap), floorKcal), clamped: raw > cap };
}

interface Calculation {
  equation: EquationId; coefficient: number | null; weightUsedKg: number;
  startKcal: number; lowKcal: number; highKcal: number;
}
const sorted = <T extends string>(set: Set<T>): T[] => [...set].sort();

/** The energy estimator (ENGINE.md §3). It never reads or writes `targetKcal` except for the comparison. */
export function estimateEnergy(cat: Cat, asOf: string, trendStops: readonly ReferCode[] = []): EnergyEstimate {
  const p = cat.profile, bw = cat.weightKg, days = ageInDays(p, asOf), bcs = effectiveBcs(cat, asOf);
  const stage = stageOf(cat, asOf), years = days === null ? null : Math.floor(days / units.daysPerYear);
  const reasons = new Set<ReferCode>(trendStops), missing = new Set<InputCode>(), notes = new Set<NoteCode>();
  if (days !== null && days < age.neonateMaxDays) reasons.add('neonate');
  if (p.endOfLife) reasons.add('end-of-life');
  if (p.medical.some(flag => (acuteMedicalFlags as readonly string[]).includes(flag))) reasons.add('acute-medical');
  if (bcs !== null && bcs <= bcsModel.referMax) reasons.add('bcs-low');
  if (p.mcs === 'severe') reasons.add('mcs-severe');
  if (stage === 'kitten' && hasReachedExpectedAdultWeight(cat, asOf)) reasons.add('kitten-adult-weight-reached');
  const adultLike = stage === 'adult' || stage === 'senior';
  if (days === null) missing.add('age');
  if (adultLike && p.neutered === 'unknown') missing.add('neutered');
  if (adultLike && bcs === null) missing.add('bcs');
  if (years !== null && years >= age.mcsRequiredMinYears && p.mcs === null) missing.add('mcs');
  if (p.reproduction.status === 'lactation') {
    if (p.reproduction.litterSize === null) missing.add('litter-size');
    if (p.reproduction.lactationWeek === null) missing.add('lactation-week');
  }
  const base: EnergyEstimate = {
    status: reasons.size ? 'refer' : 'needs-input', stage, lifeStageLabel: years === null ? null : lifeStageLabel(years),
    ageMonths: days === null ? null : days / units.daysPerMonth, rerKcal: rer(bw), idealWeight: null,
    equation: null, coefficient: null, weightUsedKg: null, startKcal: null, lowKcal: null, highKcal: null,
    floorKcal: null, referenceBand: null, reasons: sorted(reasons), missing: sorted(missing), notes: [], comparison: null,
  };
  if (reasons.size || missing.size || stage === null || days === null) return base;

  const chronic = p.medical.some(flag => (chronicMedicalFlags as readonly string[]).includes(flag));
  if (chronic) { notes.add('medical-vet-plan'); if (p.medical.includes('diabetes')) notes.add('diabetes-low-carb-info'); }
  let calc: Calculation, idealWeight: IdealWeight | null = null, floorKcal: number | null = null;
  let referenceBand: EnergyEstimate['referenceBand'] = null;
  if (stage === 'kitten') {
    const kitten = model.kitten, months = days / units.daysPerMonth;
    const bandLow = kittenBandMultiplier(months, kitten.bandLow) * mer(kitten.bandLowK, bw);
    const bandHigh = kittenBandMultiplier(months, kitten.bandHigh) * mer(kitten.bandHighK, bw);
    const merAdult = mer(lifestyleK(p), bw), ageTerm = (months - kitten.transitionStartMonths) / kitten.transitionMonthsWidth;
    const adult = p.expectedAdultWeightKg;
    let base: number, t: number, equation: EquationId, coefficient: number | null;
    if (adult !== null) {
      // Reached/exceeded adult-weight estimates are referred above, so ratio < 1 here.
      const ratio = bw / adult;
      base = mer(kitten.nrcK, bw) * kitten.nrcFactor * (Math.exp(kitten.nrcExponent * ratio) - kitten.nrcOffset);
      t = clamp01(Math.max((ratio - kitten.transitionStartRatio) / kitten.transitionRatioWidth, ageTerm));
      equation = 'kitten-nrc'; coefficient = kitten.nrcK;
    } else {
      notes.add('kitten-adult-weight-unknown');
      base = (bandLow + bandHigh) / 2; t = clamp01(ageTerm);
      equation = 'kitten-fediaf-band'; coefficient = null;
    }
    const raw = (1 - t) * base + t * merAdult, cap = kitten.maxRerMultiple * rer(bw);
    if (raw > cap) notes.add('clamped-high');
    const start = Math.min(raw, cap);
    let low = Math.min(kitten.startLowFactor * start, bandLow), high = Math.max(kitten.startHighFactor * start, bandHigh);
    if (t > 0) { low = Math.min(low, model.maintain.lowFactor * merAdult); high = Math.max(high, model.maintain.highFactor * merAdult); }
    if (t > 0 && t < 1) notes.add('kitten-transition');
    calc = { equation, coefficient, weightUsedKg: bw, startKcal: start, lowKcal: low, highKcal: high };
    notes.add('kitten-weigh-weekly');
  } else if (stage === 'gestation') {
    const g = model.gestation, w = p.reproduction.preBreedingWeightKg ?? bw;
    if (p.reproduction.preBreedingWeightKg === null) notes.add('pre-breeding-weight-assumed');
    const start = mer(g.k, w);
    calc = { equation: 'gestation-fediaf', coefficient: g.k, weightUsedKg: w, startKcal: start, lowKcal: start, highKcal: g.highFactor * start };
    notes.add('free-choice-recommended'); notes.add('reproduction-vet');
  } else if (stage === 'lactation') {
    const l = model.lactation, litter = p.reproduction.litterSize!, week = p.reproduction.lactationWeek!;
    let tier = l.litterMax.findIndex(max => litter <= max);
    if (tier < 0) tier = l.litterC.length - 1;
    const factor = week <= l.weekFactors.length ? l.weekFactors[week - 1]! : l.lateWeekFactor;
    if (week > l.weekFactors.length) notes.add('weaning-transition');
    const start = mer(l.k, bw) + l.litterC[tier]! * bw * factor;
    calc = { equation: 'lactation-fediaf', coefficient: l.k, weightUsedKg: bw, startKcal: start, lowKcal: start, highKcal: l.highFactor * start };
    notes.add('free-choice-recommended'); notes.add('reproduction-vet');
  } else {
    const effective = bcs!, ibw = idealWeightOf(cat, effective), floor = model.floor.rerFactor * rer(ibw.kg);
    const k = lifestyleK(p), overweight = effective >= bcsModel.overweightMin;
    const wider = years! >= age.widerRangeMinYears;
    const maintain = (w: number): Calculation => {
      const start = maintainStartKcal(cat, w, floor);
      if (start.clamped) notes.add('clamped-high');
      if (wider) notes.add('senior-wider-range');
      return { equation: 'adult-fediaf', coefficient: k, weightUsedKg: w, startKcal: start.kcal,
        lowKcal: Math.max(start.kcal * model.maintain.lowFactor, floor),
        highKcal: start.kcal * (wider ? model.maintain.seniorHighFactor : model.maintain.highFactor) };
    };
    const w = weightUsed(bw, ibw.kg);
    if (chronic) calc = maintain(bw);
    else if (cat.goal === 'loss') {
      if (ibw.kg < bw) {
        const loss = model.loss, start = weightLossStartKcal(ibw.kg, k, p.verifiedIntakeKcal, floor);
        // A weight-stable cat that eats less than the floor needs a work-up, not a further cut (D1).
        if (start === null) return { ...base, status: 'refer', reasons: ['verified-intake-below-floor'] };
        calc = { equation: 'weight-loss-aaha', coefficient: loss.startFactor, weightUsedKg: ibw.kg, startKcal: start,
          lowKcal: Math.max(start * loss.lowFactor, floor), highKcal: start * loss.highFactor };
      } else { calc = maintain(w); notes.add('loss-not-indicated'); }
    } else if (cat.goal === 'gain') {
      if (effective === bcsModel.gainOnly) {
        const g = model.gain, m = mer(k, w);
        calc = { equation: 'adult-gain', coefficient: k, weightUsedKg: w, startKcal: Math.max(g.startFactor * m, floor),
          lowKcal: Math.max(g.lowFactor * m, floor), highKcal: Math.max(g.highFactor * m, floor) };
      } else { calc = maintain(w); notes.add('gain-not-indicated'); }
    } else {
      calc = maintain(w);
      if (overweight) notes.add('overweight-consider-loss');
    }
    if (isRecentlyNeutered(p, asOf)) notes.add('recently-neutered');
    idealWeight = ibw; floorKcal = floor;
    referenceBand = { lowKcal: mer(model.mer.referenceBandLow, calc.weightUsedKg), highKcal: mer(model.mer.referenceBandHigh, calc.weightUsedKg) };
  }
  const target = cat.targetKcal, ratio = target / calc.startKcal;
  return { ...base, status: chronic || stage === 'gestation' || stage === 'lactation' ? 'reference-only' : 'ok',
    idealWeight, ...calc, floorKcal, referenceBand, notes: sorted(notes),
    comparison: { targetToStartRatio: ratio, belowRange: target < calc.lowKcal, aboveRange: target > calc.highKcal,
      differsOver30Percent: Math.abs(ratio - 1) > model.comparison.differsFraction,
      belowFloor: floorKcal !== null && target < floorKcal } };
}
