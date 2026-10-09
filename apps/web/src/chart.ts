import { daysBetween, type WeightEntry } from '../../../packages/core/src/index.js';
import { h, s } from './dom.js';
import { t, num, dateText, shortDate } from './i18n.js';
const W = 420, H = 190, L = 44, R = 12, T = 12, B = 34;
/** Weight over time with the ideal weight as a dashed line. role=img with a text summary. */
export function weightChart(entries: WeightEntry[], idealKg: number | null): HTMLElement {
  const sorted = [...entries].sort((a, b) => a.date < b.date ? -1 : a.date > b.date ? 1 : a.id < b.id ? -1 : 1);
  if (sorted.length < 2) return h('p', { class: 'caption' }, t('log.chartNeedsTwo'));
  const first = sorted[0]!, last = sorted.at(-1)!;
  const span = Math.max(1, daysBetween(first.date, last.date));
  const weights = sorted.map(e => e.weightKg).concat(idealKg === null ? [] : [idealKg]);
  let min = Math.min(...weights), max = Math.max(...weights);
  const pad = Math.max(0.1, (max - min) * 0.15); min -= pad; max += pad;
  const step = [0.1, 0.2, 0.25, 0.5, 1, 2, 5].find(st => (max - min) / st <= 5) ?? 5;
  min = Math.floor(min / step) * step; max = Math.ceil(max / step) * step;
  const x = (date: string) => L + daysBetween(first.date, date) / span * (W - L - R);
  const y = (kg: number) => T + (max - kg) / (max - min) * (H - T - B);
  const parts: SVGElement[] = [];
  for (let v = min; v <= max + 1e-9; v += step) parts.push(
    s('line', { x1: L, y1: y(v), x2: W - R, y2: y(v), class: 'chart-grid' }),
    s('text', { x: L - 6, y: y(v) + 4, 'text-anchor': 'end', class: 'chart-label' }, num(v, 2)));
  parts.push(s('text', { x: 4, y: T + 2, class: 'chart-unit', 'dominant-baseline': 'hanging' }, 'kg'));
  const ticks = span < 1 ? [first.date] : [first.date, last.date];
  if (sorted.length > 2) { const mid = sorted[Math.floor(sorted.length / 2)]!.date; if (!ticks.includes(mid)) ticks.splice(1, 0, mid); }
  for (const [i, date] of ticks.entries()) parts.push(
    s('line', { x1: x(date), y1: H - B, x2: x(date), y2: H - B + 5, class: 'chart-axis' }),
    s('text', { x: x(date), y: H - B + 18, 'text-anchor': i === 0 ? 'start' : i === ticks.length - 1 ? 'end' : 'middle', class: 'chart-label' }, shortDate(date)));
  parts.push(s('line', { x1: L, y1: H - B, x2: W - R, y2: H - B, class: 'chart-axis' }));
  if (idealKg !== null) parts.push(s('line', { x1: L, y1: y(idealKg), x2: W - R, y2: y(idealKg), class: 'chart-ideal' }),
    s('text', { x: W - R, y: y(idealKg) - 5, 'text-anchor': 'end', class: 'chart-ideal-label' }, t('log.idealLine', { kg: num(idealKg, 2) })));
  parts.push(s('polyline', { points: sorted.map(e => `${x(e.date).toFixed(1)},${y(e.weightKg).toFixed(1)}`).join(' '), class: 'chart-line' }));
  for (const e of sorted) parts.push(s('circle', { cx: x(e.date), cy: y(e.weightKg), r: 3.6, class: 'chart-dot' }));
  const summary = t('log.chartSummary', { count: String(sorted.length), from: dateText(first.date), to: dateText(last.date),
    first: num(first.weightKg, 2), last: num(last.weightKg, 2) }) + (idealKg === null ? '' : ` ${t('log.chartIdeal', { kg: num(idealKg, 2) })}`);
  const svg = s('svg', { class: 'weight-chart', viewBox: `0 0 ${W} ${H}`, role: 'img', 'aria-label': summary, focusable: 'false' }, ...parts);
  return h('figure', { class: 'chart-figure' }, svg, h('figcaption', { class: 'caption' }, summary));
}
