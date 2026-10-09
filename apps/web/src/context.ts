import type { PlanStore } from './store.js';
import type { NoticeKind } from './dom.js';
export type Page = { kind: 'household' } | { kind: 'cat'; id: string } | { kind: 'foods' } | { kind: 'method' };
export interface AppContext {
  store: PlanStore; navigate: (page: Page) => void; render: () => void;
  /** A one-time notice shown at the top of the next rendered page. */
  notify: (text: string, kind?: NoticeKind) => void;
  /** Leave unsaved forms only after confirmation. */
  canLeave: () => boolean;
}
