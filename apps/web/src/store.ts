import { parsePlan, parsePlanJSON, planToJSON, type Plan } from '../../../packages/core/src/index.js';
import { translate, type UiKey } from './i18n.js';
export const KEY = 'purrtion.plan.v2';
/** Read only as a fallback and migrated in memory; it is never written or deleted (ENGINE.md §9). */
const LEGACY_KEY = 'purrtion.plan.v1';
export type StoreNotice = '' | 'storage-unavailable' | 'saved-unreadable' | 'save-failed' | 'external-conflict' | 'external-unreadable';
/** Result of a change made in another tab: reloaded into memory, kept because a form is dirty, or ignored. */
export type ExternalResult = 'ignored' | 'reloaded' | 'conflict' | 'unreadable';
/** Local-only persistence. Invalid saved data is never silently overwritten. */
export class PlanStore {
  plan: Plan;
  readonly sample: Plan;
  /** A persistent condition the UI must show; translated by the UI (`store.<notice>`). */
  notice: StoreNotice = '';
  recoveryMode = false;
  private damagedData: string | null = null;
  constructor(sample: Plan) {
    this.sample = parsePlan(sample); this.plan = parsePlan(sample);
    this.reload();
  }
  /**
   * Re-reads the saved plan with the constructor's semantics: nothing saved gives the sample, unreadable data enters recovery mode,
   * unavailable storage leaves the in-memory plan as it is. Used when edits are discarded after a cross-tab conflict.
   */
  reload(): void {
    let saved: string | null;
    try { saved = localStorage.getItem(KEY) ?? localStorage.getItem(LEGACY_KEY); }
    catch { this.notice = 'storage-unavailable'; return; }
    this.plan = parsePlan(this.sample); this.recoveryMode = false; this.damagedData = null; this.notice = '';
    if (saved === null) return;
    try { this.plan = parsePlanJSON(saved); }
    catch { this.damagedData = saved; this.recoveryMode = true; this.notice = 'saved-unreadable'; }
  }
  /** English text of the current notice (the UI shows the translated one). */
  get message(): string { return this.notice ? translate('en', `store.${this.notice}` as UiKey) : ''; }
  /** Validates and keeps the plan in memory; returns whether it was also persisted (false: recovery mode or a failed write, see `notice`). */
  commit(candidate: Plan, replaceDamaged = false): boolean {
    const next = parsePlan(candidate);
    this.plan = next;
    if (this.recoveryMode && !replaceDamaged) return false;
    try {
      if (replaceDamaged && this.damagedData !== null) localStorage.setItem(`${KEY}.recovery`, this.damagedData);
      localStorage.setItem(KEY, planToJSON(next));
      this.recoveryMode = false; this.damagedData = null; this.notice = '';
      return true;
    } catch { this.notice = 'save-failed'; return false; }
  }
  /**
   * Handles a `storage` event from another tab. With no unsaved form (`dirty` false) the plan is reloaded.
   * With unsaved edits the in-memory plan is kept and a conflict notice is raised: saving overwrites the other tab's change.
   * Unreadable data written elsewhere enters recovery mode, so it is not overwritten silently either.
   */
  external(key: string | null, newValue: string | null, dirty: boolean): ExternalResult {
    if (key !== KEY || newValue === null) return 'ignored';
    let next: Plan;
    try { next = parsePlanJSON(newValue); }
    catch { this.damagedData = newValue; this.recoveryMode = true; this.notice = 'external-unreadable'; return 'unreadable'; }
    if (planToJSON(next) === planToJSON(this.plan)) return 'ignored';
    if (dirty) { this.notice = 'external-conflict'; return 'conflict'; }
    this.plan = next; this.recoveryMode = false; this.damagedData = null;
    if (this.notice === 'external-conflict' || this.notice === 'external-unreadable' || this.notice === 'saved-unreadable') this.notice = '';
    return 'reloaded';
  }
  damagedJSON(): string | null { return this.damagedData; }
}
