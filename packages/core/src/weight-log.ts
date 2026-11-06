import type { Cat, WeightEntry } from './models.js';
import { byDateThenId } from './estimator.js';

/** Adds a weigh-in (ENGINE.md "Current weight"), mirroring Swift `Cat.addWeighIn`: an entry on the same date is replaced, and an entry
 * dated on or after every other one also sets the current weight and, if it has a BCS, the profile BCS. Returns a new cat. */
export function addWeighIn(cat: Cat, entry: WeightEntry): Cat {
  const others = cat.weightLog.filter(e => e.date !== entry.date);
  const newest = others.every(e => e.date <= entry.date);
  return { ...cat, weightLog: [...others, { ...entry }],
    weightKg: newest ? entry.weightKg : cat.weightKg,
    profile: newest && entry.bcs !== null ? { ...cat.profile, bcs: entry.bcs } : cat.profile };
}
/** Removes a weigh-in, mirroring Swift `Cat.removeWeighIn`: if it was the newest, the newest remaining entry becomes the current weight
 * (and BCS, if it has one); removing the last entry leaves the weight unchanged. Returns a new cat. */
export function removeWeighIn(cat: Cat, id: string): Cat {
  const removed = cat.weightLog.find(e => e.id === id);
  if (!removed) return cat;
  const weightLog = cat.weightLog.filter(e => e.id !== id);
  const newest = [...weightLog].sort(byDateThenId).at(-1);
  if (!newest || !weightLog.every(e => e.date <= removed.date)) return { ...cat, weightLog };
  return { ...cat, weightLog, weightKg: newest.weightKg, profile: newest.bcs !== null ? { ...cat.profile, bcs: newest.bcs } : cat.profile };
}
