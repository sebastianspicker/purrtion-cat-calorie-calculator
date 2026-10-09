import type { WarningCode } from './models.js';
import { messages, type Locale, type MessageKey } from './generated/messages.js';
export { messages, type Locale, type MessageKey };
export const locales = Object.keys(messages) as Locale[];
/** User-facing text for a namespaced code such as `warning.over-budget` or `refer.bcs-low`. */
export function messageFor(code: MessageKey, locale: Locale = 'en'): string { return messages[locale][code]; }
const warningCodes: WarningCode[] = ['estimated-energy', 'provisional-target', 'unknown-completeness',
  'complementary-balance-food', 'extras-over-10-percent', 'over-budget'];
/** English allocation warnings, kept for callers that index by WarningCode. */
export const warningMessages = Object.fromEntries(warningCodes.map(code => [code, messageFor(`warning.${code}`)])) as Record<WarningCode, string>;
