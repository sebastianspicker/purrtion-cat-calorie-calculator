import { energyModel, type Cat, type CatResult, type EquationId } from '../../../packages/core/src/index.js';
import { h, fill, notice, chip } from './dom.js';
import { t, msg, num } from './i18n.js';
import { createRuler } from './ruler.js';
import { explain } from './formulas.js';
import { tex } from './math.js';
/** Short labels for the SCIENCE.md reference numbers used in `energyModel.references`. */
export const referenceLabels: Record<number, string> = {
  1: 'FEDIAF 2025', 2: 'NRC 2006', 4: 'AAHA 2021', 5: 'AAHA 2014', 9: 'Merck Veterinary Manual', 13: 'Fontaine 2012',
  21: 'Hall et al. 2013', 22: 'Jewell & Jackson 2023', 25: 'Vecchiato et al. 2021', 27: 'Menniti et al. 2026',
};
export function citation(key: keyof typeof energyModel.references): string {
  return energyModel.references[key].map(ref => `[${ref}] ${referenceLabels[ref] ?? ''}`.trim()).join('; ');
}
export function equationChip(id: EquationId | 'fediaf-4-step' | 'fediaf-fresh'): HTMLElement {
  return h('span', { class: 'equation-chip' }, h('span', null, msg(`equation.${id}`)), h('small', null, t('estimate.sources', { refs: citation(id) })));
}
/** The referral panel: plain icon, plain words, no kcal numbers, no mascot. */
export function referralPanel(result: CatResult): HTMLElement {
  return h('section', { class: 'referral-panel', role: 'alert', 'aria-labelledby': `refer-${result.id}` },
    notice(h('div', null, h('p', null, t('refer.intro')),
      h('ul', null, ...result.estimate.reasons.map(code => h('li', null, msg(`refer.${code}`)))),
      h('p', null, t('refer.outro'))), 'vet', t('refer.title')));
}
export interface EstimateViewOptions { why?: boolean; comparison?: boolean }
/** Estimator output for one cat. The ruler persists across updates so the target pin can glide. */
export function createEstimateView(options: EstimateViewOptions = {}): { element: HTMLElement; update: (cat: Cat, result: CatResult, asOf: string) => void; clear: () => void } {
  const ruler = createRuler();
  const head = h('div', { class: 'estimate-head' });
  const body = h('div', { class: 'estimate-body' });
  const after = h('div', { class: 'estimate-after' });
  const element = h('section', { class: 'estimate-view', 'aria-label': t('estimate.title') }, head, body, ruler.element, after);
  function update(cat: Cat, result: CatResult, asOf: string): void {
    const e = result.estimate;
    fill(head, h('h2', null, t('estimate.title')), h('div', { class: 'chip-row' },
      chip(msg(`status.${e.status}`), `status-${e.status}`), e.stage ? chip(msg(`stage.${e.stage}`)) : null,
      e.lifeStageLabel && e.stage !== 'kitten' ? chip(msg(`lifeStage.${e.lifeStageLabel}`)) : null));
    const hasNumbers = e.startKcal !== null && e.lowKcal !== null && e.highKcal !== null;
    ruler.update(hasNumbers ? { lowKcal: e.lowKcal, highKcal: e.highKcal, startKcal: e.startKcal, floorKcal: e.floorKcal,
      bandLowKcal: e.referenceBand?.lowKcal ?? null, bandHighKcal: e.referenceBand?.highKcal ?? null,
      targetKcal: options.comparison === false ? null : cat.targetKcal }
      : { lowKcal: null, highKcal: null, startKcal: null, floorKcal: null, bandLowKcal: null, bandHighKcal: null, targetKcal: null });
    element.dataset.status = e.status;
    if (e.status === 'refer') { fill(body, referralPanel(result)); fill(after); return; }
    if (e.status === 'needs-input') {
      fill(body, h('div', { class: 'needs-input' }, h('p', null, t('estimate.needsInput')),
        h('ul', null, ...e.missing.map(code => h('li', null, msg(`missing.${code}`))))));
      fill(after); return;
    }
    const reference = e.status === 'reference-only';
    fill(body, 
      reference ? notice(t('estimate.referenceBanner'), 'vet', t('estimate.referenceTitle')) : null,
      h('div', { class: 'estimate-figure' },
        h('span', { class: 'figure-label' }, reference ? t('estimate.referenceValue') : t('estimate.start')),
        h('span', { class: 'figure-number', 'data-testid': 'estimate-start' }, num(e.startKcal!, 0), h('span', { class: 'unit' }, ` ${t('unit.kcalPerDay')}`)),
        h('span', { class: 'figure-range' }, t('estimate.rangeText', { low: num(e.lowKcal!, 0), high: num(e.highKcal!, 0) }))),
      e.equation ? h('div', { class: 'chip-row' }, equationChip(e.equation)) : null);
    const comparison = e.comparison, whyOpen = after.querySelector('details.why')?.hasAttribute('open') ?? false;
    fill(after, 
      options.comparison !== false && comparison ? h('div', { class: 'comparison' },
        comparison.belowFloor ? notice(msg('comparison.below-floor'), 'error', t('comparison.belowFloorTitle')) : null,
        h('p', null, t('comparison.ratio', { target: num(cat.targetKcal, 0), percent: num(comparison.targetToStartRatio * 100, 0) })),
        comparison.belowRange && !comparison.belowFloor ? notice(msg('comparison.below-range'), 'warning') : null,
        comparison.aboveRange ? notice(msg('comparison.above-range'), 'warning') : null,
        comparison.differsOver30Percent ? notice(msg('comparison.differs-over-30-percent'), 'warning') : null) : null,
      e.notes.length ? h('ul', { class: 'note-list' }, ...e.notes.map(code => h('li', null, msg(`note.${code}`)))) : null,
      options.why !== false ? h('details', { class: 'why', open: whyOpen }, h('summary', null, t('why.title')),
        h('p', { class: 'caption' }, t('why.intro')),
        h('ol', { class: 'formula-list' }, ...explain(cat, e, asOf).map(line => h('li', null, tex(line.latex, true), line.caption ? h('small', null, line.caption) : null)))) : null);
  }
  /** Empties the view when there is no valid result to show. */
  function clear(): void {
    fill(head); fill(body); fill(after); element.removeAttribute('data-status');
    ruler.update({ lowKcal: null, highKcal: null, startKcal: null, floorKcal: null, bandLowKcal: null, bandHighKcal: null, targetKcal: null });
  }
  return { element, update, clear };
}
