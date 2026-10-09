import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { calculatePlan, parsePlan, parsePlanJSON, planToJSON, planToCSV, kcalPerGram, energyInUnit, rer, allocateRounded, PlanError } from '../../../dist/web/packages/core/src/index.js';
const seed = JSON.parse(readFileSync(new URL('../../../shared/default-plan.json', import.meta.url), 'utf8'));
const v1Vectors = JSON.parse(readFileSync(new URL('./fixtures/golden-cases-v1.json', import.meta.url), 'utf8'));
const asOf = '2026-10-09', opts = { asOf };
const clone = () => structuredClone(seed);
const close = (actual, expected) => assert.ok(Math.abs(actual - expected) < 1e-8, `${actual} ≠ ${expected}`);
test('CALCULATIONS.md Luna example keeps full precision until final portion rounding', () => {
  const r = calculatePlan(seed, opts).cats[0];
  close(r.fixedKcal, 159.133294);
  close(r.balanceKcal, 30.866706);
  close(r.balanceGramsExact, 8.071643619);
  assert.equal(r.balanceGramsRounded, 8);
  close(r.roundedDailyKcal, 189.7260282256214);
  assert.deepEqual(r.activities.map(a => a.roundedGrams), [3, 2, 3]);
});
for (const vector of v1Vectors) test(`v1 golden migrates with identical allocation: ${vector.name}`, () => {
  const result = calculatePlan(vector.plan, opts);
  for (const expected of vector.expected.cats) {
    const actual = result.cats.find(cat => cat.id === expected.id);
    for (const [key, old] of [['fixedGrams', 'wetGrams'], ['fixedKcal', 'wetKcal'], ['balanceKcal', 'dryKcal'], ['balanceGramsExact', 'dryGramsExact'],
      ['balanceGramsRounded', 'dryGramsRounded'], ['overBudgetKcal', 'overBudgetKcal']]) close(actual[key], expected[old]);
    assert.deepEqual(actual.activities.map(a => a.roundedGrams), expected.activityRoundedGrams);
  }
  close(result.totals.balanceGramsExact, vector.expected.totalDryGramsExact);
  assert.equal(result.totals.balanceGramsRounded, vector.expected.totalDryGramsRounded);
});
test('regression: the example household portions on 2026-10-09', () => {
  const result = calculatePlan(seed, opts);
  assert.deepEqual(seed.cats.map(c => c.targetKcal), [190, 145, 266, 210, 231]);
  assert.deepEqual(result.cats.map(c => c.balanceGramsRounded), [8, 11, 59, 280, 160]);
  assert.deepEqual(result.cats.map(c => c.activities.map(a => a.roundedGrams)), [[3, 2, 3], [3, 3, 5], [18, 18, 23], [84, 84, 112], [48, 48, 64]]);
  assert.deepEqual(result.cats.map(c => c.fixedGrams), [170, 140, 40, 0, 0]);
  assert.equal(result.totals.balanceGramsRounded, 518);
  assert.deepEqual(result.totals.balanceByFood.map(b => [b.foodId, b.gramsRounded]), [['dry-adult', 19], ['dry-kitten', 59], ['wet-fish', 280], ['raw-mix', 160]]);
  assert.deepEqual(result.cats.map(c => [c.estimate.status, c.estimate.equation, Math.round(c.estimate.startKcal)]),
    [['ok', 'adult-fediaf', 190], ['ok', 'weight-loss-aaha', 145], ['ok', 'kitten-nrc', 266], ['reference-only', 'adult-fediaf', 183], ['ok', 'adult-fediaf', 231]]);
  assert.deepEqual(result.cats[1].trend.suggestion, { action: 'none', reason: 'on-track', suggestedKcal: null });
  assert.deepEqual(result.cats.map(c => c.nutrition.status === 'ok' ? [...c.nutrition.warnings, ...c.nutrition.notes] : c.nutrition.status),
    [[], ['protein-below-5g-per-kg-ibw'], [], ['ckd-protein-vet'], []]);
});
test('1600 kJ/100g uses exact 4.184 conversion, not rounded 3.824', () => close(kcalPerGram(seed.foods[2]), 1600 / 4.184 / 100));
test('conversion between all four label units preserves energy density', () => {
  for (const unit of ['kcal/100g', 'kJ/100g', 'kcal/kg', 'kJ/kg']) {
    close(kcalPerGram({ energyPerUnit: energyInUnit(seed.foods[2], unit), energyUnit: unit }), kcalPerGram(seed.foods[2]));
  }
});
test('goals and current weights never silently change chosen targets', () => {
  const p = clone(); p.cats[0].weightKg = 4; p.cats[0].goal = 'gain';
  close(calculatePlan(p, opts).cats[0].balanceGramsExact, calculatePlan(seed, opts).cats[0].balanceGramsExact);
});
test('unconfirmed source and completeness warnings are preserved', () => {
  assert.deepEqual(calculatePlan(seed, opts).cats.map(c => c.warnings), [['estimated-energy'], ['estimated-energy', 'provisional-target'],
    ['provisional-target'], [], ['estimated-energy', 'unknown-completeness']]);
});
test('balance-food warnings follow delivered grams after rounding', () => {
  for (const [target, fixed, grams, overTen] of [[190, 189.6, 0, false], [199, 179.4, 20, true], [194, 174.6, 19, false]]) {
    const p = clone(); p.cats = [p.cats[0]];
    const c = p.cats[0], complete = p.foods[0], balance = p.foods[2];
    Object.assign(complete, { energyPerUnit: 100, energyUnit: 'kcal/100g', energySource: 'label', completeness: 'complete', analysis: null });
    Object.assign(balance, { energyPerUnit: 100, energyUnit: 'kcal/100g', energySource: 'estimate', completeness: 'complementary', analysis: null });
    Object.assign(c, { targetKcal: target, extraKcal: 0, targetSource: 'owner', balanceFoodId: balance.id,
      meals: [{ id: 'fixed', label: 'Fixed meal', foodId: complete.id, grams: fixed }] });
    const r = calculatePlan(p, opts).cats[0];
    assert.equal(r.balanceGramsRounded, grams);
    assert.equal(r.warnings.includes('complementary-balance-food'), grams > 0);
    assert.equal(r.warnings.includes('estimated-energy'), grams > 0);
    assert.equal(r.warnings.includes('extras-over-10-percent'), overTen);
    balance.completeness = 'unknown';
    assert.equal(calculatePlan(p, opts).cats[0].warnings.includes('unknown-completeness'), grams > 0);
  }
});
test('confirmed complete foods and veterinarian target remove those warnings', () => {
  const p = clone();
  p.foods.forEach(f => { f.energyPerUnit ??= 100; f.energySource = 'label'; f.completeness = 'complete'; }); p.cats.forEach(c => { c.targetSource = 'veterinarian'; });
  assert.deepEqual(calculatePlan(p, opts).cats.map(c => c.warnings), [[], [], [], [], []]);
});
test('unused estimated foods do not taint a confirmed ration', () => {
  const p = clone(); p.cats[0].meals = [];
  assert.deepEqual(calculatePlan(p, opts).cats[0].warnings, []);
});
test('supplementary calories above 10% trigger a warning; exactly 10% does not', () => {
  const p = clone(); p.cats[0].extraKcal = 19;
  assert.ok(!calculatePlan(p, opts).cats[0].warnings.includes('extras-over-10-percent'));
  p.cats[0].extraKcal = 19.1; assert.ok(calculatePlan(p, opts).cats[0].warnings.includes('extras-over-10-percent'));
});
test('complementary balance food is flagged instead of treated as a complete ration', () => {
  const p = clone(); p.foods[2].completeness = 'complementary';
  assert.ok(calculatePlan(p, opts).cats[0].warnings.includes('complementary-balance-food'));
});
test('whole-gram household total sums rounded containers, not rounded household arithmetic', () => {
  const p = clone(); p.cats.forEach(c => { c.meals = []; c.targetKcal = 10; });
  const r = calculatePlan(p, opts);
  assert.deepEqual(r.cats.map(c => c.balanceGramsRounded), [3, 3, 3, 13, 7]);
  assert.equal(r.totals.balanceGramsRounded, 29); assert.equal(Math.round(r.totals.balanceGramsExact), 28);
});
test('allocation uses stable tie-breaks and preserves the rounded ration', () => {
  assert.deepEqual(allocateRounded(5, [{ id: 'a', label: 'A', sharePercent: 50 }, { id: 'b', label: 'B', sharePercent: 50 }]), [3, 2]);
});
test('JSON round-trip keeps all known user input fields', () => assert.deepEqual(parsePlanJSON(planToJSON(seed)), seed));
test('JSON export writes explicit nulls for empty nullable fields', () => {
  const p = clone(); delete p.foods[1].analysis; delete p.cats[0].profile.birthDate; delete p.cats[0].profile.idealWeightSource;
  const json = JSON.parse(planToJSON(p));
  assert.equal(json.schemaVersion, 2); assert.equal(json.foods[1].analysis, null); assert.equal(json.cats[0].profile.birthDate, null);
  assert.equal(json.cats[0].profile.idealWeightSource, null); assert.equal(json.cats[1].profile.idealWeightSource, 'estimate');
});
test('unknown fields are ignored', () => assert.deepEqual(parsePlan({ ...seed, future: 'ignored' }), seed));
test('calculation does not mutate user input', () => { const p = clone(), original = JSON.stringify(p); calculatePlan(p, opts); assert.equal(JSON.stringify(p), original); });
test('calculatePlan requires a strict asOf date', () => {
  for (const bad of [undefined, {}, { asOf: '2026-2-1' }, { asOf: '2026-02-30' }, { asOf: 20261009 }])
    assert.throws(() => calculatePlan(seed, bad), PlanError);
});
test('CSV escapes commas, quotes, line breaks and formula-like names', () => {
  const p = clone(); p.cats[0].name = '=HYPERLINK("x")'; p.cats[1].name = 'A, "B"';
  p.cats[2].profile.birthDate = null;
  const csv = planToCSV(p, opts); assert.ok(csv.includes(`"'=HYPERLINK(""x"")"`)); assert.ok(csv.includes('"A, ""B"""'));
  assert.ok(csv.includes('Balance food rounded (g/day)')); assert.ok(csv.includes('"Estimate status"')); assert.ok(csv.includes('"needs-input","",""'));
});
test('CSV includes the estimate start and range when available', () => {
  const row = planToCSV(seed, opts).split('\r\n')[2];
  const e = calculatePlan(seed, opts).cats[1].estimate;
  assert.ok(row.includes(`"ok","${e.startKcal.toFixed(0)}","${e.lowKcal.toFixed(0)}–${e.highKcal.toFixed(0)}"`), row);
  assert.ok(row.includes('"Example dry food, adult"'));
});
for (const [name, mutate] of [
  ['future schema', p => p.schemaVersion = 3], ['string number', p => p.cats[0].targetKcal = '220'],
  ['NaN', p => p.cats[0].weightKg = NaN], ['infinity', p => p.cats[0].targetKcal = Infinity],
  ['negative grams', p => p.cats[0].meals[0].grams = -1], ['zero energy', p => p.foods[3].energyPerUnit = 0],
  ['implausible energy unit/value', p => p.foods[3].energyPerUnit = 50000],
  ['unknown unit', p => p.foods[3].energyUnit = 'kcal/cup'], ['duplicate food ID', p => p.foods[1].id = p.foods[0].id],
  ['duplicate cat ID', p => p.cats[1].id = p.cats[0].id], ['duplicate meal ID', p => p.cats[0].meals[1].id = p.cats[0].meals[0].id],
  ['missing food reference', p => p.cats[0].meals[0].foodId = 'missing'], ['missing balance food reference', p => p.cats[0].balanceFoodId = 'missing'],
  ['zero cats', p => p.cats = []], ['blank name', p => p.cats[0].name = '  '],
  ['shares not 100', p => p.activities[0].sharePercent = 29], ['negative share', p => p.activities[0].sharePercent = -1],
  ['too many meals', p => p.cats[0].meals = Array.from({ length: 25 }, (_, i) => ({ ...p.cats[0].meals[0], id: `m${i}` }))],
]) test(`rejects invalid input: ${name}`, () => { const p = clone(); mutate(p); assert.throws(() => parsePlan(p), PlanError); });
test('invalid JSON and oversized files are rejected', () => {
  assert.throws(() => parsePlanJSON('{'), /invalid JSON/);
  assert.throws(() => parsePlanJSON(' '.repeat(1_048_577)), /maximum size/);
});
test('RER rejects invalid weights', () => { for (const n of [0, -1, NaN, Infinity]) assert.throws(() => rer(n)); });
test('invalid allocation arguments are rejected', () => { assert.throws(() => allocateRounded(-1, seed.activities)); assert.throws(() => allocateRounded(5, [])); });
test('200 deterministic scenarios conserve calories and enrichment portions', () => {
  let state = 73; const random = () => ((state = (1664525 * state + 1013904223) >>> 0) / 4294967296);
  for (let i = 0; i < 200; i++) {
    const p = clone(); p.cats.forEach(c => { c.targetKcal = 180 + random() * 160; c.extraKcal = random() * 20; c.meals.forEach(m => { m.grams = random() * 100; }); });
    const r = calculatePlan(p, opts);
    r.cats.forEach((c, index) => {
      assert.ok(c.balanceGramsExact >= 0); assert.equal(c.activities.reduce((n, a) => n + a.roundedGrams, 0), c.balanceGramsRounded);
      close(c.fixedKcal + c.extraKcal + c.balanceKcal, p.cats[index].targetKcal + c.overBudgetKcal);
    });
  }
});
test('calculatePlan never changes targetKcal, whatever the profile, estimate or trend', () => {
  let state = 11; const random = () => ((state = (1664525 * state + 1013904223) >>> 0) / 4294967296);
  const pick = list => list[Math.floor(random() * list.length)];
  for (let i = 0; i < 300; i++) {
    const p = clone();
    p.cats.forEach(c => {
      c.goal = pick(['loss', 'maintain', 'gain']); c.targetSource = pick(['provisional', 'owner', 'veterinarian']);
      Object.assign(c.profile, { birthDate: null, approxAgeYears: pick([null, 0.3, 2, 8, 13]), neutered: pick(['yes', 'no', 'unknown']), bcs: pick([null, 2, 4, 5, 7, 9]),
        mcs: pick([null, 'normal', 'severe']), lifestyle: pick([null, 'sedentary', 'active']), idealWeightKg: pick([null, 3.5]),
        expectedAdultWeightKg: pick([null, 4.5]), verifiedIntakeKcal: pick([null, 120, 250]), medical: pick([[], ['ckd'], ['not-eating']]) });
      c.profile.idealWeightSource = c.profile.idealWeightKg === null ? null : pick(['veterinarian', 'estimate']);
      c.weightLog = [{ id: 'a', date: '2026-09-11', weightKg: c.weightKg * (0.9 + random() * 0.2), bcs: null },
        { id: 'b', date: '2026-10-09', weightKg: c.weightKg, bcs: pick([null, 4, 6]) }];
    });
    const before = p.cats.map(c => c.targetKcal);
    const r = calculatePlan(p, opts);
    assert.deepEqual(p.cats.map(c => c.targetKcal), before);
    r.cats.forEach((c, index) => close(c.fixedKcal + c.extraKcal + c.balanceKcal, before[index] + c.overBudgetKcal));
    assert.equal(r.totals.targetKcal, before.reduce((a, b) => a + b, 0));
  }
});
