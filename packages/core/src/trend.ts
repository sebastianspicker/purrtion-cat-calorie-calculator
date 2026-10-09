import type { Cat, EnergyEstimate, ReferCode, Stage, Suggestion, Trend, WeightEntry } from './models.js';
import { daysBetween } from './dates.js';
import { effectiveBcs, isRecentlyNeutered, maintainStartKcal, weightEntriesAsOf } from './estimator.js';
import { model } from './generated/model.js';
const t = model.trend;

export interface WeightSeries {
  entries: WeightEntry[]; latest: WeightEntry | null; window: WeightEntry[];
  spanDays: number; ratePercentPerWeek: number | null; change28dPercent: number | null;
}
/** Window, least-squares rate and 28-day change from the entries dated on or before `asOf` (ENGINE.md §6). */
export function weightSeries(cat: Cat, asOf: string): WeightSeries {
  const entries = weightEntriesAsOf(cat, asOf), latest = entries.at(-1) ?? null;
  if (!latest) return { entries, latest, window: [], spanDays: 0, ratePercentPerWeek: null, change28dPercent: null };
  const window = entries.filter(e => daysBetween(e.date, latest.date) <= t.windowDays);
  const first = window[0]!, spanDays = daysBetween(first.date, latest.date);
  let ratePercentPerWeek: number | null = null, change28dPercent: number | null = null;
  if (window.length >= 2 && spanDays >= t.rateMinSpanDays) {
    const xs = window.map(e => daysBetween(first.date, e.date)), ys = window.map(e => e.weightKg);
    const mean = (values: number[]) => values.reduce((a, b) => a + b, 0) / values.length;
    const mx = mean(xs), my = mean(ys);
    let sxy = 0, sxx = 0;
    xs.forEach((x, i) => { sxy += (x - mx) * (ys[i]! - my); sxx += (x - mx) * (x - mx); });
    ratePercentPerWeek = sxy / sxx * 7 / my * 100;
  }
  if (window.length >= 2 && spanDays >= t.changeMinSpanDays)
    change28dPercent = (latest.weightKg - first.weightKg) / first.weightKg * 100;
  return { entries, latest, window, spanDays, ratePercentPerWeek, change28dPercent };
}
/** Trend stops that feed into `estimate.reasons`. */
export function trendStops(cat: Cat, series: WeightSeries, stage: Stage | null): ReferCode[] {
  const stops: ReferCode[] = [], rate = series.ratePercentPerWeek, change = series.change28dPercent;
  // Growth, pregnancy and lactation change weight by design; the rapid-change stop is for unintended change only (SCIENCE.md §12.6).
  const growing = stage === 'kitten' || stage === 'gestation' || stage === 'lactation';
  // On a weight-loss plan, loss itself is intended; only a gain or a loss that is too fast stops the plan (D5).
  const rapid = cat.goal === 'loss'
    ? (change !== null && (change >= t.rapidChangePercent || change <= t.lossRapidChangePercent)) || (rate !== null && rate < t.lossRapidRatePercent)
    : (change !== null && Math.abs(change) >= t.rapidChangePercent) || (rate !== null && rate < t.rapidLossRatePercent);
  if (!growing && rapid) stops.push('rapid-weight-change');
  const latest = series.latest;
  if (stage === 'kitten' && latest) {
    const earlier = series.entries.filter(e => {
      const days = daysBetween(e.date, latest.date);
      return days >= t.kittenLookbackMinDays && days <= t.kittenLookbackMaxDays;
    }).at(-1);
    if (earlier && latest.weightKg <= earlier.weightKg) stops.push('kitten-not-growing');
  }
  return stops;
}
function suggest(cat: Cat, asOf: string, estimate: EnergyEstimate, series: WeightSeries): Suggestion | null {
  const rate = series.ratePercentPerWeek, floor = estimate.floorKcal ?? 0, target = cat.targetKcal;
  // Suggestions are defined for adult and senior plans only; kittens grow and queens are reference-only.
  if (estimate.status !== 'ok' || rate === null || (estimate.stage !== 'adult' && estimate.stage !== 'senior')) return null;
  const increase = Math.max(target * t.increaseFactor, floor), decrease = Math.max(target * t.decreaseFactor, floor);
  if (cat.goal === 'loss') {
    const ibw = estimate.idealWeight?.kg ?? cat.weightKg;
    if (series.latest!.weightKg <= ibw)
      return { action: 'switch-to-maintenance', reason: 'ideal-weight-reached', suggestedKcal: maintainStartKcal(cat, ibw, floor).kcal };
    if (rate < t.lossTooFastRate) return { action: 'increase', reason: 'loss-too-fast', suggestedKcal: increase };
    if (rate <= t.lossOnTrackSlowestRate) return { action: 'none', reason: 'on-track', suggestedKcal: null };
    if (rate <= t.lossSlowRate || series.spanDays < t.plateauMinSpanDays) return { action: 'hold', reason: 'slow-recheck-2-weeks', suggestedKcal: null };
    return target * t.decreaseFactor < floor ? { action: 'refer', reason: 'at-floor', suggestedKcal: null }
      : { action: 'decrease', reason: 'plateau', suggestedKcal: decrease };
  }
  if (cat.goal === 'maintain') {
    const change = series.change28dPercent!;
    if (change >= t.maintainChangePercent) return { action: 'decrease', reason: 'gaining', suggestedKcal: decrease };
    if (change <= -t.maintainChangePercent) return { action: 'increase', reason: 'losing', suggestedKcal: increase };
    return { action: 'none', reason: 'stable', suggestedKcal: null };
  }
  const bcs = effectiveBcs(cat, asOf);
  if (bcs !== null && bcs >= model.bcs.ideal) return { action: 'switch-to-maintenance', reason: 'ideal-condition-reached', suggestedKcal: null };
  if (rate > t.gainTooFastRate) return { action: 'decrease', reason: 'gain-too-fast', suggestedKcal: decrease };
  if (rate <= t.gainStalledRate && series.spanDays >= t.gainStalledMinSpanDays) return { action: 'increase', reason: 'not-gaining', suggestedKcal: increase };
  return { action: 'none', reason: 'on-track', suggestedKcal: null };
}
export function trendFor(cat: Cat, asOf: string, estimate: EnergyEstimate, series: WeightSeries): Trend {
  return {
    entries: series.entries.length, latestKg: series.latest?.weightKg ?? null,
    ratePercentPerWeek: series.ratePercentPerWeek, change28dPercent: series.change28dPercent,
    suggestion: suggest(cat, asOf, estimate, series),
    nextWeighInDays: estimate.stage === 'kitten' ? t.weighInKittenDays : cat.goal === 'loss' ? t.weighInLossDays
      : isRecentlyNeutered(cat.profile, asOf) ? t.weighInRecentlyNeuteredDays : t.weighInOtherDays,
  };
}
