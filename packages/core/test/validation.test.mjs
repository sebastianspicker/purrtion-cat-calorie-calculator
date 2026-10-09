import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parsePlan, parsePlanJSON, migrateV1, defaultProfile, calculatePlan, planToJSON, PlanError } from '../../../dist/web/packages/core/src/index.js';
const seed = JSON.parse(readFileSync(new URL('../../../shared/default-plan.json', import.meta.url), 'utf8'));
const v1 = JSON.parse(readFileSync(new URL('./fixtures/golden-cases-v1.json', import.meta.url), 'utf8'))[0].plan;
const clone = () => structuredClone(seed);
const analysis = { moisture: 78, protein: 10, fat: 5, fibre: 0.5, ash: 2, kind: 'prepared' };

/** The v2 form of the v1 fixture, written out by hand (ENGINE.md §9). */
const v1AsV2 = () => ({ schemaVersion: 2, name: v1.name,
  foods: v1.foods.map(f => ({ ...f, lifeStageClaim: 'unknown', analysis: null })),
  cats: v1.cats.map(({ dryFoodId, ...c }) => ({ ...c, icon: null, balanceFoodId: dryFoodId, profile: defaultProfile(), weightLog: [] })),
  activities: v1.activities });
test('migration: a v1 document becomes v2 with all-null/unknown defaults', () => {
  const migrated = parsePlan(v1);
  assert.deepEqual(migrated, v1AsV2());
  assert.equal(migrated.schemaVersion, 2);
  for (const c of migrated.cats) { assert.equal(c.balanceFoodId, 'dry'); assert.deepEqual(c.profile, defaultProfile()); assert.deepEqual(c.weightLog, []); assert.ok(!('dryFoodId' in c)); }
  for (const f of migrated.foods) { assert.equal(f.analysis, null); assert.equal(f.lifeStageClaim, 'unknown'); }
  assert.equal(defaultProfile().idealWeightSource, null);
  assert.deepEqual(migrateV1(v1), v1AsV2());
});
test('migration: v1 allocation results are identical after migration', () => {
  const a = calculatePlan(v1, { asOf: '2026-10-09' }), b = calculatePlan(v1AsV2(), { asOf: '2026-10-09' });
  assert.deepEqual(a, b);
  assert.deepEqual(a.cats.map(c => c.balanceGramsRounded), [26, 24, 39]);
});
test('migration: export of a v1 import is always v2', () => assert.equal(JSON.parse(planToJSON(v1)).schemaVersion, 2));
test('migration: v1 documents keep their v1 type rules', () => {
  const p = structuredClone(v1); p.cats[0].dryFoodId = 'wet-a'; assert.throws(() => parsePlan(p), /dry food/);
  const q = structuredClone(v1); q.cats[0].meals[0].foodId = 'dry'; assert.throws(() => parsePlan(q), /wet food/);
  const r = structuredClone(v1); r.foods[0].energySource = 'analysis'; assert.throws(() => parsePlan(r), PlanError);
});
test('v2: fixed meals and the balance food may use any food', () => {
  const p = clone(); p.cats[0].balanceFoodId = 'wet-chicken'; p.cats[0].meals[0].foodId = 'dry-adult';
  assert.equal(parsePlan(p).cats[0].balanceFoodId, 'wet-chicken');
});
test('v2: nullable fields accept a missing key or null; analysis-sourced energy may omit energyPerUnit', () => {
  const p = clone(); delete p.cats[0].profile.bcs; delete p.foods[1].analysis;
  p.foods[2] = { ...p.foods[2], energySource: 'analysis', energyPerUnit: null, analysis };
  const parsed = parsePlan(p);
  assert.equal(parsed.cats[0].profile.bcs, null); assert.equal(parsed.foods[1].analysis, null); assert.equal(parsed.foods[2].energyPerUnit, null);
  const q = clone(); delete q.foods[2].energyPerUnit; q.foods[2].energySource = 'analysis'; q.foods[2].analysis = analysis;
  assert.equal(parsePlan(q).foods[2].energyPerUnit, null);
});
test('v2: idealWeightSource is null if and only if idealWeightKg is null; a missing source decodes as veterinarian (D3)', () => {
  const p = clone(); p.cats[0].profile.idealWeightKg = 3.8; delete p.cats[0].profile.idealWeightSource;
  p.cats[4].profile.idealWeightKg = 3.4; p.cats[4].profile.idealWeightSource = null;
  const parsed = parsePlan(p);
  assert.equal(parsed.cats[0].profile.idealWeightSource, 'veterinarian'); assert.equal(parsed.cats[4].profile.idealWeightSource, 'veterinarian');
  assert.equal(parsed.cats[1].profile.idealWeightSource, 'estimate'); assert.equal(parsed.cats[2].profile.idealWeightSource, null);
  const round = parsePlanJSON(planToJSON(parsed));
  assert.deepEqual(round.cats.map(c => c.profile.idealWeightSource), ['veterinarian', 'estimate', null, null, 'veterinarian']);
  assert.equal(calculatePlan(round, { asOf: '2026-10-09' }).cats[1].estimate.idealWeight.source, 'estimate');
});
test('v2: the optional cat icon round-trips; a missing icon decodes as null and is exported as null', () => {
  assert.deepEqual(parsePlan(seed).cats.map(c => c.icon), ['moon', 'scale', 'dango', 'stripes', 'bolt']);
  const p = clone(); p.cats[0].icon = 'heart'; delete p.cats[1].icon; p.cats[2].icon = null;
  const round = parsePlanJSON(planToJSON(p));
  assert.deepEqual(round.cats.map(c => c.icon), ['heart', null, null, 'stripes', 'bolt']);
  assert.equal(JSON.parse(planToJSON(p)).cats[1].icon, null);
  assert.ok(parsePlan(v1).cats.every(c => c.icon === null));
});
test('v2: a valid full profile and weight log round-trip', () => {
  const p = clone();
  p.cats[0].profile = { ...defaultProfile(), birthDate: '2020-02-29', sex: 'female', neutered: 'yes', neuteredDate: '2020-09-01', lifestyle: 'sedentary',
    bcs: 7, mcs: 'mild', idealWeightKg: 5, idealWeightSource: 'estimate', expectedAdultWeightKg: null, medical: ['ckd', 'diabetes'], verifiedIntakeKcal: 240,
    reproduction: { status: 'none', litterSize: null, lactationWeek: null, preBreedingWeightKg: null } };
  p.cats[0].weightLog = [{ id: 'w1', date: '2026-09-01', weightKg: 6.1, bcs: 7 }, { id: 'w2', date: '2026-10-01', weightKg: 6, bcs: null }];
  assert.deepEqual(parsePlan(p), p);
});
for (const [name, mutate] of [
  ['energySource analysis without analysis', p => { p.foods[0].analysis = null; }],
  ['null energy without analysis source', p => { p.foods[1].energyPerUnit = null; }],
  ['unknown energy source', p => { p.foods[0].energySource = 'guess'; }],
  ['unknown life-stage claim', p => { p.foods[0].lifeStageClaim = 'senior'; }],
  ['missing life-stage claim', p => { delete p.foods[0].lifeStageClaim; }],
  ['analysis value above 100', p => { p.foods[0].analysis = { ...analysis, protein: 101 }; }],
  ['negative analysis value', p => { p.foods[0].analysis = { ...analysis, fat: -1 }; }],
  ['analysis sum above 100', p => { p.foods[0].analysis = { ...analysis, protein: 20 }; }],
  ['null moisture on wet food', p => { p.foods[0].analysis = { ...analysis, moisture: null }; }],
  ['moisture of 100', p => { p.foods[3].analysis = { moisture: 100, protein: 0, fat: 0, fibre: 0, ash: 0, kind: 'prepared' }; }],
  ['unknown analysis kind', p => { p.foods[0].analysis = { ...analysis, kind: 'raw' }; }],
  ['implausible computed density', p => { p.foods[0] = { ...p.foods[0], energySource: 'analysis', analysis: { moisture: 99.5, protein: 0.2, fat: 0, fibre: 0, ash: 0.3, kind: 'fresh' } }; }],
  ['missing profile', p => { delete p.cats[0].profile; }],
  ['missing weight log', p => { delete p.cats[0].weightLog; }],
  ['invalid birth date', p => { p.cats[0].profile.birthDate = '2023-02-29'; }],
  ['non-ISO birth date', p => { p.cats[0].profile.birthDate = '09.10.2020'; }],
  ['invalid neutered date', p => { p.cats[0].profile.neuteredDate = '2026-13-01'; }],
  ['approximate age above 30', p => { p.cats[0].profile.approxAgeYears = 31; }],
  ['unknown sex', p => { p.cats[0].profile.sex = 'x'; }],
  ['unknown neutered value', p => { p.cats[0].profile.neutered = true; }],
  ['unknown lifestyle', p => { p.cats[0].profile.lifestyle = 'lazy'; }],
  ['fractional BCS', p => { p.cats[0].profile.bcs = 5.5; }],
  ['BCS above 9', p => { p.cats[0].profile.bcs = 10; }],
  ['unknown MCS', p => { p.cats[0].profile.mcs = 'none'; }],
  ['ideal weight below 0.1 kg', p => { p.cats[0].profile.idealWeightKg = 0.05; }],
  ['ideal weight source without ideal weight', p => { p.cats[0].profile.idealWeightSource = 'estimate'; }],
  ['ideal weight cleared but source kept', p => { p.cats[1].profile.idealWeightKg = null; }],
  ['unknown cat icon', p => { p.cats[0].icon = 'dragon'; }],
  ['non-string cat icon', p => { p.cats[0].icon = 3; }],
  ['unknown ideal weight source', p => { p.cats[1].profile.idealWeightSource = 'bcs-estimate'; }],
  ['expected adult weight above 40 kg', p => { p.cats[0].profile.expectedAdultWeightKg = 41; }],
  ['unknown reproduction status', p => { p.cats[0].profile.reproduction.status = 'pregnant'; }],
  ['litter size 13', p => { p.cats[0].profile.reproduction.litterSize = 13; }],
  ['fractional lactation week', p => { p.cats[0].profile.reproduction.lactationWeek = 2.5; }],
  ['missing reproduction', p => { delete p.cats[0].profile.reproduction; }],
  ['unknown medical flag', p => { p.cats[0].profile.medical = ['flu']; }],
  ['duplicate medical flag', p => { p.cats[0].profile.medical = ['ckd', 'ckd']; }],
  ['non-boolean end of life', p => { p.cats[0].profile.endOfLife = 'no'; }],
  ['verified intake above 3000', p => { p.cats[0].profile.verifiedIntakeKcal = 3001; }],
  ['weight entry with invalid date', p => { p.cats[0].weightLog = [{ id: 'w', date: '2026-02-30', weightKg: 4, bcs: null }]; }],
  ['weight entry below 0.1 kg', p => { p.cats[0].weightLog = [{ id: 'w', date: '2026-02-01', weightKg: 0, bcs: null }]; }],
  ['weight entry BCS 0', p => { p.cats[0].weightLog = [{ id: 'w', date: '2026-02-01', weightKg: 4, bcs: 0 }]; }],
  ['duplicate weight entry ID', p => { p.cats[0].weightLog = [{ id: 'w', date: '2026-02-01', weightKg: 4, bcs: null }, { id: 'w', date: '2026-02-02', weightKg: 4, bcs: null }]; }],
  ['more than 1000 weight entries', p => { p.cats[0].weightLog = Array.from({ length: 1001 }, (_, i) => ({ id: `w${i}`, date: '2026-02-01', weightKg: 4, bcs: null })); }],
  ['dryFoodId instead of balanceFoodId in v2', p => { p.cats[0].dryFoodId = p.cats[0].balanceFoodId; delete p.cats[0].balanceFoodId; }],
]) test(`v2 rejects: ${name}`, () => { const p = clone(); mutate(p); assert.throws(() => parsePlan(p), PlanError); });

// Control characters and bidirectional overrides/isolates in text (same rule as the Swift core).
const forbiddenSingle = ['\u0000', '\u0009', '\u000A', '\u000D', '\u001F', '\u007F', '\u202A', '\u202B', '\u202C', '\u202D', '\u202E', '\u2066', '\u2067', '\u2068', '\u2069'];
const textFields = [
  ['plan name', (p, v) => { p.name = v; }], ['cat name', (p, v) => { p.cats[0].name = v; }], ['food name', (p, v) => { p.foods[0].name = v; }],
  ['meal label', (p, v) => { p.cats[0].meals[0].label = v; }], ['activity label', (p, v) => { p.activities[0].label = v; }],
];
for (const [field, set] of textFields) for (const ch of forbiddenSingle)
  test(`v2 rejects U+${ch.codePointAt(0).toString(16).toUpperCase().padStart(4, '0')} in ${field}`, () => {
    const p = clone(); set(p, `Mi${ch}mi`); assert.throws(() => parsePlan(p), /control or bidirectional/);
  });
test('v2 rejects forbidden characters in ids', () => {
  const p = clone(); p.cats[0].id = 'cat\u202E1'; assert.throws(() => parsePlan(p), PlanError);
  const q = clone(); q.foods[0].id = 'food\n'; assert.throws(() => parsePlan(q), PlanError);
});
test('v2 note: tab and line feed are allowed, other controls and bidi characters are not', () => {
  const p = clone(); p.foods[0].note = 'Line one\n\tindented line two'; assert.equal(parsePlan(p).foods[0].note, 'Line one\n\tindented line two');
  for (const ch of ['\u0000', '\u0008', '\u000B', '\u000D', '\u001F', '\u007F', '\u202A', '\u202E', '\u2066', '\u2069']) {
    const q = clone(); q.foods[0].note = `a${ch}b`; assert.throws(() => parsePlan(q), /control or bidirectional/, ch.codePointAt(0).toString(16));
  }
});
test('v2 accepts ordinary international text, including emoji and RTL letters', () => {
  const p = clone(); p.cats[0].name = 'Mieze ✨ 猫 قطة'; assert.equal(parsePlan(p).cats[0].name, 'Mieze ✨ 猫 قطة');
});
test('golden vector: a name containing U+202E (right-to-left override) is rejected', () => {
  const p = clone(); p.cats[0].name = 'Mimi\u202Egpj.exe';
  assert.throws(() => parsePlan(p), error => error instanceof PlanError && error.path === 'cats[0].name');
  assert.throws(() => parsePlanJSON(JSON.stringify(p)), PlanError);
  assert.throws(() => parsePlanJSON('{"schemaVersion":2,"name":"x\\u202Ey","foods":[],"cats":[],"activities":[]}'), PlanError);
});
