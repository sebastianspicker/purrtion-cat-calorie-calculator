import { energyUnits, energyInUnit, kcalPerGram, analyseFood, parsePlan,
  type Food, type EnergyUnit, type Completeness, type Analysis, type LifeStageClaim, type EnergySource } from '../../../../packages/core/src/index.js';
import { h, button, field, selectField, formText, newId, markDirty, errorText, decimal, notice, optionalNumber, chip, table } from '../dom.js';
import { t, msg, num } from '../i18n.js';
import { equationChip } from '../estimate.js';
import type { AppContext } from '../context.js';
const units = energyUnits.map(unit => [unit, unit] as const);
export function foodsPage(ctx: AppContext): HTMLElement {
  const list = h('div', { class: 'food-list' }, ...ctx.store.plan.foods.map(food => foodEditor(ctx, food)));
  const add = button(t('food.add'), () => {
    if (list.querySelector('[data-new-food]')) return;
    const form = foodEditor(ctx, null); form.setAttribute('data-new-food', 'true'); list.prepend(form);
    form.querySelector('input')?.focus();
  }, 'button primary');
  return h('div', null, h('header', { class: 'page-heading heading-with-action' },
    h('div', null, h('h1', null, t('food.title')), h('p', null, t('food.lead'))), add),
    notice(t('food.notice')), list);
}
const constituents = ['moisture', 'protein', 'fat', 'fibre', 'ash'] as const;
function foodEditor(ctx: AppContext, food: Food | null): HTMLElement {
  const id = food?.id ?? newId('food');
  const prefix = `${id}-`;
  const form = h('form', { class: 'food-editor section sticker' }); const error = h('p', { class: 'form-error', role: 'alert' });
  let oldUnit: EnergyUnit = food?.energyUnit ?? 'kcal/100g';
  const unitControl = selectField(t('food.unit'), `${prefix}unit`, oldUnit, units);
  const energyControl = field(t('food.energy'), `${prefix}energy`, food?.energyPerUnit ?? '', { numeric: true, maxDecimals: 4, required: false, help: t('food.energy.help') });
  unitControl.querySelector('select')!.addEventListener('change', event => {
    const select = event.currentTarget as HTMLSelectElement; const input = energyControl.querySelector('input')!;
    if (input.value.trim()) {
      try { input.value = String(Math.round(energyInUnit({ energyPerUnit: decimal(input.value, t('food.energy'), 4), energyUnit: oldUnit }, select.value as EnergyUnit) * 1e4) / 1e4); }
      catch { select.value = oldUnit; error.textContent = t('food.unitError'); return; }
    }
    oldUnit = select.value as EnergyUnit;
  });
  const a = food?.analysis ?? null;
  const analysisFields = h('div', { class: 'fields-grid analysis-fields' }, ...constituents.map(key =>
    field(t(`analysis.${key}`), `${prefix}${key}`, a ? a[key] ?? '' : '', { numeric: true, maxDecimals: 2, required: false, unit: '%', ...(key === 'moisture' ? { help: t('analysis.moisture.help') } : {}) })),
    selectField(t('analysis.kind'), `${prefix}kind`, a?.kind ?? 'prepared', [['prepared', t('analysis.kind.prepared')], ['fresh', t('analysis.kind.fresh')]]));
  const derived = h('div', { class: 'derived', 'aria-live': 'polite' });
  const effective = h('p', { class: 'caption' });
  const sourceLabel = (source: EnergySource) => source === 'estimate' ? t('food.source.estimate') : source === 'analysis' ? t('food.source.analysis') : t('food.source.label');
  form.append(h('div', { class: 'section-heading' }, h('h2', null, food?.name ?? t('food.new')),
    food ? chip(sourceLabel(food.energySource), food.energySource === 'label' ? '' : 'status-reference-only') : null),
    h('div', { class: 'fields-grid food-fields' }, field(t('food.name'), `${prefix}name`, food?.name ?? ''),
      selectField(t('food.type'), `${prefix}type`, food?.type ?? 'wet', [['wet', t('food.type.wet')], ['dry', t('food.type.dry')]], t('food.type.help')),
      selectField(t('food.source'), `${prefix}source`, food?.energySource ?? 'estimate', [['label', t('food.source.label')], ['estimate', t('food.source.estimate')], ['analysis', t('food.source.analysis')]]),
      energyControl, unitControl,
      selectField(t('food.completeness'), `${prefix}complete`, food?.completeness ?? 'unknown', [['unknown', t('food.complete.unknown')], ['complete', t('food.complete.complete')], ['complementary', t('food.complete.complementary')]]),
      selectField(t('food.claim'), `${prefix}claim`, food?.lifeStageClaim ?? 'unknown', [['unknown', t('food.claim.unknown')], ['adult', t('food.claim.adult')], ['growth', t('food.claim.growth')], ['all', t('food.claim.all')]], t('food.claim.help'))),
    h('fieldset', { class: 'analysis' }, h('legend', null, t('analysis.title')), h('p', { class: 'caption' }, t('analysis.help')), analysisFields, derived),
    field(t('food.note'), `${prefix}note`, food?.note ?? '', { required: false, maxLength: 1000 }), effective,
    error, h('div', { class: 'form-actions' }, h('button', { type: 'submit', class: 'button primary' }, food ? t('food.save') : t('food.create')),
      button(food ? t('food.delete') : t('ui.cancel'), () => {
        if (!food) { form.remove(); return; }
        const inUse = ctx.store.plan.cats.some(c => c.balanceFoodId === id || c.meals.some(m => m.foodId === id));
        if (inUse) { error.textContent = t('food.inUse'); return; }
        if (canReplacePage() && confirm(t('food.deleteConfirm', { name: food.name }))) { ctx.store.commit({ ...ctx.store.plan, foods: ctx.store.plan.foods.filter(f => f.id !== id) }); ctx.render(); }
      }, 'button subtle')));
  function canReplacePage(): boolean {
    const otherEdits = [...document.querySelectorAll<HTMLFormElement>('form[data-dirty="true"]')].some(f => f !== form);
    return !otherEdits || confirm(t('food.otherEdits'));
  }
  function readAnalysis(): Analysis | null {
    const values = Object.fromEntries(constituents.map(key => [key, optionalNumber(form, `${prefix}${key}`, t(`analysis.${key}`), 2)])) as Record<typeof constituents[number], number | null>;
    const required = (['protein', 'fat', 'fibre', 'ash'] as const);
    if (constituents.every(key => values[key] === null)) return null;
    const missing = required.filter(key => values[key] === null);
    if (missing.length) throw new Error(t('analysis.incomplete', { fields: missing.map(key => t(`analysis.${key}`)).join(', ') }));
    return { protein: values.protein!, fat: values.fat!, fibre: values.fibre!, ash: values.ash!, moisture: values.moisture, kind: formText(form, `${prefix}kind`) as Analysis['kind'] };
  }
  function read(): Food {
    const energy = formText(form, `${prefix}energy`);
    return { id, name: formText(form, `${prefix}name`), type: formText(form, `${prefix}type`) as Food['type'],
      energyPerUnit: energy === '' ? null : decimal(energy, t('food.energy'), 4), energyUnit: formText(form, `${prefix}unit`) as EnergyUnit,
      energySource: formText(form, `${prefix}source`) as EnergySource, completeness: formText(form, `${prefix}complete`) as Completeness,
      lifeStageClaim: formText(form, `${prefix}claim`) as LifeStageClaim, analysis: readAnalysis(), note: formText(form, `${prefix}note`) };
  }
  function candidatePlan(next: Food) {
    return { ...ctx.store.plan, foods: ctx.store.plan.foods.some(f => f.id === id) ? ctx.store.plan.foods.map(f => f.id === id ? next : f) : [...ctx.store.plan.foods, next] };
  }
  function updateDerived(): void {
    let next: Food;
    try {
      const raw = read(); if (!raw.name) raw.name = t('food.new');
      next = parsePlan(candidatePlan(raw)).foods.find(f => f.id === id)!;
    } catch (err) {
      effective.textContent = '';
      derived.replaceChildren(h('p', { class: 'caption' }, t('analysis.invalid', { detail: errorText(err) }))); return;
    }
    const k = kcalPerGram(next);
    effective.textContent = t('food.effective', { perGram: num(k, 4), per100: num(k * 100, 1) });
    const r = analyseFood(next);
    if (!r) { derived.replaceChildren(h('p', { class: 'caption' }, t('analysis.none'))); return; }
    const pct = (v: number) => `${num(v, 1)} %`;
    const shares = r.energySharePercent;
    derived.replaceChildren(
      h('div', { class: 'derived-head' }, h('div', { class: 'estimate-figure' }, h('span', { class: 'figure-label' }, t('analysis.me')),
        h('span', { class: 'figure-number', 'data-testid': `food-me-${id}` }, num(r.meKcalPer100g, 1), h('span', { class: 'unit' }, ' kcal/100 g'))),
        equationChip(r.method)),
      h('dl', { class: 'stat-list' },
        h('dt', null, t('analysis.atwater')), h('dd', null, `${num(r.atwaterKcalPer100g, 1)} kcal/100 g (${num((r.atwaterKcalPer100g / r.meKcalPer100g - 1) * 100, 1)} %)`),
        h('dt', null, t('analysis.nfe')), h('dd', null, pct(r.nfe)),
        h('dt', null, t('analysis.moistureUsed')), h('dd', null, pct(r.moisture)),
        h('dt', null, t('analysis.proteinPer1000')), h('dd', null, `${num(r.proteinGPer1000kcal, 1)} g`),
        h('dt', null, t('analysis.fatPer1000')), h('dd', null, `${num(r.fatGPer1000kcal, 1)} g`),
        h('dt', null, t('analysis.carbPercent')), h('dd', null, pct(shares.carbohydrate)),
        h('dt', null, t('analysis.carbPer100')), h('dd', null, `${num(r.carbGPer100kcal, 1)} g`)),
      table([t('analysis.dmTitle'), t('analysis.protein'), t('analysis.fat'), t('analysis.fibre'), t('analysis.ash'), t('analysis.nfeShort')],
        [[t('analysis.dmRow'), pct(r.dryMatter.protein), pct(r.dryMatter.fat), pct(r.dryMatter.fibre), pct(r.dryMatter.ash), pct(r.dryMatter.nfe)]], t('analysis.dmTitle')),
      h('div', { class: 'share-bar', role: 'img', 'aria-label': t('analysis.sharesAria', { protein: num(shares.protein, 0), fat: num(shares.fat, 0), carb: num(shares.carbohydrate, 0) }) },
        ...(['protein', 'fat', 'carbohydrate'] as const).map(key => shareSegment(key, shares[key]))),
      h('p', { class: 'caption' }, t('analysis.sharesText', { protein: num(shares.protein, 0), fat: num(shares.fat, 0), carb: num(shares.carbohydrate, 0) })),
      ...r.warnings.map(code => notice(msg(`food.${code}`), 'warning')));
  }
  markDirty(form);
  form.addEventListener('input', updateDerived); form.addEventListener('change', updateDerived);
  form.addEventListener('submit', event => { event.preventDefault(); try {
    const next = read();
    if (!canReplacePage()) return;
    ctx.store.commit(candidatePlan(next)); form.dataset.dirty = 'false'; ctx.render();
  } catch (err) { error.textContent = errorText(err); } });
  updateDerived();
  return form;
}
function shareSegment(key: 'protein' | 'fat' | 'carbohydrate', value: number): HTMLElement {
  const segment = h('span', { class: `share share-${key}` });
  // CSSOM property (allowed by the CSP), not an inline style attribute.
  segment.style.flexGrow = String(Math.max(0, value));
  return segment;
}
