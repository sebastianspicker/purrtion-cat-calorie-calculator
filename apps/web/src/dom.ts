import { t, num, getLocale } from './i18n.js';
export type Child = Node | string | number | null | undefined | false;
export function h<K extends keyof HTMLElementTagNameMap>(tag: K,
  attributes: Record<string, string | number | boolean> | null = null, ...children: Child[]): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attributes ?? {})) {
    if (typeof value === 'boolean') { if (value) node.setAttribute(key, ''); }
    else node.setAttribute(key, String(value));
  }
  append(node, children);
  return node;
}
const SVG_NS = 'http://www.w3.org/2000/svg';
/** SVG counterpart of h(); presentation attributes only, never inline style markup. */
export function s(tag: string, attributes: Record<string, string | number> | null = null, ...children: Child[]): SVGElement {
  const node = document.createElementNS(SVG_NS, tag) as SVGElement;
  for (const [key, value] of Object.entries(attributes ?? {})) node.setAttribute(key, String(value));
  append(node, children);
  return node;
}
function append(node: Element, children: Child[]): void {
  for (const child of children) if (child !== null && child !== undefined && child !== false)
    node.append(child instanceof Node ? child : document.createTextNode(String(child)));
}
export function button(label: string, action: () => void, className = 'button'): HTMLButtonElement {
  const result = h('button', { type: 'button', class: className }, label);
  result.addEventListener('click', action); return result;
}
/** Locale-aware number formatting; see i18n.num. */
export function format(value: number, digits = 1): string { return num(value, digits); }
/** Accepts `5`, `5.5`, `5,5`, `.5` and `5.`; one decimal separator, no sign, no grouping, at most `maxDecimals` decimals. */
export function decimalPattern(maxDecimals: number): string {
  if (maxDecimals < 1) return '[0-9]+[.,]?';
  return `([0-9]+([.,][0-9]{0,${maxDecimals}})?|[.,][0-9]{1,${maxDecimals}})`;
}
const decimalExpression = /^([0-9]+([.,][0-9]*)?|[.,][0-9]+)$/;
/** A numeric field must say how many decimals it accepts, so "1,200" cannot silently become 1.2. */
export type FieldOptions = { required?: boolean; help?: string; maxLength?: number; type?: string; unit?: string }
  & ({ numeric: true; maxDecimals: number } | { numeric?: false; maxDecimals?: undefined });
export function field(label: string, name: string, value: string | number, options: FieldOptions = {}): HTMLElement {
  const input = h('input', { name, id: name, type: options.type ?? 'text', value, required: options.required !== false,
    ...(options.type === 'date' ? {} : { maxlength: options.maxLength ?? 120 }),
    ...(options.numeric ? { inputmode: 'decimal', pattern: decimalPattern(options.maxDecimals), autocomplete: 'off' } : {}) });
  const help = options.help ? h('small', { id: `${name}-help` }, options.help) : null;
  if (help) input.setAttribute('aria-describedby', `${name}-help`);
  const control = options.unit ? h('span', { class: 'input-unit' }, input, h('span', { 'aria-hidden': 'true' }, options.unit)) : input;
  return h('label', { class: 'field', for: name }, h('span', { class: 'field-label' }, label), control, help);
}
export function selectField(label: string, name: string, value: string, choices: readonly (readonly [string, string])[], help?: string): HTMLElement {
  const select = h('select', { name, id: name }, ...choices.map(([key, text]) => h('option', { value: key, selected: key === value }, text)));
  const note = help ? h('small', { id: `${name}-help` }, help) : null;
  if (note) select.setAttribute('aria-describedby', `${name}-help`);
  return h('label', { class: 'field', for: name }, h('span', { class: 'field-label' }, label), select, note);
}
/** A radio group rendered as a fieldset; each choice can carry a one-line description. */
export function radioGroup(legend: string, name: string, value: string,
  choices: readonly (readonly [string, string, string?])[], className = 'choice-cards'): HTMLFieldSetElement {
  return h('fieldset', { class: `radio-group ${className}` }, h('legend', null, legend),
    ...choices.map(([key, text, description]) => h('label', { class: 'choice' },
      h('input', { type: 'radio', name, value: key, checked: key === value }),
      h('span', { class: 'choice-text' }, h('span', { class: 'choice-title' }, text), description ? h('small', null, description) : null))));
}
export function checkbox(label: string, name: string, checked: boolean, description?: string): HTMLElement {
  return h('label', { class: 'check' }, h('input', { type: 'checkbox', name, checked }),
    h('span', null, label, description ? h('small', null, description) : null));
}
export function formText(form: HTMLFormElement | HTMLElement, name: string): string {
  if (form instanceof HTMLFormElement) return String(new FormData(form).get(name) ?? '').trim();
  const control = form.querySelector<HTMLInputElement>(`[name="${name}"]:is(:checked, :not([type=radio]):not([type=checkbox]))`);
  return (control?.value ?? '').trim();
}
export function decimal(value: string, label: string, maxDecimals: number): number {
  const text = value.trim();
  if (!decimalExpression.test(text)) throw new Error(t('error.number', { label }));
  const separator = text.search(/[.,]/);
  if (separator >= 0 && text.length - separator - 1 > maxDecimals) throw new Error(t('error.decimals', { label, max: String(maxDecimals) }));
  const number = Number(text.replace(',', '.'));
  if (!Number.isFinite(number)) throw new Error(t('error.finite', { label }));
  return number;
}
export function formNumber(form: HTMLFormElement | HTMLElement, name: string, label: string, maxDecimals: number): number { return decimal(formText(form, name), label, maxDecimals); }
/** Blank means "not entered" (null). */
export function optionalNumber(form: HTMLFormElement | HTMLElement, name: string, label: string, maxDecimals: number): number | null {
  const text = formText(form, name); return text === '' ? null : decimal(text, label, maxDecimals);
}
export function newId(prefix: string): string { return `${prefix}-${crypto.randomUUID()}`; }
export function errorText(error: unknown): string { return error instanceof Error ? error.message : t('error.generic'); }
export function download(name: string, text: string, type: string): void {
  const url = URL.createObjectURL(new Blob([text], { type }));
  const link = h('a', { href: url, download: name }); document.body.append(link); link.click(); link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
export function table(headers: string[], rows: Child[][], caption?: string): HTMLElement {
  return h('div', { class: 'table-wrap', tabindex: '0', role: 'region', 'aria-label': caption ?? t('table.default') },
    h('table', null, caption ? h('caption', { class: 'visually-hidden' }, caption) : null,
      h('thead', null, h('tr', null, ...headers.map(header => h('th', { scope: 'col' }, header)))),
      h('tbody', null, ...rows.map(row => h('tr', null, ...row.map((cell, i) => i === 0 ? h('th', { scope: 'row' }, cell) : h('td', null, cell)))))));
}
export function markDirty(form: HTMLFormElement): void {
  form.addEventListener('input', () => { form.dataset.dirty = 'true'; });
  form.addEventListener('change', () => { form.dataset.dirty = 'true'; });
}
export type NoticeKind = 'note' | 'error' | 'warning' | 'success' | 'vet';
export function notice(text: string | Node, kind: NoticeKind = 'note', title?: string): HTMLElement {
  return h('div', { class: `notice ${kind}`, role: kind === 'error' ? 'alert' : 'note' },
    kind === 'note' || kind === 'success' ? null : statusIcon(kind),
    h('div', null, title ? h('strong', { class: 'notice-title' }, title) : null, typeof text === 'string' ? h('p', null, text) : text));
}
/** Plain icons for serious states; the mascot never appears on these. */
export function statusIcon(kind: 'error' | 'warning' | 'vet'): SVGElement {
  const icon = s('svg', { class: 'status-icon', viewBox: '0 0 20 20', width: 20, height: 20, 'aria-hidden': 'true', focusable: 'false' });
  if (kind === 'vet') icon.append(s('rect', { x: 2, y: 2, width: 16, height: 16, rx: 4, fill: 'none', stroke: 'currentColor', 'stroke-width': 2 }),
    s('path', { d: 'M10 6v8M6 10h8', stroke: 'currentColor', 'stroke-width': 2.4, 'stroke-linecap': 'round' }));
  else icon.append(s('path', { d: 'M10 2.5 18.5 17h-17Z', fill: 'none', stroke: 'currentColor', 'stroke-width': 2, 'stroke-linejoin': 'round' }),
    s('path', { d: 'M10 8v4', stroke: 'currentColor', 'stroke-width': 2, 'stroke-linecap': 'round' }), s('circle', { cx: 10, cy: 14.6, r: 1.2, fill: 'currentColor' }));
  return icon;
}
export function chip(text: string, kind = ''): HTMLElement { return h('span', { class: `chip ${kind}`.trim() }, text); }
/** Set a field value programmatically and let live previews react. */
export function setValue(root: ParentNode, name: string, value: string): void {
  const controls = [...root.querySelectorAll<HTMLInputElement | HTMLSelectElement>(`[name="${name}"]`)];
  for (const control of controls) {
    if (control instanceof HTMLInputElement && (control.type === 'radio' || control.type === 'checkbox')) control.checked = control.value === value;
    else control.value = value;
  }
  controls[0]?.dispatchEvent(new Event('change', { bubbles: true }));
}
/** replaceChildren() that skips null/false children, like h(). */
export function fill(node: Element, ...children: Child[]): void { node.replaceChildren(); append(node, children); }
/** A number as typed into a field: no grouping, the locale's decimal separator (decimal() accepts both). */
export function inputNumber(value: number): string { return String(value).replace('.', getLocale() === 'de' ? ',' : '.'); }
