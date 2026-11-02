import { messages, type Locale, type MessageKey } from './generated/messages.js';
export { messages, type Locale, type MessageKey };
export const locales = Object.keys(messages) as Locale[];
/** User-facing text for a namespaced code such as `warning.over-budget` or `refer.bcs-low`. */
export function messageFor(code: MessageKey, locale: Locale = 'en'): string { return messages[locale][code]; }
