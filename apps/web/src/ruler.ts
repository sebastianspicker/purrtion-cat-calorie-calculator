import { h, s } from './dom.js';
import { t, num } from './i18n.js';
/** Values drawn on the energy ruler; any may be null. kcal/day. */
export interface RulerData {
  lowKcal: number | null; highKcal: number | null; startKcal: number | null; floorKcal: number | null;
  bandLowKcal: number | null; bandHighKcal: number | null; targetKcal: number | null;
}
const W = 420, H = 104, PAD = 18, AXIS_Y = 62;
let rulerCount = 0;
function niceStep(span: number): number {
  const raw = span / 5, power = 10 ** Math.floor(Math.log10(raw)), unit = raw / power;
  return (unit < 1.5 ? 1 : unit < 3 ? 2 : unit < 7 ? 5 : 10) * power;
}
/** A paw print centred on (0, 0), pointing down at the axis. */
function pawPin(): SVGElement {
  return s('g', { class: 'paw-pin' },
    s('path', { d: 'M0 0 L-5 -9 H5 Z', class: 'paw-stem' }),
    s('ellipse', { cx: 0, cy: -16, rx: 6.4, ry: 5.4, class: 'paw-pad' }),
    s('ellipse', { cx: -7.4, cy: -24, rx: 2.3, ry: 2.9, class: 'paw-pad' }), s('ellipse', { cx: -2.6, cy: -27.6, rx: 2.3, ry: 2.9, class: 'paw-pad' }),
    s('ellipse', { cx: 2.6, cy: -27.6, rx: 2.3, ry: 2.9, class: 'paw-pad' }), s('ellipse', { cx: 7.4, cy: -24, rx: 2.3, ry: 2.9, class: 'paw-pad' }));
}
/**
 * The energy ruler: a kcal/day scale with the reference band (hatched), the estimate range (pill),
 * the start value (diamond), the floor (dashed line) and the owner's target (paw-print pin).
 * The pin element persists across updates so it can glide (CSS transition; off under reduced motion).
 */
export function createRuler(): { element: HTMLElement; update: (data: RulerData) => void } {
  const id = `ruler-hatch-${++rulerCount}`;
  const layer = s('g');
  const pin = pawPin();
  const svg = s('svg', { class: 'energy-ruler', viewBox: `0 0 ${W} ${H}`, role: 'img', focusable: 'false' },
    s('defs', null, s('pattern', { id, width: 6, height: 6, patternUnits: 'userSpaceOnUse', patternTransform: 'rotate(45)' },
      s('rect', { width: 6, height: 6, class: 'hatch-bg' }), s('line', { x1: 0, y1: 0, x2: 0, y2: 6, class: 'hatch-line' }))),
    layer, pin);
  const legend = h('dl', { class: 'ruler-legend' });
  const element = h('figure', { class: 'ruler-figure' }, svg, h('figcaption', null, legend));
  function update(d: RulerData): void {
    const values = [d.lowKcal, d.highKcal, d.startKcal, d.floorKcal, d.bandLowKcal, d.bandHighKcal, d.targetKcal]
      .filter((v): v is number => v !== null && Number.isFinite(v));
    if (!values.length) { element.hidden = true; return; }
    element.hidden = false;
    let min = Math.min(...values), max = Math.max(...values);
    if (max - min < 20) { min -= 10; max += 10; }
    const step = niceStep(max - min);
    min = Math.max(0, Math.floor((min - step * 0.4) / step) * step); max = Math.ceil((max + step * 0.4) / step) * step;
    const x = (v: number) => PAD + (v - min) / (max - min) * (W - 2 * PAD);
    const parts: SVGElement[] = [];
    if (d.bandLowKcal !== null && d.bandHighKcal !== null)
      parts.push(s('rect', { x: x(d.bandLowKcal), y: AXIS_Y - 26, width: Math.max(1, x(d.bandHighKcal) - x(d.bandLowKcal)), height: 22, rx: 3, fill: `url(#${id})`, class: 'ruler-band' }));
    parts.push(s('line', { x1: PAD, y1: AXIS_Y, x2: W - PAD, y2: AXIS_Y, class: 'ruler-axis' }));
    for (let v = min; v <= max + 1e-9; v += step) {
      parts.push(s('line', { x1: x(v), y1: AXIS_Y, x2: x(v), y2: AXIS_Y + 6, class: 'ruler-tick' }),
        s('text', { x: x(v), y: AXIS_Y + 18, 'text-anchor': 'middle', class: 'ruler-tick-label' }, num(v, 0)));
      for (let minor = 1; minor < 5; minor++) {
        const mv = v + step * minor / 5;
        if (mv < max) parts.push(s('line', { x1: x(mv), y1: AXIS_Y, x2: x(mv), y2: AXIS_Y + 3, class: 'ruler-tick minor' }));
      }
    }
    parts.push(s('text', { x: W - PAD, y: AXIS_Y + 34, 'text-anchor': 'end', class: 'ruler-unit' }, t('unit.kcalPerDay')));
    if (d.lowKcal !== null && d.highKcal !== null) {
      const width = Math.max(8, x(d.highKcal) - x(d.lowKcal));
      parts.push(s('rect', { x: x(d.lowKcal), y: AXIS_Y - 20, width, height: 10, rx: 5, class: 'ruler-range' }));
    }
    if (d.startKcal !== null) {
      const sx = x(d.startKcal);
      parts.push(s('path', { d: `M${sx} ${AXIS_Y - 23} l6 8 -6 8 -6 -8 Z`, class: 'ruler-start' }));
    }
    if (d.floorKcal !== null) {
      const fx = x(d.floorKcal);
      parts.push(s('line', { x1: fx, y1: 8, x2: fx, y2: AXIS_Y + 4, class: 'ruler-floor' }),
        s('text', { x: fx + 4, y: 14, class: 'ruler-floor-label' }, t('ruler.floor')));
    }
    layer.replaceChildren(...parts);
    if (d.targetKcal !== null) {
      pin.removeAttribute('visibility');
      // CSSOM transforms are allowed by the CSP (no inline style markup) and are what the transition animates.
      (pin as SVGGElement).style.transform = `translate(${x(d.targetKcal).toFixed(2)}px, ${AXIS_Y - 1}px)`;
    } else pin.setAttribute('visibility', 'hidden');
    // Glide only on changes, not on the first placement.
    if (!svg.classList.contains('ready')) requestAnimationFrame(() => requestAnimationFrame(() => svg.classList.add('ready')));
    const rows: [string, string, string][] = [];
    if (d.targetKcal !== null) rows.push(['target', t('ruler.target'), `${num(d.targetKcal, 0)} ${t('unit.kcalPerDay')}`]);
    if (d.startKcal !== null) rows.push(['start', t('ruler.start'), `${num(d.startKcal, 0)} ${t('unit.kcalPerDay')}`]);
    if (d.lowKcal !== null && d.highKcal !== null) rows.push(['range', t('ruler.range'), t('range.kcal', { low: num(d.lowKcal, 0), high: num(d.highKcal, 0) })]);
    if (d.floorKcal !== null) rows.push(['floor', t('ruler.floorLong'), `${num(d.floorKcal, 0)} ${t('unit.kcalPerDay')}`]);
    if (d.bandLowKcal !== null && d.bandHighKcal !== null) rows.push(['band', t('ruler.band'), t('range.kcal', { low: num(d.bandLowKcal, 0), high: num(d.bandHighKcal, 0) })]);
    legend.replaceChildren(...rows.flatMap(([kind, label, value]) => [h('dt', null, h('span', { class: `key key-${kind}`, 'aria-hidden': 'true' }), label), h('dd', null, value)]));
    svg.setAttribute('aria-label', `${t('ruler.label')}: ${rows.map(([, label, value]) => `${label} ${value}`).join('; ')}`);
  }
  return { element, update };
}
