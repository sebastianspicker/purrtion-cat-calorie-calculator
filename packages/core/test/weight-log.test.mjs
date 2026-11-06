import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { addWeighIn, removeWeighIn, parsePlan } from '../../../dist/web/packages/core/src/index.js';
// Ports packages/swift-core/Tests/PurrtionCoreTests/WeightLogTests.swift so both apps keep the same weigh-in rules.
const sample = parsePlan(JSON.parse(readFileSync(new URL('../../../shared/default-plan.json', import.meta.url), 'utf8')));
const cat = () => ({ ...sample.cats[0], weightLog: [], weightKg: 4, profile: { ...sample.cats[0].profile, bcs: 5 } });
const add = (c, id, date, weightKg, bcs) => addWeighIn(c, { id, date, weightKg, bcs });

test('adding the newest weigh-in sets the weight and BCS', () => {
  const c = add(cat(), 'a', '2026-10-01', 4.2, 6);
  assert.equal(c.weightKg, 4.2); assert.equal(c.profile.bcs, 6);
});
test('adding an older weigh-in does not change the weight', () => {
  const c = add(add(cat(), 'a', '2026-10-01', 4.2, 6), 'b', '2026-09-01', 3.9, 4);
  assert.equal(c.weightKg, 4.2); assert.equal(c.profile.bcs, 6); assert.equal(c.weightLog.length, 2);
});
test('a weigh-in on the same date replaces the old one', () => {
  const c = add(add(cat(), 'a', '2026-10-01', 4.2, null), 'b', '2026-10-01', 4.3, null);
  assert.deepEqual(c.weightLog.map(e => e.id), ['b']); assert.equal(c.weightKg, 4.3); assert.equal(c.profile.bcs, 5);
});
test('removing the newest restores the previous weight; a missing BCS keeps the current one', () => {
  const c = removeWeighIn(add(add(cat(), 'a', '2026-09-01', 3.9, null), 'b', '2026-10-01', 4.2, 7), 'b');
  assert.equal(c.weightKg, 3.9); assert.equal(c.profile.bcs, 7);
});
test('removing the newest restores the previous BCS when it has one', () => {
  const c = removeWeighIn(add(add(cat(), 'a', '2026-09-01', 3.9, 4), 'b', '2026-10-01', 4.2, 7), 'b');
  assert.equal(c.weightKg, 3.9); assert.equal(c.profile.bcs, 4);
});
test('removing an older weigh-in changes nothing else', () => {
  const c = removeWeighIn(add(add(cat(), 'a', '2026-09-01', 3.9, 4), 'b', '2026-10-01', 4.2, 7), 'a');
  assert.equal(c.weightKg, 4.2); assert.equal(c.profile.bcs, 7);
});
test('removing the last weigh-in keeps the weight', () => {
  const c = removeWeighIn(add(cat(), 'a', '2026-10-01', 4.2, null), 'a');
  assert.equal(c.weightKg, 4.2); assert.deepEqual(c.weightLog, []);
});
test('the rules return new objects and leave the input cat unchanged', () => {
  const before = cat(), after = add(before, 'a', '2026-10-01', 4.2, 6);
  assert.notEqual(after, before); assert.equal(before.weightKg, 4); assert.equal(before.profile.bcs, 5); assert.deepEqual(before.weightLog, []);
});
