import { energyModel as m } from '../../../../packages/core/src/index.js';
import { h, button, notice, download, table } from '../dom.js';
import { t, msg, num, type UiKey } from '../i18n.js';
import { tex } from '../math.js';
import { generic } from '../formulas.js';
import { citation, referenceLabels } from '../estimate.js';
import type { AppContext } from '../context.js';

type Strength = 'G' | 'M' | 'E' | 'O' | 'X' | 'S';
function card(title: string, formulas: string[], strength: Strength[], refs: string, text?: string): HTMLElement {
  return h('article', { class: 'method-card sticker' }, h('h3', null, title),
    h('div', { class: 'formula-stack' }, ...formulas.map(f => tex(f, true))),
    text ? h('p', null, text) : null,
    h('p', { class: 'evidence' }, h('span', { class: 'evidence-label' }, t('method.evidence')), ...strength.map(code => h('abbr', { class: `chip strength strength-${code}`, title: t(`strength.${code}` as UiKey) }, code)),
      h('span', { class: 'refs' }, refs)));
}
export function methodPage(ctx: AppContext): HTMLElement {
  const k = m.kitten;
  const bandRows = k.bandCentreMonths.map((months, i) => [t('method.kittenBand.at', { months: num(months, 1) }),
    num(k.bandLow[i]!, 2), num(k.bandHigh[i]!, 2)]);
  const strengths: Strength[] = ['G', 'M', 'E', 'O', 'X', 'S'];
  return h('article', { class: 'prose method' }, h('header', { class: 'page-heading' }, h('h1', null, t('method.title')), h('p', null, t('method.lead'))),
    h('section', { class: 'section' }, h('h2', null, t('method.allocation')),
      h('div', { class: 'method-grid' },
        card(t('method.allocation.card'), [generic.fixed(), generic.balance(), generic.balanceGrams()], ['X'], t('method.allocation.refs'), t('method.allocation.text')),
        card(t('method.units'), [generic.kj()], ['G'], t('method.units.refs'), t('method.units.text'))),
      h('p', null, t('method.rounding')), h('p', null, t('method.extras'))),
    h('section', { class: 'section' }, h('h2', null, t('method.estimator')), h('p', null, t('method.estimator.lead')),
      h('div', { class: 'method-grid' },
        card(t('method.rer'), [generic.rer()], ['G'], citation('rer'), t('method.rer.text')),
        card(t('method.mer'), [generic.mer(), generic.band(), generic.maintainRange()], ['G'], citation('adult-fediaf'), t('method.mer.text')),
        card(t('method.ibw'), [generic.ibw()], ['G', 'X'], citation('weight-loss-aaha'), t('method.ibw.text')),
        card(msg('equation.weight-loss-aaha'), [generic.loss(), generic.floor()], ['G'], citation('weight-loss-aaha'), t('method.loss.text')),
        card(msg('equation.adult-gain'), [generic.gain()], ['X'], citation('adult-gain'), t('method.gain.text')),
        card(msg('equation.kitten-nrc'), [generic.kittenNrc(), generic.kittenTransition(), generic.kittenCap()], ['G', 'S'], citation('kitten-nrc'), t('method.kittenNrc.text')),
        h('article', { class: 'method-card sticker' }, h('h3', null, msg('equation.kitten-fediaf-band')), tex(generic.kittenBand(), true),
          table([t('method.kittenBand.age'), t('method.kittenBand.low'), t('method.kittenBand.high')], bandRows, msg('equation.kitten-fediaf-band')),
          h('p', { class: 'evidence' }, h('span', { class: 'evidence-label' }, t('method.evidence')), h('abbr', { class: 'chip strength strength-G', title: t('strength.G') }, 'G'), h('span', { class: 'refs' }, citation('kitten-fediaf-band')))),
        card(msg('equation.gestation-fediaf'), [generic.gestation()], ['G'], citation('gestation-fediaf'), t('method.gestation.text')),
        card(msg('equation.lactation-fediaf'), [generic.lactation(), generic.lactationC(), generic.lactationL()], ['G'], citation('lactation-fediaf'), t('method.lactation.text')))),
    h('section', { class: 'section' }, h('h2', null, t('method.food')), h('p', null, t('method.food.lead')),
      h('div', { class: 'method-grid' },
        card(msg('equation.fediaf-4-step'), [generic.nfe(), generic.ge(), generic.digestibility(), generic.me4()], ['G'], citation('fediaf-4-step'), t('method.me4.text')),
        card(msg('equation.fediaf-fresh'), [generic.fresh()], ['G'], citation('fediaf-fresh'), t('method.fresh.text')),
        card(t('method.atwater'), [generic.atwater()], ['G', 'M'], citation('atwater'), t('method.atwater.text')),
        card(t('method.protein'), [generic.protein(), generic.proteinGrowth()], ['G'], `[1] ${referenceLabels[1]}`, t('method.protein.text'))),
      notice(t('method.labelCaveat'), 'note', t('method.labelCaveat.title'))),
    h('section', { class: 'section' }, h('h2', null, t('method.practical')),
      notice(t('method.grams'), 'note', t('method.grams.title')),
      h('p', null, t('method.monitoring')),
      h('ul', null, h('li', null, t('advice.oneChange')), h('li', null, t('advice.secondPlateau')))),
    h('section', { class: 'section' }, h('h2', null, t('method.strength')),
      h('dl', { class: 'strength-list' }, ...strengths.flatMap(code => [h('dt', null, h('span', { class: `chip strength strength-${code}` }, code)), h('dd', null, t(`strength.${code}` as UiKey))]))),
    h('section', { class: 'section' }, h('h2', null, t('method.limits')),
      notice(t('method.limits.text'), 'vet'), h('p', null, t('method.principle'))),
    h('section', { class: 'section' }, h('h2', null, t('method.storage')),
      h('p', null, t('method.storage.text')), h('p', null, t('method.storage.tabs')),
      h('div', { class: 'form-actions' },
        ctx.store.damagedJSON() ? button(t('method.exportDamaged'), () => download('purrtion-recovery.json', ctx.store.damagedJSON()!, 'application/json')) : null,
        button(t('method.reset'), () => {
          if (confirm(t('method.resetConfirm'))) { ctx.store.commit(ctx.store.sample, true); ctx.render(); }
        }, 'button danger'))),
    h('section', { class: 'section' }, h('h2', null, t('method.reading')),
      h('p', null, t('method.science')),
      h('ul', null,
        h('li', null, h('a', { href: 'https://www.merckvetmanual.com/management-and-nutrition/nutrition-small-animals/nutritional-requirements-of-small-animals', target: '_blank', rel: 'noopener noreferrer' }, t('method.link.merck'))),
        h('li', null, h('a', { href: 'https://www.aaha.org/resources/2021-aaha-nutrition-and-weight-management-guidelines/prevention-of-obesity/', target: '_blank', rel: 'noopener noreferrer' }, t('method.link.aaha')))),
      h('p', { class: 'caption' }, t('method.links.note'))));
}
