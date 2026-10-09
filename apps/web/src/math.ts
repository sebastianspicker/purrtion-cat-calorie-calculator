import { h } from './dom.js';
import { getLocale } from './i18n.js';
/** The vendored Temml build (apps/web/vendor/temml) defines this global; see apps/web/vendor/README.md. */
interface Temml { render(expression: string, baseNode: Element, options?: { displayMode?: boolean; throwOnError?: boolean; annotate?: boolean }): void }
/**
 * Renders trusted, app-built LaTeX to MathML through DOM APIs. User input is never interpolated into LaTeX;
 * only numbers formatted by texNumber() are. Falls back to the LaTeX source in <code> when Temml is unavailable or fails.
 */
export function tex(latex: string, display = false): Element {
  const temml = (globalThis as { temml?: Temml }).temml;
  const host = h(display ? 'div' : 'span', { class: display ? 'math math-display' : 'math' });
  try {
    if (!temml) throw new Error('Temml is not loaded');
    temml.render(latex, host, { displayMode: display, throwOnError: true, annotate: true });
    if (!host.querySelector('math')) throw new Error('No MathML produced');
    return host;
  } catch { return h('code', { class: 'math-fallback' }, latex); }
}
/** A number as a LaTeX literal in the active locale: `4{,}0` in German, `4.0` in English. No digit grouping. */
export function texNumber(value: number, digits = 1, minimumDigits = 0): string {
  const text = new Intl.NumberFormat(getLocale(), { maximumFractionDigits: digits, minimumFractionDigits: minimumDigits, useGrouping: false })
    .format(value);
  return text.replace('−', '-').replace(',', '{,}');
}
