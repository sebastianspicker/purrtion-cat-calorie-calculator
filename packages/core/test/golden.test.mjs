import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { calculatePlan } from '../../../dist/web/packages/core/src/index.js';
const cases = JSON.parse(readFileSync(new URL('../../../shared/golden-cases.json', import.meta.url), 'utf8'));
/** Every expected key must match; numbers within a relative 1e-9 (both engines may differ in the last bits of pow/exp). */
function matches(actual, expected, path) {
  if (typeof expected === 'number') {
    assert.equal(typeof actual, 'number', `${path}: expected a number, got ${JSON.stringify(actual)}`);
    assert.ok(Math.abs(actual - expected) <= 1e-9 * Math.max(1, Math.abs(expected)), `${path}: ${actual} ≠ ${expected}`);
  } else if (Array.isArray(expected)) {
    assert.ok(Array.isArray(actual) && actual.length === expected.length, `${path}: ${JSON.stringify(actual)} ≠ ${JSON.stringify(expected)}`);
    expected.forEach((item, i) => matches(actual[i], item, `${path}[${i}]`));
  } else if (expected && typeof expected === 'object') {
    assert.ok(actual && typeof actual === 'object', `${path}: expected an object, got ${JSON.stringify(actual)}`);
    for (const key of Object.keys(expected)) matches(actual[key], expected[key], `${path}.${key}`);
  } else assert.equal(actual, expected, path);
}
test('golden file has the v2 shape and all 117 cases', () => {
  assert.ok(cases.length >= 117);
  for (const c of cases) for (const key of ['name', 'asOf', 'plan', 'expected']) assert.ok(key in c, `${c.name}: ${key}`);
});
for (const c of cases) test(`shared golden v2: ${c.name}`, () => {
  const result = calculatePlan(c.plan, { asOf: c.asOf });
  assert.equal(result.cats.length, c.expected.cats.length);
  for (const expected of c.expected.cats) {
    const actual = result.cats.find(cat => cat.id === expected.id);
    assert.ok(actual, `cat ${expected.id}`);
    const { activityRoundedGrams, ...rest } = expected;
    matches(actual, rest, `cats.${expected.id}`);
    assert.deepEqual(actual.activities.map(a => a.roundedGrams), activityRoundedGrams);
  }
  matches(result.foods, c.expected.foods, 'foods');
  matches(result.totals, c.expected.totals, 'totals');
});
