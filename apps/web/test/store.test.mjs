import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PlanStore } from '../../../dist/web/apps/web/src/store.js';
const sample = JSON.parse(readFileSync(new URL('../../../shared/default-plan.json', import.meta.url), 'utf8'));
const KEY = 'purrtion.plan.v2', LEGACY_KEY = 'purrtion.plan.v1';
const v1Sample = JSON.parse(readFileSync(new URL('../../../packages/core/test/fixtures/golden-cases-v1.json', import.meta.url), 'utf8'))[0].plan;
function storage(initial = {}) {
  const map = new Map(Object.entries(initial));
  Object.defineProperty(globalThis, 'localStorage', { configurable: true, value: {
    getItem: key => map.get(key) ?? null,
    setItem: (key, value) => map.set(key, String(value)),
    removeItem: key => map.delete(key),
  } });
  return map;
}
test('browser store: sample stays local in memory until an explicit save', () => {
  const map = storage(); const store = new PlanStore(sample);
  assert.deepEqual(store.plan, sample); assert.equal(map.size, 0);
  store.plan.cats[0].name = 'Changed'; assert.notEqual(sample.cats[0].name, 'Changed');
});
test('browser store: restore a saved versioned plan', () => {
  const next = structuredClone(sample); next.cats[0].name = 'Saved name';
  storage({[KEY]: JSON.stringify(next)});
  assert.equal(new PlanStore(sample).plan.cats[0].name, 'Saved name');
});
test('browser store: commit persists a validated independent copy', () => {
  const map = storage(); const store = new PlanStore(sample); const next = structuredClone(sample);
  next.cats[0].extraKcal = 20; store.commit(next); next.cats[0].extraKcal = 100;
  assert.equal(store.plan.cats[0].extraKcal, 20);
  assert.equal(JSON.parse(map.get(KEY)).cats[0].extraKcal, 20);
});
test('browser store: invalid candidate changes neither saved nor in-memory data', () => {
  const map = storage({[KEY]: JSON.stringify(sample)}); const store = new PlanStore(sample);
  const next = structuredClone(sample); next.cats[0].targetKcal = -1;
  assert.throws(() => store.commit(next)); assert.deepEqual(store.plan, sample);
  assert.deepEqual(JSON.parse(map.get(KEY)), sample);
});
test('browser store: damaged data is retained until explicitly replaced and backed up', () => {
  const map = storage({[KEY]: 'broken'}); const store = new PlanStore(sample);
  assert.equal(store.recoveryMode, true); assert.equal(store.damagedJSON(), 'broken');
  store.commit(sample); assert.equal(map.get(KEY), 'broken');
  store.commit(sample, true);
  assert.equal(map.get(KEY + '.recovery'), 'broken'); assert.equal(store.recoveryMode, false);
  assert.deepEqual(JSON.parse(map.get(KEY)), sample);
});
test('browser store: disabled storage degrades to explicit in-memory-only mode', () => {
  Object.defineProperty(globalThis, 'localStorage', {configurable: true, get() { throw new Error('Denied'); }});
  const store = new PlanStore(sample); assert.match(store.message, /unavailable/);
  const next = structuredClone(sample); next.cats[0].extraKcal = 10; store.commit(next);
  assert.equal(store.plan.cats[0].extraKcal, 10); assert.match(store.message, /could not be saved/);
});
test('browser store: a failed backup never overwrites damaged saved data', () => {
  const map = storage({[KEY]: 'broken'}); const store = new PlanStore(sample);
  localStorage.setItem = () => { throw new Error('Quota exceeded'); };
  store.commit(sample, true); assert.equal(map.get(KEY), 'broken');
  assert.equal(store.recoveryMode, true); assert.match(store.message, /could not be saved/);
});
test('browser store: falls back to the v1 key, migrates in memory, and never deletes it', () => {
  const legacy = structuredClone(v1Sample); legacy.cats[0].name = 'Legacy name';
  const map = storage({[LEGACY_KEY]: JSON.stringify(legacy)}); const store = new PlanStore(sample);
  assert.equal(store.plan.schemaVersion, 2); assert.equal(store.plan.cats[0].name, 'Legacy name');
  assert.equal(store.plan.cats[0].balanceFoodId, 'dry'); assert.equal(store.recoveryMode, false);
  const next = structuredClone(store.plan); next.cats[0].extraKcal = 5; store.commit(next);
  assert.equal(JSON.parse(map.get(KEY)).schemaVersion, 2); assert.equal(JSON.parse(map.get(KEY)).cats[0].extraKcal, 5);
  assert.equal(map.get(LEGACY_KEY), JSON.stringify(legacy));
});
test('browser store: the v2 key wins over the v1 key', () => {
  const legacy = structuredClone(v1Sample); legacy.cats[0].name = 'Legacy name';
  const current = structuredClone(sample); current.cats[0].name = 'Current name';
  storage({[LEGACY_KEY]: JSON.stringify(legacy), [KEY]: JSON.stringify(current)});
  assert.equal(new PlanStore(sample).plan.cats[0].name, 'Current name');
});
test('browser store: damaged v1 data enters recovery mode without touching the v1 key', () => {
  const map = storage({[LEGACY_KEY]: 'broken'}); const store = new PlanStore(sample);
  assert.equal(store.recoveryMode, true); store.commit(sample, true);
  assert.equal(map.get(LEGACY_KEY), 'broken'); assert.equal(map.get(KEY + '.recovery'), 'broken');
  assert.deepEqual(JSON.parse(map.get(KEY)), sample);
});
test('browser store: another tab’s save is reloaded when nothing is being edited', () => {
  storage(); const store = new PlanStore(sample);
  const other = structuredClone(sample); other.cats[0].name = 'Renamed elsewhere';
  assert.equal(store.external(KEY, JSON.stringify(other), false), 'reloaded');
  assert.equal(store.plan.cats[0].name, 'Renamed elsewhere'); assert.equal(store.notice, '');
});
test('browser store: another tab’s save with a dirty form keeps memory and warns before overwriting', () => {
  const map = storage(); const store = new PlanStore(sample);
  const other = structuredClone(sample); other.cats[0].name = 'Renamed elsewhere';
  map.set(KEY, JSON.stringify(other));
  assert.equal(store.external(KEY, JSON.stringify(other), true), 'conflict');
  assert.equal(store.plan.cats[0].name, sample.cats[0].name); assert.equal(store.notice, 'external-conflict');
  assert.match(store.message, /another tab/);
  const mine = structuredClone(sample); mine.cats[0].extraKcal = 15; store.commit(mine);
  assert.equal(store.notice, ''); assert.equal(JSON.parse(map.get(KEY)).cats[0].extraKcal, 15);
});
test('browser store: unrelated keys, removals and identical plans are ignored', () => {
  storage(); const store = new PlanStore(sample);
  assert.equal(store.external('purrtion.locale', 'de', false), 'ignored');
  assert.equal(store.external(KEY, null, false), 'ignored');
  assert.equal(store.external(null, null, false), 'ignored');
  assert.equal(store.external(KEY, JSON.stringify(sample), true), 'ignored');
  assert.equal(store.notice, ''); assert.deepEqual(store.plan, sample);
});
test('browser store: unreadable data from another tab enters recovery and is not overwritten', () => {
  const map = storage(); const store = new PlanStore(sample);
  map.set(KEY, 'broken');
  assert.equal(store.external(KEY, 'broken', false), 'unreadable');
  assert.equal(store.recoveryMode, true); assert.equal(store.damagedJSON(), 'broken');
  store.commit(sample); assert.equal(map.get(KEY), 'broken');
});
test('browser store: commit reports whether the plan was persisted', () => {
  const map = storage(); const store = new PlanStore(sample); const next = structuredClone(sample);
  next.cats[0].extraKcal = 20; assert.equal(store.commit(next), true); assert.equal(JSON.parse(map.get(KEY)).cats[0].extraKcal, 20);
  localStorage.setItem = () => { throw new Error('Quota exceeded'); };
  next.cats[0].extraKcal = 30; assert.equal(store.commit(next), false);
  assert.equal(store.notice, 'save-failed'); assert.equal(store.plan.cats[0].extraKcal, 30);
});
test('browser store: commit returns false in recovery mode and true once the damaged data is replaced', () => {
  const map = storage({[KEY]: 'broken'}); const store = new PlanStore(sample);
  assert.equal(store.commit(sample), false); assert.equal(map.get(KEY), 'broken'); assert.equal(store.notice, 'saved-unreadable');
  assert.equal(store.commit(sample, true), true); assert.equal(store.recoveryMode, false);
});
test('browser store: commit returns false when storage is unavailable', () => {
  Object.defineProperty(globalThis, 'localStorage', {configurable: true, get() { throw new Error('Denied'); }});
  const store = new PlanStore(sample); assert.equal(store.commit(structuredClone(sample)), false);
});
test('browser store: reload after a conflict shows the other tab’s saved plan and clears the notice', () => {
  const map = storage(); const store = new PlanStore(sample);
  const other = structuredClone(sample); other.cats[0].name = 'Renamed elsewhere';
  map.set(KEY, JSON.stringify(other));
  assert.equal(store.external(KEY, JSON.stringify(other), true), 'conflict'); assert.equal(store.notice, 'external-conflict');
  store.reload();
  assert.equal(store.plan.cats[0].name, 'Renamed elsewhere'); assert.equal(store.notice, ''); assert.equal(store.recoveryMode, false);
});
test('browser store: reload with nothing saved gives the sample, and with the v1 key falls back like the constructor', () => {
  const map = storage(); const store = new PlanStore(sample);
  const next = structuredClone(sample); next.cats[0].extraKcal = 20; store.commit(next); map.delete(KEY);
  store.reload(); assert.deepEqual(store.plan, sample);
  const legacy = structuredClone(v1Sample); legacy.cats[0].name = 'Legacy name'; map.set(LEGACY_KEY, JSON.stringify(legacy));
  store.reload(); assert.equal(store.plan.cats[0].name, 'Legacy name'); assert.equal(store.plan.schemaVersion, 2);
});
test('browser store: reload of unreadable data enters recovery mode and is not overwritten', () => {
  const map = storage(); const store = new PlanStore(sample);
  map.set(KEY, 'broken'); store.reload();
  assert.equal(store.recoveryMode, true); assert.equal(store.damagedJSON(), 'broken'); assert.equal(store.notice, 'saved-unreadable');
  assert.equal(store.commit(sample), false); assert.equal(map.get(KEY), 'broken');
});
test('browser store: reload with unavailable storage keeps the in-memory plan and says so', () => {
  storage(); const store = new PlanStore(sample); const next = structuredClone(sample); next.cats[0].extraKcal = 20; store.commit(next);
  Object.defineProperty(globalThis, 'localStorage', {configurable: true, get() { throw new Error('Denied'); }});
  store.reload(); assert.equal(store.plan.cats[0].extraKcal, 20); assert.equal(store.notice, 'storage-unavailable');
});
