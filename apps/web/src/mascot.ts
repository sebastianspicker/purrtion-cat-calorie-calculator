import { h, s } from './dom.js';
import { iconBadge } from './cat-icons.js';
import type { CatIcon } from '../../../packages/core/src/index.js';
/**
 * The app's own cat-face drawing (simple circles, ellipses and triangles), matching the brand mark's face:
 * dot eyes, small "w" mouth, blush ovals, white face with an ink outline, triangular ears with sakura inner ears.
 * Used for per-cat avatars, empty states and the wizard guide. Never on referral, warning or error panels.
 */
export type Expression = 'happy' | 'curious' | 'thinking';
const INK = '#2B2541', SAKURA = '#E8779E', SAKURA_LIGHT = '#F4A9C2', SKY = '#8DBDEB', SKY_INK = '#2C64A0', YOLK = '#F5CF6B';
/** A stable pastel for a cat id (FNV-1a hash → hue). */
export function pastelFor(id: string): string {
  let hash = 0x811c9dc5;
  for (let i = 0; i < id.length; i++) { hash ^= id.charCodeAt(i); hash = Math.imul(hash, 0x01000193); }
  return `hsl(${(hash >>> 0) % 360} 72% 86%)`;
}
function face(expression: Expression): SVGElement {
  const g = s('g', null,
    s('path', { d: 'M15 33 L17 15 L30 23 Z M49 33 L47 15 L34 23 Z', fill: '#FFFFFF', stroke: INK, 'stroke-width': 2.6, 'stroke-linejoin': 'round' }),
    s('path', { d: 'M19 20 L19.6 26.5 L25.4 23.3 Z M45 20 L44.4 26.5 L38.6 23.3 Z', fill: SAKURA_LIGHT }),
    s('ellipse', { cx: 32, cy: 37, rx: 18, ry: 15, fill: '#FFFFFF', stroke: INK, 'stroke-width': 2.6 }),
    s('ellipse', { cx: 22.5, cy: 40.6, rx: 2.8, ry: 1.5, fill: SAKURA, opacity: 0.6 }),
    s('ellipse', { cx: 41.5, cy: 40.6, rx: 2.8, ry: 1.5, fill: SAKURA, opacity: 0.6 }));
  if (expression === 'curious') {
    g.append(s('circle', { cx: 25.5, cy: 35.5, r: 3, fill: INK }), s('circle', { cx: 38.5, cy: 35.5, r: 3, fill: INK }),
      s('circle', { cx: 26.5, cy: 34.4, r: 0.9, fill: '#FFFFFF' }), s('circle', { cx: 39.5, cy: 34.4, r: 0.9, fill: '#FFFFFF' }),
      s('ellipse', { cx: 32, cy: 42.4, rx: 1.4, ry: 1.7, fill: 'none', stroke: INK, 'stroke-width': 1.5 }));
  } else if (expression === 'thinking') {
    g.append(s('circle', { cx: 26.6, cy: 34.6, r: 2.2, fill: INK }), s('circle', { cx: 39.6, cy: 34.6, r: 2.2, fill: INK }),
      s('path', { d: 'M29.5 42.5 h5', stroke: INK, 'stroke-width': 1.6, 'stroke-linecap': 'round' }));
  } else {
    g.append(s('circle', { cx: 25.5, cy: 36, r: 2.2, fill: INK }), s('circle', { cx: 38.5, cy: 36, r: 2.2, fill: INK }),
      s('path', { d: 'M29.8 40.6 q1.1 1.3 2.2 0 q1.1 1.3 2.2 0', fill: 'none', stroke: INK, 'stroke-width': 1.6, 'stroke-linecap': 'round' }));
  }
  return g;
}
/** A small wizard hat (cone, band, star) that sits between the ears; viewBox units match the face. */
export function wizardHat(): SVGElement {
  return s('g', { class: 'wizard-hat' },
    s('path', { d: 'M20 22 Q32 25 44 22 L35 1.5 Q33.5 -0.5 32 2 Z', fill: SKY, stroke: INK, 'stroke-width': 2.4, 'stroke-linejoin': 'round' }),
    s('path', { d: 'M21.6 18.6 Q32 21.6 42.4 18.6 L43.4 21 Q32 24.4 20.6 21 Z', fill: SAKURA, stroke: INK, 'stroke-width': 1.6, 'stroke-linejoin': 'round' }),
    s('path', { d: 'M31 7.5 l1.2 2.5 2.7 .3 -2 1.8 .6 2.7 -2.5 -1.4 -2.4 1.4 .6 -2.7 -2 -1.8 2.7 -.3 Z', fill: YOLK, stroke: SKY_INK, 'stroke-width': 0.6 }));
}
export interface MascotOptions { size?: number; tint?: string | null; expression?: Expression; hat?: boolean; label?: string }
/** The cat-face mark. Decorative (aria-hidden) unless a label is given. */
export function catFace(options: MascotOptions = {}): SVGElement {
  const size = options.size ?? 40;
  const svg = s('svg', { class: 'cat-face', viewBox: options.hat ? '0 -4 64 60' : '0 6 64 50', width: size, height: size, focusable: 'false' });
  if (options.label) { svg.setAttribute('role', 'img'); svg.setAttribute('aria-label', options.label); }
  else svg.setAttribute('aria-hidden', 'true');
  if (options.tint) svg.append(s('circle', { cx: 32, cy: options.hat ? 26 : 31, r: options.hat ? 31 : 26, fill: options.tint }));
  svg.append(face(options.expression ?? 'happy'));
  if (options.hat) svg.append(wizardHat());
  return svg;
}
/** Per-cat avatar: the face on the cat's own pastel, with the cat's icon as a round badge at the bottom right. */
export function avatar(id: string, size = 40, icon: CatIcon | null = null): HTMLElement {
  const svg = catFace({ size, tint: pastelFor(id) }); svg.classList.add('avatar');
  return h('span', { class: 'avatar-wrap' }, svg, icon ? iconBadge(icon, size) : null);
}
