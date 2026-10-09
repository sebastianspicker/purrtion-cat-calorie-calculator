import { catIcons, type CatIcon } from '../../../packages/core/src/index.js';
import { s } from './dom.js';
/**
 * The 12 cat profile icons as inline SVG, 24 x 24. Path data is copied from brand/cat-icons.svg, which is the source of truth;
 * the Mac app redraws the same shapes in Views/CatIcons.swift. Built with createElementNS, so no markup is parsed.
 */
const INK = '#2B2541', SAKURA = '#E8779E', SAKURA_LIGHT = '#F4A9C2', SKY = '#8DBDEB', YOLK = '#F5CF6B', MATCHA = '#7CC49A', CREAM = '#FFFFFF', TIGER = '#F4B36A', WOOD = '#B58A5A';
type Attributes = Record<string, string | number>;
/** Filled shape with the brand outline (1.6 ink, round joins and caps). */
const solid = (tag: string, attributes: Attributes, fill: string, width = 1.6) =>
  s(tag, { ...attributes, fill, stroke: INK, 'stroke-width': width, 'stroke-linejoin': 'round', 'stroke-linecap': 'round' });
/** Unfilled ink stroke. */
const line = (d: string, width = 1.6) =>
  s('path', { d, fill: 'none', stroke: INK, 'stroke-width': width, 'stroke-linejoin': 'round', 'stroke-linecap': 'round' });
const dot = (cx: number, cy: number, r: number) => s('circle', { cx, cy, r, fill: INK });
const bowLoop = (d: string) => solid('path', { d }, SAKURA);

export const iconDrawings: Record<CatIcon, () => SVGElement[]> = {
  moon: () => [solid('path', { d: 'M14.6 3.8 A8.4 8.4 0 1 0 20.2 15.6 A6.6 6.6 0 0 1 14.6 3.8 Z' }, YOLK), dot(18.6, 5.4, 1)],
  scale: () => [
    solid('path', { d: 'M5.4 9.2 H18.6 C18.1 12.4 15.4 13.6 12 13.6 C8.6 13.6 5.9 12.4 5.4 9.2 Z' }, SAKURA_LIGHT),
    solid('rect', { x: 4.6, y: 14.2, width: 14.8, height: 6.4, rx: 2.2 }, SKY),
    solid('circle', { cx: 12, cy: 17.4, r: 1.7 }, CREAM, 1.3)],
  dango: () => [
    s('path', { d: 'M5.5 21 L19 3.5', fill: 'none', stroke: WOOD, 'stroke-width': 1.8, 'stroke-linecap': 'round' }),
    solid('circle', { cx: 8.6, cy: 17, r: 3.3 }, MATCHA), solid('circle', { cx: 12.25, cy: 12.25, r: 3.3 }, CREAM), solid('circle', { cx: 15.9, cy: 7.5, r: 3.3 }, SAKURA_LIGHT),
    dot(11.2, 12.2, 0.55), dot(13.3, 12.2, 0.55)],
  stripes: () => [
    solid('path', { d: 'M5.2 9.6 L5.6 4.4 L9.6 6.9 Z M18.8 9.6 L18.4 4.4 L14.4 6.9 Z' }, TIGER),
    solid('circle', { cx: 12, cy: 13, r: 7.6 }, TIGER),
    line('M10.6 6.2 L11 8.4 M12 5.6 V8.4 M13.4 6.2 L13 8.4 M4.8 13 H7.2 M5 15.2 H7.4 M19.2 13 H16.8 M19 15.2 H16.6', 1.3),
    dot(9.6, 12.4, 0.95), dot(14.4, 12.4, 0.95),
    line('M11 15.2 q.5 .7 1 0 q.5 .7 1 0', 1.1)],
  bolt: () => [solid('path', { d: 'M13.6 2.8 L5.8 13.4 H11.2 L10 21.2 L18.2 9.8 H12.8 Z' }, YOLK)],
  paw: () => [
    solid('ellipse', { cx: 12, cy: 15.6, rx: 4.4, ry: 3.7 }, SAKURA_LIGHT),
    solid('circle', { cx: 6.4, cy: 10.6, r: 1.9 }, SAKURA_LIGHT), solid('circle', { cx: 9.9, cy: 7, r: 1.9 }, SAKURA_LIGHT),
    solid('circle', { cx: 14.1, cy: 7, r: 1.9 }, SAKURA_LIGHT), solid('circle', { cx: 17.6, cy: 10.6, r: 1.9 }, SAKURA_LIGHT)],
  fish: () => [
    solid('path', { d: 'M3.6 12 C6.6 6.8 13.6 6.8 16.8 12 C13.6 17.2 6.6 17.2 3.6 12 Z' }, SKY),
    solid('path', { d: 'M16.8 12 L20.6 8.4 V15.6 Z' }, SKY),
    dot(7.6, 11.2, 0.9), line('M11.4 9.6 Q12.8 12 11.4 14.4', 1.2)],
  yarn: () => [
    solid('circle', { cx: 11, cy: 11, r: 7.4 }, SAKURA_LIGHT),
    line('M5.4 7.8 Q11 9.4 15.6 5.4 M4.4 12.4 Q11 13 17.6 8.8 M6.6 16.8 Q12.4 15.6 17.8 12.6', 1.2),
    line('M16.2 16.2 Q19.6 17.4 19.4 21')],
  star: () => [solid('path', { d: 'M12 3.4 L14.5 8.6 L20.2 9.3 L16 13.2 L17.1 18.8 L12 16 L6.9 18.8 L8 13.2 L3.8 9.3 L9.5 8.6 Z' }, YOLK)],
  heart: () => [solid('path', { d: 'M12 20 C5.4 15.4 3.6 11.4 5.4 8.2 C7.2 5.2 10.8 5.6 12 8.4 C13.2 5.6 16.8 5.2 18.6 8.2 C20.4 11.4 18.6 15.4 12 20 Z' }, SAKURA)],
  leaf: () => [
    solid('path', { d: 'M4.8 19.2 C4.8 10.2 9.8 4.8 19.2 4.8 C19.2 14.2 13.8 19.2 4.8 19.2 Z' }, MATCHA),
    line('M5.6 18.4 L14.4 9.6', 1.3)],
  bow: () => [
    bowLoop('M12 12 C9 7 4 7.2 4.2 11.6 C4.4 16 9 16.4 12 12 Z'), bowLoop('M12 12 C15 7 20 7.2 19.8 11.6 C19.6 16 15 16.4 12 12 Z'),
    line('M10.6 13.4 L8.6 19.4 M13.4 13.4 L15.4 19.4'),
    solid('circle', { cx: 12, cy: 12, r: 2 }, SAKURA_LIGHT)],
};
/** A free-standing icon (for the picker). Decorative: the control that holds it carries the name. */
export function catIconSvg(icon: CatIcon, size = 24): SVGElement {
  return s('svg', { class: 'cat-icon', viewBox: '0 0 24 24', width: size, height: size, 'aria-hidden': 'true', focusable: 'false' }, ...iconDrawings[icon]());
}
/** The round badge shown at the corner of an avatar: white disc, 1.5 px ink ring, the icon inset inside it. */
export function iconBadge(icon: CatIcon, avatarSize: number): SVGElement {
  const size = Math.max(10, Math.round(avatarSize * 0.4)), inset = size * 0.14;
  const badge = s('svg', { class: 'icon-badge', viewBox: `0 0 ${size} ${size}`, width: size, height: size, 'aria-hidden': 'true', focusable: 'false' },
    s('circle', { cx: size / 2, cy: size / 2, r: size / 2 - 0.75, fill: '#FFFFFF', stroke: INK, 'stroke-width': 1.5 }));
  const inner = catIconSvg(icon, size - 2 * inset); inner.setAttribute('x', String(inset)); inner.setAttribute('y', String(inset));
  badge.append(inner); return badge;
}
export function isCatIcon(value: string): value is CatIcon { return (catIcons as readonly string[]).includes(value); }
