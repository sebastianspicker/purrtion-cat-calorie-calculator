import { calculatePlan, todayLocalISO, type Activity } from '../../../../packages/core/src/index.js';
import { h, button, field, formText, formNumber, markDirty, table, notice, errorText, newId, chip } from '../dom.js';
import { t, msg, num } from '../i18n.js';
import { avatar } from '../mascot.js';
import type { AppContext } from '../context.js';

export function goalLabel(goal: string): string {
  return goal === 'loss' ? t('goal.loss') : goal === 'gain' ? t('goal.gain') : t('goal.maintain');
}
export function household(ctx: AppContext): HTMLElement {
  const { plan } = ctx.store; const result = calculatePlan(plan, { asOf: todayLocalISO() });
  const foodName = (id: string) => plan.foods.find(f => f.id === id)?.name ?? id;
  const bowls = h('section', { class: 'bowls', 'aria-label': t('home.bowls') }, ...plan.cats.map(cat => {
    const r = result.cats.find(c => c.id === cat.id)!;
    const fixed = cat.meals.length ? t('home.fixedSummary', { count: String(cat.meals.length), grams: num(r.fixedGrams, 0) }) : t('home.noFixed');
    return h('article', { class: 'bowl sticker' },
      h('header', { class: 'bowl-head' }, avatar(cat.id, 44, cat.icon), h('h2', null, cat.name)),
      h('p', { class: 'bowl-number' }, h('span', { 'data-testid': `dry-${cat.id}` }, String(r.balanceGramsRounded), h('span', { class: 'unit' }, ' g'))),
      h('p', { class: 'bowl-food' }, foodName(r.balanceFoodId)),
      h('p', { class: 'bowl-fixed' }, fixed),
      h('div', { class: 'chip-row' }, chip(msg(`status.${r.estimate.status}`), `status-${r.estimate.status}`), chip(t('home.target', { kcal: num(cat.targetKcal, 0) }))),
      button(t('home.open', { name: cat.name }), () => ctx.navigate({ kind: 'cat', id: cat.id }), 'button subtle bowl-open'));
  }));
  const prepare = h('section', { class: 'section sticker prepare' }, h('h2', null, t('home.prepare')),
    h('ul', { class: 'prepare-list' }, ...result.totals.balanceByFood.map(b => h('li', null,
      h('span', { class: 'prepare-food' }, foodName(b.foodId)), h('span', { class: 'prepare-grams' }, `${b.gramsRounded} g`)))),
    h('p', { class: 'prepare-total' }, h('span', null, t('home.total')),
      h('strong', { 'data-testid': 'total-dry' }, String(result.totals.balanceGramsRounded), h('span', { class: 'unit' }, ' g'))),
    h('p', { class: 'caption' }, t('home.prepareHelp', { grams: num(result.totals.balanceGramsExact, 1) })));
  const mealRows = plan.cats.flatMap(cat => cat.meals.map(meal => [cat.name, meal.label, foodName(meal.foodId), `${num(meal.grams, 1)} g`]));
  const meals = h('section', { class: 'section' }, h('h2', null, t('home.schedule')),
    mealRows.length ? table([t('home.col.cat'), t('home.col.meal'), t('home.col.food'), t('home.col.eaten')], mealRows, t('home.schedule'))
      : h('p', { class: 'caption' }, t('home.noMeals')));
  const activities = h('section', { class: 'section' }, h('h2', null, t('home.activities')),
    table([t('home.col.activity'), ...plan.cats.map(c => c.name)], plan.activities.map(a => [a.label, ...result.cats.map(c => `${c.activities.find(x => x.id === a.id)!.roundedGrams} g`)]), t('home.activities')),
    h('p', { class: 'caption' }, t('home.activitiesHelp')), activityEditor(ctx));
  const warnings = [...new Set(result.cats.flatMap(c => c.warnings))].sort();
  const serious = result.cats.filter(c => c.estimate.status === 'refer').map(c => plan.cats.find(x => x.id === c.id)!.name);
  return h('div', null, h('header', { class: 'page-heading' }, h('h1', null, t('home.title')), h('p', null, t('home.lead'))),
    serious.length ? notice(t('home.referNames', { names: serious.join(', ') }), 'vet', t('refer.title')) : null,
    bowls, prepare, h('div', { class: 'detail-grid' }, meals, activities),
    h('section', { class: 'section assumptions' }, h('h2', null, t('home.assumptions')),
      ...warnings.map(code => notice(msg(`warning.${code}`), code === 'over-budget' || code === 'complementary-balance-food' ? 'error' : 'warning')),
      h('p', { class: 'caption' }, t('home.disclaimer'))));
}
function activityEditor(ctx: AppContext): HTMLElement {
  const details = h('details', { class: 'activity-editor no-print' }, h('summary', null, t('activity.adjust')));
  const form = h('form', null); const error = h('p', { class: 'form-error', role: 'alert' });
  const rows = h('div');
  function row(activity: Activity): HTMLElement {
    const element = h('div', { class: 'activity-row', 'data-id': activity.id },
      field(t('activity.label'), `${activity.id}-label`, activity.label),
      field(t('activity.share'), `${activity.id}-share`, activity.sharePercent, { numeric: true, maxDecimals: 2, unit: '%' }));
    element.append(button(t('ui.remove'), () => { element.remove(); form.dataset.dirty = 'true'; }, 'button subtle'));
    return element;
  }
  rows.append(...ctx.store.plan.activities.map(row));
  const add = button(t('activity.add'), () => {
    if (rows.children.length >= 12) { error.textContent = t('activity.max'); return; }
    rows.append(row({ id: newId('activity'), label: t('activity.new'), sharePercent: 0 })); form.dataset.dirty = 'true';
  }, 'button subtle');
  form.append(rows, h('p', { class: 'caption' }, t('activity.help')), error,
    h('div', { class: 'form-actions' }, add, h('button', { type: 'submit', class: 'button primary' }, t('activity.save'))));
  markDirty(form);
  form.addEventListener('submit', event => {
    event.preventDefault();
    try {
      const activities = [...rows.querySelectorAll<HTMLElement>('[data-id]')].map(element => {
        const id = element.dataset.id!;
        return { id, label: formText(form, `${id}-label`), sharePercent: formNumber(form, `${id}-share`, t('activity.share'), 2) };
      });
      ctx.store.commit({ ...ctx.store.plan, activities }); form.dataset.dirty = 'false'; ctx.render();
    } catch (err) { error.textContent = errorText(err); }
  });
  details.append(form); return details;
}
