import test from 'node:test';
import assert from 'node:assert/strict';
import { calculatePlan, estimateEnergy, rer, mer, meKcalPer100g, atwaterKcalPer100g, analyseFood, nfe, weightSeries, trendStops, trendFor,
  checkNutrition, idealWeightOf, ageInDays, effectiveBcs, stageOf, kittenBandMultiplier, weightLossStartKcal, isISODate, daysBetween, todayLocalISO, kcalPerGram, defaultProfile,
  messageFor, messages, warningMessages, energyModel, catIcons } from '../../../dist/web/packages/core/src/index.js';
const asOf = '2026-10-09';
const near = (actual, expected, tolerance = 1e-9) => assert.ok(Math.abs(actual - expected) <= tolerance * Math.max(1, Math.abs(expected)), `${actual} ≠ ${expected}`);
const round2 = (actual, expected) => assert.equal(Math.round(actual * 100) / 100, expected, `${actual} does not round to ${expected}`);
const day = offset => new Date(Date.parse(`${asOf}T00:00:00Z`) + offset * 86400000).toISOString().slice(0, 10);
const cat = (o = {}, p = {}) => ({ id: 'c', name: 'Cat', weightKg: 4, goal: 'maintain', targetKcal: 190, targetSource: 'owner', extraKcal: 0,
  balanceFoodId: 'dry', meals: [], weightLog: [], ...o, profile: { ...defaultProfile(), approxAgeYears: 5, neutered: 'yes', bcs: 5, ...p } });
const wet = { moisture: 78, protein: 10, fat: 5, fibre: 0.5, ash: 2, kind: 'prepared' };
const dry = { moisture: 8, protein: 34, fat: 14, fibre: 3, ash: 7, kind: 'prepared' };

test('gain range remains ordered when a stored ideal weight makes the floor bind', () => {
  const e = estimateEnergy(cat({ goal: 'gain' }, { bcs: 4, lifestyle: 'sedentary', idealWeightKg: 8, idealWeightSource: 'veterinarian' }), asOf);
  assert.equal(e.equation, 'adult-gain');
  round2(e.floorKcal, 199.79);
  near(e.lowKcal, e.floorKcal); near(e.startKcal, e.floorKcal); near(e.highKcal, e.floorKcal);
  // Independent interval invariants over the accepted weight bounds and all adult goals.
  for (const weightKg of [0.1, 1, 4, 8, 40]) for (const idealWeightKg of [0.1, 1, 4, 8, 40])
    for (const lifestyle of ['sedentary', 'typical', 'active']) for (const goal of ['gain', 'maintain', 'loss']) {
      const result = estimateEnergy(cat({ weightKg, goal }, { bcs: 4, lifestyle, idealWeightKg, idealWeightSource: 'veterinarian' }), asOf);
      assert.ok(result.floorKcal <= result.lowKcal && result.lowKcal <= result.startKcal && result.startKcal <= result.highKcal,
        JSON.stringify({ weightKg, idealWeightKg, lifestyle, goal, result }));
    }
});

test('all trend reductions refer if a ten-percent cut crosses the floor', () => {
  for (const goal of ['maintain', 'gain', 'loss']) for (const targetKcal of [100, 120, 140, 190]) {
    const weightLog = [{ id: 'a', date: day(-21), weightKg: 4, bcs: null },
      { id: 'b', date: day(0), weightKg: goal === 'loss' ? 4 : 4.15, bcs: null }];
    const c = cat({ goal, targetKcal, weightKg: weightLog[1].weightKg, weightLog },
      { bcs: goal === 'gain' ? 4 : goal === 'loss' ? 6 : 5 });
    const before = structuredClone(c), series = weightSeries(c, asOf);
    const e = estimateEnergy(c, asOf, trendStops(c, series, stageOf(c, asOf)));
    const suggestion = trendFor(c, asOf, e, series).suggestion;
    assert.ok(suggestion);
    if (0.9 * targetKcal < e.floorKcal) {
      assert.deepEqual(suggestion, { action: 'refer', reason: 'at-floor', suggestedKcal: null });
    } else {
      assert.equal(suggestion.action, 'decrease'); near(suggestion.suggestedKcal, 0.9 * targetKcal);
      assert.ok(suggestion.suggestedKcal < targetKcal && suggestion.suggestedKcal >= e.floorKcal);
    }
    assert.deepEqual(c, before, 'suggestions must not mutate the plan');
  }
});

test('SCIENCE.md §12.2 anchors: MER, RER, kitten NRC, gestation, lactation, weight loss', () => {
  round2(mer(75, 4), 189.86); round2(mer(100, 4), 253.15); round2(rer(4), 197.99);
  round2(estimateEnergy(cat({ weightKg: 2 }, { approxAgeYears: null, birthDate: day(-91), expectedAdultWeightKg: 4 }), asOf).startKcal, 266.32);
  const queen = reproduction => cat({}, { approxAgeYears: 3, reproduction: { status: 'none', litterSize: null, lactationWeek: null, preBreedingWeightKg: null, ...reproduction } });
  round2(estimateEnergy(queen({ status: 'gestation', preBreedingWeightKg: 4 }), asOf).startKcal, 354.41);
  round2(estimateEnergy(queen({ status: 'lactation', litterSize: 4, lactationWeek: 4 }), asOf).startKcal, 541.15);
  round2(estimateEnergy(cat({ weightKg: 6, goal: 'loss' }, { bcs: 8 }), asOf).startKcal, 167.17);
});
test('SCIENCE.md §12.2 weight-loss vectors (D1): 80 % of the lower of RER and MER at ideal weight; verified intake', () => {
  const ibw = 6 / 1.3, floor = 0.6 * rer(ibw), loss = p => estimateEnergy(cat({ weightKg: 6, goal: 'loss' }, { bcs: 8, ...p }), asOf);
  round2(floor, 132.25);
  round2(weightLossStartKcal(ibw, 75, null, floor), 167.17); round2(weightLossStartKcal(ibw, 63.5, null, floor), 141.54);
  round2(weightLossStartKcal(ibw, 100, null, floor), 176.34);
  round2(weightLossStartKcal(ibw, 75, 200, floor), 160); round2(weightLossStartKcal(ibw, 75, 150, floor), 132.25);
  assert.equal(weightLossStartKcal(ibw, 75, 120, floor), null);
  const sedentary = loss({ lifestyle: 'sedentary' });
  round2(sedentary.startKcal, 141.54); assert.ok(sedentary.startKcal < mer(63.5, ibw)); near(sedentary.coefficient, 0.8);
  round2(loss({ lifestyle: 'active' }).startKcal, 176.34);
  round2(loss({ verifiedIntakeKcal: 200 }).startKcal, 160); round2(loss({ verifiedIntakeKcal: 150 }).startKcal, 132.25);
  const refer = loss({ verifiedIntakeKcal: 120 });
  assert.equal(refer.status, 'refer'); assert.deepEqual(refer.reasons, ['verified-intake-below-floor']);
  assert.equal(refer.startKcal, null); assert.equal(refer.idealWeight, null); assert.deepEqual(refer.notes, []);
});
test('SCIENCE.md §12.2 kitten vectors (D4): interpolated band, transition by age and by weight, cap on the start only', () => {
  const kitten = (bw, years, p = {}) => estimateEnergy(cat({ weightKg: bw }, { approxAgeYears: years, ...p }), asOf);
  near(kittenBandMultiplier(1, [2, 1.75, 1.5]), 2); near(kittenBandMultiplier(4, [2, 1.75, 1.5]), 2 - 2 / 4.5 * 0.25);
  near(kittenBandMultiplier(11, [2.5, 2, 1.5]), 1.5);
  const nrc4 = kitten(2, 1 / 3, { expectedAdultWeightKg: 4, neutered: 'no', lifestyle: null });
  round2(nrc4.startKcal, 266.32); round2(nrc4.lowKcal, 225.40); round2(nrc4.highKcal, 362.41); assert.ok(!nrc4.notes.includes('kitten-transition'));
  round2(kitten(2, 1 / 3, { neutered: 'no', lifestyle: null }).startKcal, 293.91);
  const age = kitten(3.4, 11 / 12, { expectedAdultWeightKg: 4 });
  round2(age.startKcal, 230.85); assert.equal(Math.round(age.lowKcal * 10) / 10, 144.7); assert.equal(Math.round(age.highKcal * 10) / 10, 340.6);
  assert.ok(age.notes.includes('kitten-transition'));
  round2(kitten(3.4, 11 / 12).startKcal, 234.13);
  round2(kitten(3.6, 0.75, { expectedAdultWeightKg: 4 }).startKcal, 233.54);
  const capped = kitten(0.8, 2 / 12, { expectedAdultWeightKg: 4, neutered: 'no', lifestyle: null });
  round2(capped.startKcal, 148.03); assert.ok(capped.notes.includes('clamped-high')); assert.ok(capped.highKcal > capped.startKcal * 1.1 - 1e-9);
  const bandCapped = kitten(1, 2 / 12, { neutered: 'no', lifestyle: null });
  near(bandCapped.startKcal, 2.5 * rer(1)); assert.ok(bandCapped.notes.includes('clamped-high'));
});
test('estimator: a kitten at its expected adult weight is an adult (growth-complete) and needs the adult inputs', () => {
  const grown = cat({ weightKg: 4 }, { approxAgeYears: 8 / 12, expectedAdultWeightKg: 4 });
  assert.equal(stageOf(grown, asOf), 'adult');
  const e = estimateEnergy(grown, asOf);
  assert.equal(e.lifeStageLabel, 'kitten'); assert.ok(e.notes.includes('growth-complete')); near(e.startKcal, mer(75, 4));
  const missing = estimateEnergy(cat({ weightKg: 4.1 }, { approxAgeYears: 8 / 12, expectedAdultWeightKg: 4, neutered: 'unknown', bcs: null }), asOf);
  assert.equal(missing.status, 'needs-input'); assert.deepEqual(missing.missing, ['bcs', 'neutered']);
  assert.equal(stageOf(cat({ weightKg: 3.9 }, { approxAgeYears: 8 / 12, expectedAdultWeightKg: 4 }), asOf), 'kitten');
});
test('SCIENCE.md §10.4 food anchors: wet ME4 99.25 / Atwater 93.25, dry ME4 379.5 / Atwater 357.0', () => {
  near(meKcalPer100g(wet), 99.2455); round2(meKcalPer100g(wet), 99.25); near(atwaterKcalPer100g(wet), 93.25);
  assert.equal(meKcalPer100g(dry).toFixed(1), '379.5'); near(atwaterKcalPer100g(dry), 357); near(nfe(wet), 4.5); near(nfe(dry), 34);
});
test('fresh food uses 4P + 8.5F + 4NFE and missing dry moisture assumes 8 %', () => {
  near(meKcalPer100g({ moisture: 70, protein: 18, fat: 9, fibre: 0.5, ash: 1.5, kind: 'fresh' }), 152.5);
  near(meKcalPer100g({ ...dry, moisture: null }), meKcalPer100g(dry));
  const result = analyseFood({ id: 'd', name: 'D', type: 'dry', energyPerUnit: 380, energyUnit: 'kcal/100g', energySource: 'label', completeness: 'complete',
    lifeStageClaim: 'adult', analysis: { ...dry, moisture: null }, note: '' });
  assert.deepEqual(result.warnings, ['assumed-moisture']); assert.equal(result.moisture, 8); assert.equal(result.method, 'fediaf-4-step');
});
test('food analysis derived values and warnings', () => {
  const food = { id: 'w', name: 'W', type: 'wet', energyPerUnit: 60, energyUnit: 'kcal/100g', energySource: 'label', completeness: 'complete',
    lifeStageClaim: 'all', analysis: wet, note: '' };
  const r = analyseFood(food), me = meKcalPer100g(wet);
  assert.deepEqual(r.warnings, ['label-energy-mismatch']);
  near(r.dryMatter.protein, 10 / 22 * 100); near(r.proteinGPer1000kcal, 10 / me * 1000); near(r.fatGPer1000kcal, 5 / me * 1000);
  near(r.carbGPer100kcal, 4.5 / me * 100);
  near(r.energySharePercent.protein + r.energySharePercent.fat + r.energySharePercent.carbohydrate, 100);
  assert.deepEqual(analyseFood({ ...food, energyPerUnit: 99 }).warnings, []);
  assert.deepEqual(analyseFood({ ...food, energySource: 'analysis', energyPerUnit: null }).warnings, []);
  assert.deepEqual(analyseFood({ ...food, energyPerUnit: 97, analysis: { moisture: 75, protein: 20, fat: 2, fibre: 0, ash: 3, kind: 'fresh' } }).warnings, ['atwater-disagreement']);
  assert.equal(analyseFood({ ...food, analysis: null }), null);
  near(kcalPerGram({ ...food, energySource: 'analysis', energyPerUnit: null }), me / 100);
  near(kcalPerGram(food), 0.6);
});
test('estimator: status precedence and null kcal fields for refer and needs-input', () => {
  const refer = estimateEnergy(cat({}, { bcs: 3, neutered: 'unknown' }), asOf);
  assert.equal(refer.status, 'refer'); assert.deepEqual(refer.reasons, ['bcs-low']); assert.deepEqual(refer.missing, ['neutered']);
  for (const key of ['startKcal', 'lowKcal', 'highKcal', 'floorKcal', 'referenceBand', 'comparison', 'equation']) assert.equal(refer[key], null, key);
  near(refer.rerKcal, rer(4));
  const needs = estimateEnergy(cat({}, { bcs: null }), asOf);
  assert.equal(needs.status, 'needs-input'); assert.deepEqual(needs.missing, ['bcs']); assert.equal(needs.startKcal, null);
  const trendStop = estimateEnergy(cat(), asOf, ['rapid-weight-change']);
  assert.equal(trendStop.status, 'refer'); assert.deepEqual(trendStop.reasons, ['rapid-weight-change']);
});
test('estimator: stage, life-stage label and age from birth date or approximate age', () => {
  const at = p => estimateEnergy(cat({}, { approxAgeYears: null, ...p }), asOf);
  assert.equal(at({ birthDate: '2016-10-09' }).stage, 'adult'); assert.equal(at({ birthDate: '2016-10-09' }).lifeStageLabel, 'mature-adult');
  assert.equal(at({ birthDate: '2015-10-08' }).stage, 'senior');
  assert.equal(at({ approxAgeYears: 2 }).lifeStageLabel, 'young-adult');
  assert.deepEqual(at({ birthDate: '2027-01-01' }).missing, ['age']);
  near(ageInDays(cat({}, { approxAgeYears: 2 }).profile, asOf), 730.5);
  assert.equal(stageOf(cat({}, { approxAgeYears: 0.1 }), asOf), 'neonate');
  assert.equal(stageOf(cat({}, { endOfLife: true }), asOf), 'end-of-life');
});
test('estimator: ideal weight from veterinarian, stored estimate, BCS or current weight', () => {
  assert.deepEqual(idealWeightOf(cat({}, { idealWeightKg: 3.5, idealWeightSource: 'veterinarian' }), 8), { kg: 3.5, lowKg: 3.5, highKg: 3.5, source: 'veterinarian' });
  const stored = idealWeightOf(cat({ weightKg: 5.4 }, { idealWeightKg: 4.6, idealWeightSource: 'estimate' }), 6);
  assert.equal(stored.source, 'estimate'); near(stored.kg, 4.6); near(stored.lowKg, 4.6 * 0.9); near(stored.highKg, 4.6 * 1.1);
  const bcs = idealWeightOf(cat({ weightKg: 6 }), 8); near(bcs.kg, 6 / 1.3); near(bcs.lowKg, 6 / 1.3 * 0.9); assert.equal(bcs.source, 'bcs-estimate');
  assert.equal(idealWeightOf(cat(), 5).source, 'current');
});
test('estimator: the profile BCS wins; otherwise the latest logged BCS on or before asOf', () => {
  const c = cat({ weightLog: [{ id: 'a', date: day(-9), weightKg: 4, bcs: 7 }, { id: 'b', date: day(-3), weightKg: 4, bcs: null },
    { id: 'c', date: day(10), weightKg: 4, bcs: 2 }] });
  assert.equal(effectiveBcs(c, asOf), 5);
  c.profile.bcs = null; assert.equal(effectiveBcs(c, asOf), 7);
  c.weightLog[0].bcs = null; assert.equal(effectiveBcs(c, asOf), null);
});
test('estimator: floor, clamps, comparison and recently-neutered cadence', () => {
  const loss = estimateEnergy(cat({ weightKg: 6, goal: 'loss', targetKcal: 110 }, { bcs: 8 }), asOf);
  near(loss.floorKcal, 0.6 * rer(6 / 1.3)); assert.ok(loss.lowKcal >= loss.floorKcal);
  assert.equal(loss.comparison.belowFloor, true); assert.equal(loss.comparison.differsOver30Percent, true); assert.equal(loss.comparison.belowRange, true);
  const clamped = estimateEnergy(cat({ weightKg: 1 }, { lifestyle: 'active' }), asOf);
  near(clamped.startKcal, 1.4 * rer(1)); assert.ok(clamped.notes.includes('clamped-high'));
  const neutered = cat({}, { neuteredDate: day(-182) });
  assert.ok(estimateEnergy(neutered, asOf).notes.includes('recently-neutered'));
  assert.equal(trendFor(neutered, asOf, estimateEnergy(neutered, asOf), weightSeries(neutered, asOf)).nextWeighInDays, 14);
  assert.ok(!estimateEnergy(cat({}, { neuteredDate: day(-183) }), asOf).notes.includes('recently-neutered'));
});
test('estimator: W is the ideal weight whenever it is below the current weight (D2)', () => {
  const vet = estimateEnergy(cat({ weightKg: 5 }, { idealWeightKg: 4.5, idealWeightSource: 'veterinarian' }), asOf);
  near(vet.weightUsedKg, 4.5); near(vet.startKcal, mer(75, 4.5)); assert.equal(Math.round(vet.startKcal * 10) / 10, 205.5);
  near(estimateEnergy(cat({ weightKg: 5, goal: 'gain' }, { bcs: 4, idealWeightKg: 4.8, idealWeightSource: 'veterinarian' }), asOf).startKcal, 1.15 * mer(75, 4.8));
  near(estimateEnergy(cat({ weightKg: 4 }, { idealWeightKg: 4.5, idealWeightSource: 'veterinarian' }), asOf).weightUsedKg, 4);
});
test('estimator: chronic medical flags give reference-only maintenance at current weight', () => {
  const e = estimateEnergy(cat({ weightKg: 5, goal: 'loss' }, { bcs: 8, medical: ['diabetes'] }), asOf);
  assert.equal(e.status, 'reference-only'); assert.equal(e.equation, 'adult-fediaf'); near(e.startKcal, mer(75, 5));
  assert.deepEqual(e.notes, ['diabetes-low-carb-info', 'medical-vet-plan']);
});
test('trend: least-squares rate, 28-day window and change', () => {
  const c = cat({ weightLog: [{ id: 'old', date: day(-60), weightKg: 3, bcs: null }, { id: 'a', date: day(-28), weightKg: 4, bcs: null },
    { id: 'b', date: day(-14), weightKg: 3.9, bcs: null }, { id: 'c', date: day(0), weightKg: 3.85, bcs: null }, { id: 'future', date: day(1), weightKg: 9, bcs: null }] });
  const s = weightSeries(c, asOf);
  assert.equal(s.entries.length, 4); assert.equal(s.window.length, 3); assert.equal(s.spanDays, 28);
  const xs = [0, 14, 28], ys = [4, 3.9, 3.85], mx = 14, my = (4 + 3.9 + 3.85) / 3;
  const slope = xs.reduce((n, x, i) => n + (x - mx) * (ys[i] - my), 0) / xs.reduce((n, x) => n + (x - mx) ** 2, 0);
  near(s.ratePercentPerWeek, slope * 7 / my * 100); near(s.change28dPercent, -3.75);
  assert.deepEqual(trendStops(c, s, 'adult'), []);
  const short = weightSeries(cat({ weightLog: [{ id: 'a', date: day(-6), weightKg: 4, bcs: null }, { id: 'b', date: day(0), weightKg: 4.1, bcs: null }] }), asOf);
  assert.equal(short.ratePercentPerWeek, null); assert.equal(short.change28dPercent, null);
});
test('trend: stops for rapid change and a kitten that is not growing', () => {
  const log = (a, b, days = 21) => [{ id: 'a', date: day(-days), weightKg: a, bcs: null }, { id: 'b', date: day(0), weightKg: b, bcs: null }];
  const stops = c => trendStops(c, weightSeries(c, asOf), stageOf(c, asOf));
  assert.deepEqual(stops(cat({ weightLog: log(4, 4.2) })), ['rapid-weight-change']);
  assert.deepEqual(stops(cat({ weightLog: log(4, 3.8) })), ['rapid-weight-change']);
  assert.deepEqual(stops(cat({ goal: 'loss', weightLog: log(4, 3.8) })), []);
  assert.deepEqual(stops(cat({ goal: 'loss', weightLog: log(4, 4.2) })), ['rapid-weight-change']);
  // D5: on a weight-loss plan, faster than 3 %/week or 8 % in 28 days stops the plan.
  assert.deepEqual(stops(cat({ goal: 'loss', weightLog: log(6, 5.6, 14) })), ['rapid-weight-change']);
  assert.deepEqual(stops(cat({ goal: 'loss', weightLog: log(6, 5.7, 14) })), []);
  const slowLarge = cat({ goal: 'loss', weightLog: [{ id: 'a', date: day(-28), weightKg: 6, bcs: null }, { id: 'b', date: day(-14), weightKg: 5.6, bcs: null },
    { id: 'c', date: day(0), weightKg: 5.5, bcs: null }] });
  assert.ok(weightSeries(slowLarge, asOf).ratePercentPerWeek > -3); assert.deepEqual(stops(slowLarge), ['rapid-weight-change']);
  assert.deepEqual(stops(cat({ goal: 'gain', weightLog: log(4, 3.81, 14) })), ['rapid-weight-change']);
  const kitten = w => cat({ weightKg: 1.5, weightLog: log(1.5, w, 7) }, { approxAgeYears: 0.3 });
  assert.deepEqual(stops(kitten(1.5)), ['kitten-not-growing']); assert.deepEqual(stops(kitten(1.6)), []);
  assert.deepEqual(stops(cat({ weightKg: 1.5, weightLog: log(1.5, 1.5, 15) }, { approxAgeYears: 0.3 })), []);
  // Growth is intended: a kitten gaining more than 5 % in 4 weeks is not a rapid-change stop.
  assert.deepEqual(stops(cat({ weightKg: 2, weightLog: log(1.5, 2) }, { approxAgeYears: 0.3 })), []);
});
test('trend: suggestions scale the current target and respect the floor', () => {
  const run = c => { const s = weightSeries(c, asOf); const e = estimateEnergy(c, asOf, trendStops(c, s, stageOf(c, asOf))); return trendFor(c, asOf, e, s); };
  const log = (...pairs) => pairs.map(([offset, kg], i) => ({ id: `w${i}`, date: day(offset), weightKg: kg, bcs: null }));
  const loss = (target, weightLog) => run(cat({ weightKg: 6, goal: 'loss', targetKcal: target, weightLog }, { bcs: 8 }));
  assert.deepEqual(loss(200, log([-14, 6], [0, 5.7])).suggestion, { action: 'increase', reason: 'loss-too-fast', suggestedKcal: 200 * 1.1 });
  assert.deepEqual(loss(200, log([-28, 6], [-14, 6], [0, 6])).suggestion, { action: 'decrease', reason: 'plateau', suggestedKcal: 180 });
  assert.deepEqual(loss(200, log([-21, 6], [-7, 6], [0, 6])).suggestion, { action: 'decrease', reason: 'plateau', suggestedKcal: 180 });
  assert.equal(loss(200, log([-20, 6], [-6, 6], [0, 6])).suggestion.action, 'hold');
  const gain = weightLog => run(cat({ goal: 'gain', targetKcal: 230, weightLog }, { bcs: 4 }));
  assert.equal(gain(log([-21, 4], [-7, 4], [0, 3.99])).suggestion.reason, 'not-gaining');
  assert.equal(gain(log([-20, 4], [-6, 4], [0, 3.99])).suggestion.reason, 'on-track');
  assert.deepEqual(loss(140, log([-28, 6], [-14, 6], [0, 6])).suggestion, { action: 'refer', reason: 'at-floor', suggestedKcal: null });
  assert.equal(loss(200, log([-14, 6], [0, 6])).suggestion.action, 'hold');
  assert.equal(loss(200, log([-14, 6], [0, 6])).nextWeighInDays, 14);
  assert.equal(run(cat({ weightLog: log([-14, 4], [0, 4.01]) }, { bcs: null })).suggestion, null);
  assert.equal(run(cat()).suggestion, null);
  assert.equal(run(cat()).nextWeighInDays, 28);
  assert.equal(gain(log([-14, 4], [0, 4])).nextWeighInDays, 14);
  // D8: a cat weighed exactly on the default cadence must still get a 28-day change and a rate (the window is inclusive).
  const onCadence = run(cat({ weightLog: log([-28, 4], [0, 4.12]) }));
  assert.ok(onCadence.change28dPercent !== null && onCadence.ratePercentPerWeek !== null);
  assert.equal(onCadence.suggestion.reason, 'gaining');
  const kitten = run(cat({ weightKg: 2, weightLog: log([-14, 1.8], [0, 2]) }, { approxAgeYears: 0.3 }));
  assert.equal(kitten.suggestion, null); assert.equal(kitten.nextWeighInDays, 7);
});
test('nutrition: protein minimum scaling, IBW protein, diabetic carbohydrate and growth claim', () => {
  const food = (id, analysis, claim = 'adult') => ({ id, name: id, type: 'dry', energyPerUnit: 380, energyUnit: 'kcal/100g', energySource: 'label',
    completeness: 'complete', lifeStageClaim: claim, analysis, note: '' });
  const c = cat({ goal: 'loss', weightKg: 6 }, { bcs: 8, medical: ['diabetes'] }), e = estimateEnergy(cat({ weightKg: 6, goal: 'loss' }, { bcs: 8 }), asOf);
  const r = checkNutrition(c, e, [{ food: food('d', dry), grams: 50 }], 190);
  near(r.proteinG, 17); near(r.proteinPer1000, 17 / 190 * 1000);
  near(r.minProteinPer1000, Math.max(62.5, 6250 / (190 / Math.pow(e.weightUsedKg, 0.67))));
  near(r.carbPercentME, 3.5 * 34 / 357 * 100); assert.deepEqual(r.notes, []);
  assert.deepEqual(r.warnings, ['carb-above-diabetic-threshold', 'protein-below-5g-per-kg-ibw', 'protein-below-minimum']);
  const kittenEstimate = estimateEnergy(cat({}, { approxAgeYears: 0.4 }), asOf);
  const k = checkNutrition(cat(), kittenEstimate, [{ food: food('d', dry), grams: 50 }], 190);
  assert.equal(k.minProteinPer1000, 70); assert.deepEqual(k.warnings, ['growth-claim-missing']);
  const queen = estimateEnergy(cat({}, { approxAgeYears: 3, reproduction: { status: 'gestation', litterSize: null, lactationWeek: null, preBreedingWeightKg: null } }), asOf);
  assert.equal(checkNutrition(cat(), queen, [{ food: food('d', dry, 'growth'), grams: 50 }], 190).minProteinPer1000, 75);
  assert.deepEqual(checkNutrition(cat(), kittenEstimate, [{ food: food('d', dry, 'growth'), grams: 50 }], 190).warnings, []);
  assert.deepEqual(checkNutrition(cat(), e, [{ food: food('x', null), grams: 5 }, { food: food('d', dry), grams: 50 }, { food: food('y', null), grams: 0 }], 190),
    { status: 'incomplete-data', missingFoodIds: ['x'] });
});
test('nutrition (D6): Atwater carbohydrate basis, CKD suppression, weight-loss equation only, not applicable for unusable estimates', () => {
  const food = (id, analysis, energy) => ({ id, name: id, type: 'wet', energyPerUnit: energy, energyUnit: 'kcal/100g', energySource: 'label',
    completeness: 'complete', lifeStageClaim: 'adult', analysis, note: '' });
  const e = estimateEnergy(cat(), asOf), wetFood = food('w', wet, 100), dryFood = food('d', dry, 380);
  round2(checkNutrition(cat(), e, [{ food: wetFood, grams: 100 }], 100).carbPercentME, 16.89);
  round2(checkNutrition(cat(), e, [{ food: dryFood, grams: 100 }], 380).carbPercentME, 33.33);
  round2(checkNutrition(cat(), e, [{ food: wetFood, grams: 100 }, { food: dryFood, grams: 30 }], 214).carbPercentME, 25.68);
  const ckdCat = cat({ weightKg: 5 }, { medical: ['ckd'] }), ckd = checkNutrition(ckdCat, estimateEnergy(ckdCat, asOf), [{ food: dryFood, grams: 39 }], 148.2);
  assert.ok(ckd.proteinPer1000 < ckd.minProteinPer1000); assert.deepEqual(ckd.warnings, []); assert.deepEqual(ckd.notes, ['ckd-protein-vet']);
  // A loss goal that falls back to maintenance (loss not indicated) does not get the 5 g/kg IBW check.
  const notIndicated = cat({ goal: 'loss' }), ni = estimateEnergy(notIndicated, asOf);
  assert.equal(ni.equation, 'adult-fediaf'); assert.deepEqual(checkNutrition(notIndicated, ni, [{ food: wetFood, grams: 190 }], 190).warnings, []);
  assert.deepEqual(checkNutrition(cat(), estimateEnergy(cat({}, { bcs: null }), asOf), [{ food: wetFood, grams: 100 }], 100), { status: 'not-applicable' });
  assert.deepEqual(checkNutrition(cat(), estimateEnergy(cat({}, { bcs: 3 }), asOf), [{ food: food('x', null, 100), grams: 100 }], 100), { status: 'not-applicable' });
});
test('nutrition is computed from rounded balance grams and food energy only', () => {
  const plan = { schemaVersion: 2, name: 'N', activities: [{ id: 'a', label: 'A', sharePercent: 100 }],
    foods: [{ id: 'dry', name: 'Dry', type: 'dry', energyPerUnit: 380, energyUnit: 'kcal/100g', energySource: 'label', completeness: 'complete', lifeStageClaim: 'adult', analysis: dry, note: '' }],
    cats: [cat({ extraKcal: 10 })] };
  const r = calculatePlan(plan, { asOf }).cats[0];
  near(r.nutrition.kcal, r.balanceGramsRounded * 3.8); near(r.nutrition.proteinG, r.balanceGramsRounded * 0.34);
});
test('dates are strict YYYY-MM-DD calendar dates', () => {
  for (const ok of ['2024-02-29', '2026-10-09', '1999-12-31']) assert.ok(isISODate(ok), ok);
  for (const bad of ['2023-02-29', '2026-13-01', '2026-1-01', '2026-10-09T00:00:00Z', ' 2026-10-09', '', null, 20261009]) assert.ok(!isISODate(bad), String(bad));
  assert.equal(daysBetween('2026-03-28', '2026-03-30'), 2);
  assert.equal(todayLocalISO(new Date(2026, 0, 5, 23, 59)), '2026-01-05');
});
test('messages: every locale has the same keys, and every engine code has text', () => {
  assert.deepEqual(Object.keys(messages.de).sort(), Object.keys(messages.en).sort());
  const codes = { warning: Object.keys(warningMessages), refer: ['neonate', 'end-of-life', 'acute-medical', 'bcs-low', 'mcs-severe', 'rapid-weight-change', 'kitten-not-growing',
    'verified-intake-below-floor'], note: ['kitten-transition', 'growth-complete', 'kitten-weigh-weekly', 'clamped-high'],
    idealWeight: ['veterinarian', 'estimate', 'bcs-estimate', 'current'], icon: [...catIcons],
    missing: ['age', 'neutered', 'bcs', 'mcs', 'litter-size', 'lactation-week'], equation: Object.keys(energyModel.references).filter(id => id !== 'rer' && id !== 'atwater'),
    food: ['assumed-moisture', 'atwater-disagreement', 'label-energy-mismatch'],
    nutrition: ['ok', 'incomplete-data', 'not-applicable', 'protein-below-minimum', 'protein-below-5g-per-kg-ibw', 'carb-above-diabetic-threshold',
      'growth-claim-missing', 'ckd-protein-vet'],
    action: ['switch-to-maintenance', 'increase', 'decrease', 'hold', 'none', 'refer'], status: ['ok', 'reference-only', 'needs-input', 'refer'] };
  for (const [prefix, list] of Object.entries(codes)) for (const code of list) for (const locale of ['en', 'de'])
    assert.ok(messageFor(`${prefix}.${code}`, locale)?.length > 0, `${locale} ${prefix}.${code}`);
  assert.match(messageFor('warning.unknown-completeness', 'de'), /Alleinfuttermittel/);
});
test('energy model is versioned and every equation has SCIENCE.md references', () => {
  assert.equal(energyModel.version, 2);
  for (const id of ['adult-fediaf', 'weight-loss-aaha', 'adult-gain', 'kitten-nrc', 'kitten-fediaf-band', 'gestation-fediaf', 'lactation-fediaf'])
    assert.ok(energyModel.references[id].length > 0, id);
});
