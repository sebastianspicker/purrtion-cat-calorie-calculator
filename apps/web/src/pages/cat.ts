import { calculatePlan, defaultProfile, catIcons, todayLocalISO, daysBetween, chronicMedicalFlags, acuteMedicalFlags, medicalFlags,
  type Cat, type CatResult, type Goal, type TargetSource, type Meal, type WeightEntry, type Profile, type MedicalFlag,
  type CatIcon, type Sex, type Neutered, type Lifestyle, type MuscleCondition, type ReproductionStatus, type Stage, type IdealWeightSource } from '../../../../packages/core/src/index.js';
import { h, fill, button, field, selectField, radioGroup, checkbox, formNumber, optionalNumber, formText, newId, markDirty, errorText,
  notice, chip, table, setValue, decimal, inputNumber, type Child } from '../dom.js';
import { t, msg, num, dateText, type UiKey } from '../i18n.js';
import { createEstimateView } from '../estimate.js';
import { weightChart } from '../chart.js';
import { avatar } from '../mascot.js';
import { catIconSvg } from '../cat-icons.js';
import { goalLabel } from './household.js';
import type { AppContext } from '../context.js';

export const lifestyles: readonly Lifestyle[] = ['sedentary', 'typical', 'active'];
export function lifestyleChoices(): [string, string, string][] {
  return [...lifestyles.map(l => [l, t(`lifestyle.${l}`), t(`lifestyle.${l}.help`)] as [string, string, string]),
    ['', t('lifestyle.default'), t('lifestyle.default.help')]];
}
export function bcsDescription(value: string): string { return value ? t(`bcs.${value}` as UiKey) : t('bcs.none'); }
/** BCS 1–9 as pills, plus "not scored"; the selected score's description is shown below. */
export function bcsPicker(name: string, value: number | null): HTMLElement {
  const describe = h('p', { class: 'bcs-description', id: `${name}-description`, 'aria-live': 'polite' }, bcsDescription(value === null ? '' : String(value)));
  const group = h('fieldset', { class: 'radio-group bcs-pills', 'aria-describedby': `${name}-description` },
    h('legend', null, t('bcs.legend')),
    h('div', { class: 'pill-row' }, ...Array.from({ length: 9 }, (_, i) => String(i + 1)).map(score => h('label', { class: 'pill' },
      h('input', { type: 'radio', name, value: score, checked: value === Number(score), 'aria-label': t('bcs.aria', { score }) }), h('span', { 'aria-hidden': 'true' }, score))),
      h('label', { class: 'pill pill-wide' }, h('input', { type: 'radio', name, value: '', checked: value === null }), h('span', null, t('bcs.notScored')))),
    h('div', { class: 'bcs-scale', 'aria-hidden': 'true' }, h('span', null, t('bcs.thin')), h('span', null, t('bcs.ideal')), h('span', null, t('bcs.heavy'))), describe);
  group.addEventListener('change', () => { describe.textContent = bcsDescription(formText(group, name)); });
  return group;
}
/** The cat's picture: one radio per icon plus "None"; each has the icon's name as its accessible name. */
export function iconPicker(name: string, value: CatIcon | null): HTMLFieldSetElement {
  const choice = (key: string, label: string, face: Child) => h('label', { class: 'icon-choice' },
    h('input', { type: 'radio', name, value: key, checked: key === (value ?? ''), 'aria-label': label }), h('span', { 'aria-hidden': 'true' }, face));
  return h('fieldset', { class: 'radio-group icon-picker' }, h('legend', null, t('icon.legend')),
    h('div', { class: 'icon-row' }, ...catIcons.map(icon => choice(icon, msg(`icon.${icon}`), catIconSvg(icon, 28))), choice('', t('icon.none'), t('icon.none'))));
}
export function medicalChecklist(prefix: string, selected: readonly MedicalFlag[]): HTMLElement {
  const box = (flag: MedicalFlag) => checkbox(msg(`medical.${flag}`), `${prefix}${flag}`, selected.includes(flag));
  return h('div', { class: 'health-lists' },
    h('fieldset', { class: 'checklist' }, h('legend', null, t('health.chronic')), h('p', { class: 'caption' }, t('health.chronic.help')), ...chronicMedicalFlags.map(box)),
    h('fieldset', { class: 'checklist acute' }, h('legend', null, t('health.acute')), h('p', { class: 'caption' }, t('health.acute.help')), ...acuteMedicalFlags.map(box)));
}
export function readMedical(root: HTMLElement, prefix: string): MedicalFlag[] {
  return medicalFlags.filter(flag => root.querySelector<HTMLInputElement>(`[name="${prefix}${flag}"]`)?.checked);
}
const goalChoices = (): [Goal, string][] => [['loss', t('goal.loss')], ['maintain', t('goal.maintain')], ['gain', t('goal.gain')]];
const sourceChoices = (): [TargetSource, string][] => [['provisional', t('source.provisional')], ['owner', t('source.owner')], ['veterinarian', t('source.veterinarian')]];
const sexChoices = (): [Sex, string][] => [['unknown', t('sex.unknown')], ['female', t('sex.female')], ['male', t('sex.male')]];
const neuterChoices = (): [Neutered, string][] => [['unknown', t('neutered.unknown')], ['yes', t('neutered.yes')], ['no', t('neutered.no')]];
const mcsChoices = (): [string, string][] => [['', t('mcs.none')], ['normal', t('mcs.normal')], ['mild', t('mcs.mild')], ['moderate', t('mcs.moderate')], ['severe', t('mcs.severe')]];
const reproChoices = (): [ReproductionStatus, string][] => [['none', t('repro.none')], ['gestation', t('repro.gestation')], ['lactation', t('repro.lactation')]];
const integerChoices = (max: number, empty: string): [string, string][] => [['', empty], ...Array.from({ length: max }, (_, i) => [String(i + 1), String(i + 1)] as [string, string])];

export function catPage(ctx: AppContext, id: string): HTMLElement {
  const cat = ctx.store.plan.cats.find(c => c.id === id)!;
  const asOf = todayLocalISO();
  const p = cat.profile;
  const form = h('form', { class: 'editor-form' });
  const error = h('p', { class: 'form-error', role: 'alert' });
  const meals = h('div', { class: 'meal-rows' });
  const foodChoices = ctx.store.plan.foods.map(f => [f.id, f.name] as const);
  let log: WeightEntry[] = cat.weightLog.map(e => ({ ...e }));
  let lastStage: Stage | null = null;
  const dirty = () => { form.dataset.dirty = 'true'; };

  function mealRow(meal: Meal): HTMLElement {
    const row = h('div', { class: 'meal-row', 'data-meal-id': meal.id },
      field(t('meal.label'), `${meal.id}-label`, meal.label),
      selectField(t('meal.food'), `${meal.id}-food`, meal.foodId, foodChoices),
      field(t('meal.grams'), `${meal.id}-grams`, meal.grams, { numeric: true, maxDecimals: 2, unit: 'g' }));
    row.append(button(t('ui.remove'), () => { row.remove(); dirty(); update(); }, 'button subtle'));
    return row;
  }
  meals.append(...cat.meals.map(mealRow));

  // ---- Profile ----
  const ageMode = p.birthDate !== null ? 'birth' : p.approxAgeYears !== null ? 'approx' : 'unknown';
  const birthField = field(t('profile.birthDate'), 'cat-birth', p.birthDate ?? '', { type: 'date', required: false });
  const approxField = field(t('profile.approxAge'), 'cat-age-years', p.approxAgeYears ?? '', { numeric: true, maxDecimals: 2, required: false, unit: t('unit.years'), help: t('profile.approxAge.help') });
  const neuterDate = field(t('profile.neuteredDate'), 'cat-neutered-date', p.neuteredDate ?? '', { type: 'date', required: false, help: t('profile.neuteredDate.help') });
  const adultWeight = field(t('weights.expectedAdult'), 'cat-adult-weight', p.expectedAdultWeightKg ?? '', { numeric: true, maxDecimals: 3, required: false, unit: 'kg', help: t('weights.expectedAdult.help') });
  const r = p.reproduction;
  const litter = selectField(t('repro.litter'), 'repro-litter', r.litterSize === null ? '' : String(r.litterSize), integerChoices(12, t('repro.notEntered')));
  const week = selectField(t('repro.week'), 'repro-week', r.lactationWeek === null ? '' : String(r.lactationWeek), integerChoices(12, t('repro.notEntered')));
  const preWeight = field(t('repro.preWeight'), 'repro-preweight', r.preBreedingWeightKg ?? '', { numeric: true, maxDecimals: 3, required: false, unit: 'kg', help: t('repro.preWeight.help') });
  const idealSource = radioGroup(t('weights.source'), 'cat-ideal-source', p.idealWeightSource ?? 'veterinarian',
    [['veterinarian', t('weights.source.vet')], ['estimate', t('weights.source.estimate')]], 'segmented');
  // Offered only while the ideal weight is a BCS estimate (parity with the Mac app).
  const reestimate = h('div', { class: 'form-actions' }, button(t('weights.reestimate'), () => { setValue(form, 'cat-ideal', ''); setValue(form, 'cat-ideal-source', 'veterinarian'); dirty(); renderLog(); update(); }, 'button subtle'),
    h('small', { class: 'caption' }, t('weights.reestimate.help')));
  const reproSection = h('section', { class: 'section sticker' }, h('h2', null, t('repro.title')), h('p', { class: 'caption' }, t('repro.help')),
    h('div', { class: 'fields-grid' }, selectField(t('repro.status'), 'repro-status', r.status, reproChoices()), litter, week, preWeight));

  form.append(
    h('section', { class: 'section sticker' }, h('h2', null, t('profile.title')),
      h('div', { class: 'fields-grid' }, field(t('profile.name'), 'cat-name', cat.name),
        field(t('profile.weight'), 'cat-weight', cat.weightKg, { numeric: true, maxDecimals: 3, unit: 'kg' })),
      iconPicker('cat-icon', cat.icon),
      radioGroup(t('profile.ageMode'), 'age-mode', ageMode, [['birth', t('profile.ageMode.birth')], ['approx', t('profile.ageMode.approx')], ['unknown', t('profile.ageMode.unknown')]], 'segmented'),
      h('div', { class: 'fields-grid' }, birthField, approxField),
      h('div', { class: 'fields-grid' }, selectField(t('profile.sex'), 'cat-sex', p.sex, sexChoices()),
        selectField(t('profile.neutered'), 'cat-neutered', p.neutered, neuterChoices()), neuterDate),
      radioGroup(t('lifestyle.legend'), 'cat-lifestyle', p.lifestyle ?? '', lifestyleChoices()),
      selectField(t('profile.goal'), 'cat-goal', cat.goal, goalChoices(), t('profile.goal.help'))),
    h('section', { class: 'section sticker' }, h('h2', null, t('target.title')),
      h('div', { class: 'fields-grid' },
        field(t('target.kcal'), 'cat-target', cat.targetKcal, { numeric: true, maxDecimals: 2, unit: t('unit.kcalPerDay'), help: t('target.kcal.help') }),
        selectField(t('target.source'), 'cat-target-source', cat.targetSource, sourceChoices()),
        field(t('target.extras'), 'cat-extras', cat.extraKcal, { numeric: true, maxDecimals: 2, unit: t('unit.kcalPerDay'), help: t('target.extras.help') }))),
    h('section', { class: 'section sticker' }, h('h2', null, t('body.title')), h('p', { class: 'caption' }, t('body.help')),
      bcsPicker('cat-bcs', p.bcs),
      h('div', { class: 'fields-grid' }, selectField(t('mcs.label'), 'cat-mcs', p.mcs ?? '', mcsChoices(), t('mcs.help')))),
    h('section', { class: 'section sticker' }, h('h2', null, t('weights.title')),
      h('div', { class: 'fields-grid' }, field(t('weights.ideal'), 'cat-ideal', p.idealWeightKg ?? '', { numeric: true, maxDecimals: 3, required: false, unit: 'kg', help: t('weights.ideal.help') }), adultWeight),
      idealSource,
      reestimate),
    reproSection,
    h('section', { class: 'section sticker' }, h('h2', null, t('health.title')), h('p', { class: 'caption' }, t('health.help')),
      medicalChecklist('medical-', p.medical),
      h('fieldset', { class: 'checklist' }, h('legend', null, t('health.other')),
        checkbox(t('health.endOfLife'), 'cat-eol', p.endOfLife, t('health.endOfLife.help'))),
      h('div', { class: 'fields-grid' }, field(t('health.verified'), 'cat-verified', p.verifiedIntakeKcal ?? '', { numeric: true, maxDecimals: 2, required: false, unit: t('unit.kcalPerDay'), help: t('health.verified.help') }))),
  );

  // ---- Meals ----
  const addMeal = button(t('meal.add'), () => {
    if (!foodChoices[0]) { error.textContent = t('meal.noFood'); return; }
    if (meals.children.length >= 24) { error.textContent = t('meal.max'); return; }
    meals.append(mealRow({ id: newId('meal'), label: t('meal.new'), foodId: foodChoices[0][0], grams: 0 })); dirty(); update();
  }, 'button subtle');
  form.append(h('section', { class: 'section sticker' }, h('div', { class: 'section-heading' }, h('h2', null, t('meal.title')), addMeal),
      h('p', { class: 'caption' }, t('meal.help')), meals),
    h('section', { class: 'section sticker' }, h('h2', null, t('balance.title')),
      selectField(t('balance.food'), 'cat-balance', cat.balanceFoodId, foodChoices),
      h('p', { class: 'caption' }, t('balance.help'))));

  // ---- Weight log ----
  const logTable = h('div'); const chartBox = h('div'); const trendBox = h('div', { class: 'trend', 'aria-live': 'polite' });
  const logError = h('p', { class: 'form-error', role: 'alert' });
  const logBcs = selectField(t('log.bcs'), 'log-bcs', '', integerChoices(9, t('log.bcsNone')));
  const logDate = field(t('log.date'), 'log-date', asOf, { type: 'date', required: false });
  const logWeight = field(t('log.weight'), 'log-weight', '', { numeric: true, maxDecimals: 3, required: false, unit: 'kg' });
  logDate.querySelector('input')!.max = asOf;
  function addEntry(): void {
    try {
      const date = formText(form, 'log-date'); const weightKg = decimal(formText(form, 'log-weight'), t('log.weight'), 3);
      if (!date) throw new Error(t('log.dateRequired'));
      if (daysBetween(date, asOf) < 0) throw new Error(t('log.dateFuture'));
      if (weightKg < 0.1 || weightKg > 40) throw new Error(t('log.weightRange'));
      // One weigh-in per day: an entry on the same date is replaced, after asking.
      const others = log.filter(e => e.date !== date);
      if (others.length < log.length && !confirm(t('log.replaceConfirm', { date: dateText(date) }))) return;
      if (others.length >= 1000) throw new Error(t('log.max'));
      const bcsText = formText(form, 'log-bcs'); const bcs = bcsText ? Number(bcsText) : null;
      log = [...others, { id: newId('weigh'), date, weightKg, bcs }];
      // Only a weigh-in dated on or after every other entry is the current one (ENGINE.md "Current weight"); an older entry never changes the profile.
      if (others.every(e => e.date <= date)) {
        setValue(form, 'cat-weight', inputNumber(weightKg));
        // The newest assessment also becomes the profile BCS (ENGINE.md §3.2 effective BCS).
        if (bcs !== null) setValue(form, 'cat-bcs', String(bcs));
      }
      setValue(form, 'log-weight', ''); setValue(form, 'log-bcs', '');
      logError.textContent = ''; dirty(); renderLog(); update();
    } catch (err) { logError.textContent = errorText(err); }
  }
  logWeight.querySelector('input')!.addEventListener('keydown', event => { if (event.key === 'Enter') { event.preventDefault(); addEntry(); } });
  function renderLog(): void {
    const sorted = [...log].sort((a, b) => a.date < b.date ? 1 : a.date > b.date ? -1 : a.id < b.id ? 1 : -1);
    fill(logTable, sorted.length ? table([t('log.date'), t('log.weight'), t('log.bcs'), ''], sorted.map(e => [dateText(e.date), `${num(e.weightKg, 2)} kg`,
      e.bcs === null ? t('log.bcsNone') : String(e.bcs),
      button(t('ui.remove'), () => { log = log.filter(x => x.id !== e.id); dirty(); renderLog(); update(); }, 'button subtle')]), t('log.title'))
      : h('p', { class: 'caption' }, t('log.empty')));
    const ideal = optionalIdeal();
    fill(chartBox, weightChart(log.filter(e => daysBetween(e.date, asOf) >= 0), ideal));
  }
  function optionalIdeal(): number | null { try { return optionalNumber(form, 'cat-ideal', t('weights.ideal'), 3); } catch { return null; } }
  form.append(h('section', { class: 'section sticker', id: 'weight-log' }, h('h2', null, t('log.title')), h('p', { class: 'caption' }, t('log.help')),
    h('fieldset', { class: 'log-add' }, h('legend', null, t('log.addLegend')), h('div', { class: 'fields-grid log-fields' }, logDate, logWeight, logBcs),
      button(t('log.add'), addEntry, 'button')), logError, chartBox, trendBox, logTable,
    h('div', { class: 'advice' }, h('h3', null, t('advice.title')), h('ul', null, h('li', null, t('advice.oneChange')), h('li', null, t('advice.secondPlateau'))))));

  form.append(error, h('div', { class: 'form-actions sticky-actions' }, h('button', { class: 'button primary', type: 'submit' }, t('cat.save')),
    button(t('cat.discard'), () => {
      if (!confirm(t('cat.discardConfirm'))) return;
      form.dataset.dirty = 'false';
      // After a change in another tab, discarding means showing that saved version, not the stale in-memory plan.
      if (ctx.store.notice === 'external-conflict') ctx.store.reload();
      ctx.render();
    }, 'button'),
    button(t('cat.remove'), () => {
      if (ctx.store.plan.cats.length <= 1) { error.textContent = t('cat.keepOne'); return; }
      if (confirm(t('cat.removeConfirm', { name: cat.name }))) {
        ctx.store.commit({ ...ctx.store.plan, cats: ctx.store.plan.cats.filter(c => c.id !== id) }); form.dataset.dirty = 'false'; ctx.navigate({ kind: 'household' });
      }
    }, 'button danger')));

  // ---- Reading the form ----
  function read(): Cat {
    const mode = formText(form, 'age-mode'), neutered = formText(form, 'cat-neutered') as Neutered, sex = formText(form, 'cat-sex') as Sex;
    const reproRelevant = sex !== 'male' && neutered !== 'yes';
    const status = (reproRelevant ? formText(form, 'repro-status') : 'none') as ReproductionStatus;
    const int = (name: string) => { const v = formText(form, name); return v ? Number(v) : null; };
    const ideal = optionalNumber(form, 'cat-ideal', t('weights.ideal'), 3);
    const profile: Profile = {
      birthDate: mode === 'birth' ? formText(form, 'cat-birth') || null : null,
      approxAgeYears: mode === 'approx' ? optionalNumber(form, 'cat-age-years', t('profile.approxAge'), 2) : null,
      sex, neutered, neuteredDate: neutered === 'yes' ? formText(form, 'cat-neutered-date') || null : null,
      lifestyle: (formText(form, 'cat-lifestyle') || null) as Lifestyle | null,
      bcs: int('cat-bcs'), mcs: (formText(form, 'cat-mcs') || null) as MuscleCondition | null,
      idealWeightKg: ideal,
      idealWeightSource: ideal === null ? null : (formText(form, 'cat-ideal-source') || 'veterinarian') as IdealWeightSource,
      expectedAdultWeightKg: optionalNumber(form, 'cat-adult-weight', t('weights.expectedAdult'), 3),
      reproduction: { status, litterSize: status === 'lactation' ? int('repro-litter') : null, lactationWeek: status === 'lactation' ? int('repro-week') : null,
        preBreedingWeightKg: status === 'gestation' ? optionalNumber(form, 'repro-preweight', t('repro.preWeight'), 3) : null },
      medical: readMedical(form, 'medical-'),
      endOfLife: form.querySelector<HTMLInputElement>('[name="cat-eol"]')!.checked,
      verifiedIntakeKcal: optionalNumber(form, 'cat-verified', t('health.verified'), 1),
    };
    return { ...cat, name: formText(form, 'cat-name'), icon: (formText(form, 'cat-icon') || null) as CatIcon | null, weightKg: formNumber(form, 'cat-weight', t('profile.weight'), 3),
      goal: formText(form, 'cat-goal') as Goal, targetKcal: formNumber(form, 'cat-target', t('target.kcal'), 1),
      targetSource: formText(form, 'cat-target-source') as TargetSource, extraKcal: formNumber(form, 'cat-extras', t('target.extras'), 1),
      balanceFoodId: formText(form, 'cat-balance'), profile, weightLog: log.map(e => ({ ...e })),
      meals: [...meals.querySelectorAll<HTMLElement>('[data-meal-id]')].map(row => {
        const mealId = row.dataset.mealId!;
        return { id: mealId, label: formText(form, `${mealId}-label`), foodId: formText(form, `${mealId}-food`), grams: formNumber(form, `${mealId}-grams`, t('meal.grams'), 1) };
      }),
    };
  }
  function candidate() { return { ...ctx.store.plan, cats: ctx.store.plan.cats.map(c => c.id === cat.id ? read() : c) }; }

  // ---- Live panel ----
  const estimateView = createEstimateView();
  const useNote = h('p', { class: 'caption', 'aria-live': 'polite' });
  const useButton = button(t('use.button'), () => useEstimate(), 'button primary');
  const nutritionBox = h('section', { class: 'panel-block nutrition' });
  const portionBox = h('section', { class: 'panel-block portions' });
  const panel = h('aside', { class: 'result-panel sticker', 'aria-label': t('panel.label') }, estimateView.element,
    h('div', { class: 'panel-block use-estimate' }, useButton, useNote), portionBox, nutritionBox);
  let current: { cat: Cat; result: CatResult } | null = null;

  /** The veterinarian's target is protected whether it is saved or only in the draft (a draft edit must not hide it). */
  function vetTarget(): boolean {
    const saved = ctx.store.plan.cats.find(c => c.id === id)?.targetSource ?? cat.targetSource;
    return saved === 'veterinarian' || formText(form, 'cat-target-source') === 'veterinarian';
  }
  function useEstimate(): void {
    const e = current?.result.estimate; if (!e || e.startKcal === null || !current) return;
    const kcal = Math.round(e.startKcal);
    const vet = vetTarget();
    // With the weight-loss equation on a BCS-estimated ideal weight, that ideal weight is stored too (source: estimate).
    const storeIbw = e.equation === 'weight-loss-aaha' && e.idealWeight?.source === 'bcs-estimate' ? Math.round(e.idealWeight.kg * 100) / 100 : null;
    const text = (vet ? t('use.confirmVet', { kcal: num(kcal, 0) }) : t('use.confirm', { kcal: num(kcal, 0) }))
      + (storeIbw === null ? '' : `\n\n${t('use.confirmIbw', { kg: num(storeIbw, 2) })}`);
    if (!confirm(text)) return;
    setValue(form, 'cat-target', String(kcal)); setValue(form, 'cat-target-source', 'provisional');
    if (storeIbw !== null) { setValue(form, 'cat-ideal', inputNumber(storeIbw)); setValue(form, 'cat-ideal-source', 'estimate'); renderLog(); }
    dirty();
    useNote.textContent = t('use.applied', { kcal: num(kcal, 0) }); update();
  }
  function applySuggestion(): void {
    const s = current?.result.trend.suggestion; if (!s || !current) return;
    const vet = vetTarget();
    const kcal = s.suggestedKcal === null ? null : Math.round(s.suggestedKcal);
    const what = s.action === 'switch-to-maintenance'
      ? kcal === null ? t('suggest.toMaintainOnly') : t('suggest.toMaintain', { kcal: num(kcal, 0) })
      : t('suggest.newTarget', { kcal: num(kcal ?? 0, 0) });
    if (!confirm(`${what}\n\n${vet ? t('suggest.confirmVet') : t('suggest.confirm')}`)) return;
    if (s.action === 'switch-to-maintenance') setValue(form, 'cat-goal', 'maintain');
    if (kcal !== null) { setValue(form, 'cat-target', String(kcal)); setValue(form, 'cat-target-source', 'provisional'); }
    dirty(); useNote.textContent = t('use.appliedSuggestion'); update();
  }

  function renderTrend(result: CatResult): void {
    const tr = result.trend, s = tr.suggestion;
    const latest = [...log].filter(e => daysBetween(e.date, asOf) >= 0).sort((a, b) => a.date < b.date ? -1 : 1).at(-1);
    const due = latest ? tr.nextWeighInDays - daysBetween(latest.date, asOf) : null;
    const applicable = s !== null && ((s.action === 'increase' || s.action === 'decrease') && s.suggestedKcal !== null || s.action === 'switch-to-maintenance');
    fill(trendBox, h('h3', null, t('trend.title')),
      h('dl', { class: 'stat-list' },
        h('dt', null, t('trend.rate')), h('dd', null, tr.ratePercentPerWeek === null ? t('trend.notEnough') : t('trend.ratePercent', { value: num(tr.ratePercentPerWeek, 2) })),
        h('dt', null, t('trend.change')), h('dd', null, tr.change28dPercent === null ? t('trend.notEnough') : t('trend.percent', { value: num(tr.change28dPercent, 1) })),
        h('dt', null, t('trend.cadence')), h('dd', null, t('trend.every', { days: String(tr.nextWeighInDays) })),
        h('dt', null, t('trend.next')), h('dd', { 'data-testid': 'next-weigh-in' }, due === null ? t('trend.nextNow') : due <= 0 ? t('trend.due') : t('trend.inDays', { days: String(due) }))),
      s ? h('div', { class: `suggestion action-${s.action}` }, h('p', null, h('strong', null, msg(`action.${s.action}`)), ' ', msg(`reason.${s.reason}`)),
        s.suggestedKcal !== null ? h('p', null, t('suggest.kcal', { kcal: num(s.suggestedKcal, 0) })) : null,
        applicable ? button(t('suggest.apply'), applySuggestion, 'button') : null)
        : h('p', { class: 'caption' }, result.estimate.status === 'ok' ? t('trend.noSuggestionData') : t('trend.noSuggestionStatus')));
  }
  function renderNutrition(result: CatResult): void {
    const n = result.nutrition;
    // Not applicable (no usable estimate): no nutrition check is shown.
    nutritionBox.hidden = n.status === 'not-applicable';
    if (n.status === 'not-applicable') { fill(nutritionBox); return; }
    if (n.status === 'incomplete-data') {
      const names = n.missingFoodIds.map(fid => ctx.store.plan.foods.find(f => f.id === fid)?.name ?? fid);
      fill(nutritionBox, h('h3', null, t('nutrition.title')), h('p', { class: 'caption' }, msg('nutrition.incomplete-data')),
        names.length ? h('p', { class: 'caption' }, t('nutrition.missing', { foods: names.join(', ') })) : null); return;
    }
    fill(nutritionBox, h('h3', null, t('nutrition.title')), h('dl', { class: 'stat-list' },
      h('dt', null, t('nutrition.protein')), h('dd', null, t('nutrition.proteinValue', { value: num(n.proteinPer1000, 0), min: num(n.minProteinPer1000, 0) })),
      h('dt', null, t('nutrition.proteinDay')), h('dd', null, `${num(n.proteinG, 1)} g`),
      h('dt', null, t('nutrition.carb')), h('dd', null, `${num(n.carbPercentME, 1)} %`)),
      n.warnings.length ? h('div', null, ...n.warnings.map(code => notice(msg(`nutrition.${code}`), 'warning'))) : h('p', { class: 'caption' }, msg('nutrition.ok')),
      ...n.notes.map(code => notice(msg(`nutrition.${code}`), 'note')));
  }
  function renderPortions(c: Cat, r: CatResult): void {
    const balance = ctx.store.plan.foods.find(f => f.id === c.balanceFoodId)?.name ?? '';
    // A referral shows grams only: no kcal figure is derived for a cat that needs a veterinarian first (parity with the Mac app).
    const refer = r.estimate.status === 'refer';
    fill(portionBox, h('h3', null, t('portions.title')),
      h('div', { class: 'portion-figure' }, h('span', { class: 'figure-number', 'data-testid': 'cat-preview-dry' }, String(r.balanceGramsRounded), h('span', { class: 'unit' }, ' g')),
        h('span', { class: 'figure-label' }, t('portions.balanceOf', { food: balance }))),
      h('p', { class: 'caption' }, t('portions.exact', { grams: num(r.balanceGramsExact, 2) })),
      refer ? h('dl', { class: 'stat-list' }, h('dt', null, t('portions.fixed')), h('dd', null, `${num(r.fixedGrams, 0)} g`))
        : h('dl', { class: 'stat-list' }, h('dt', null, t('portions.fixed')), h('dd', null, `${num(r.fixedGrams, 0)} g, ${num(r.fixedKcal, 0)} kcal`),
          h('dt', null, t('portions.extras')), h('dd', null, `${num(r.extraKcal, 0)} kcal`),
          h('dt', null, t('portions.balanceKcal')), h('dd', null, `${num(r.balanceKcal, 0)} kcal`),
          h('dt', null, t('portions.rounded')), h('dd', null, `${num(r.roundedDailyKcal, 0)} ${t('unit.kcalPerDay')}`)),
      r.overBudgetKcal > 0 && !refer ? notice(t('portions.over', { kcal: num(r.overBudgetKcal, 0) }), 'error') : null,
      r.warnings.length ? h('div', { class: 'mini-warnings' }, ...r.warnings.map(code => h('p', null, msg(`warning.${code}`)))) : null);
  }
  function sync(): void {
    const mode = formText(form, 'age-mode'), sex = formText(form, 'cat-sex'), neutered = formText(form, 'cat-neutered');
    birthField.hidden = mode !== 'birth'; approxField.hidden = mode !== 'approx';
    neuterDate.hidden = neutered !== 'yes';
    reproSection.hidden = sex === 'male' || neutered === 'yes';
    idealSource.hidden = formText(form, 'cat-ideal') === '';
    reestimate.hidden = idealSource.hidden || formText(form, 'cat-ideal-source') !== 'estimate';
    const status = formText(form, 'repro-status');
    litter.hidden = status !== 'lactation'; week.hidden = status !== 'lactation'; preWeight.hidden = status !== 'gestation';
    adultWeight.hidden = lastStage !== 'kitten';
  }
  function update(): void {
    try {
      const plan = candidate(); const result = calculatePlan(plan, { asOf }).cats.find(c => c.id === id)!;
      const c = plan.cats.find(x => x.id === id)!;
      current = { cat: c, result }; lastStage = result.estimate.stage;
      panel.classList.remove('stale');
      estimateView.update(c, result, asOf);
      // Only an ok estimate is offered as a target; reference-only figures stay with the veterinarian (parity with the Mac app).
      const e = result.estimate, usable = e.status === 'ok' && e.startKcal !== null;
      useButton.disabled = !usable;
      useButton.textContent = usable ? t('use.buttonKcal', { kcal: num(Math.round(e.startKcal!), 0) }) : t('use.button');
      useButton.title = usable ? '' : t('use.disabled');
      renderPortions(c, result); renderNutrition(result); renderTrend(result);
    } catch (err) {
      // Invalid input: no result from an earlier valid state may stay visible or be applied.
      current = null; panel.classList.add('stale'); estimateView.clear();
      useButton.disabled = true; useButton.textContent = t('use.button'); useButton.title = t('use.invalid'); useNote.textContent = '';
      fill(portionBox, h('h3', null, t('portions.title')), notice(t('panel.invalid', { detail: errorText(err) }), 'warning'));
      nutritionBox.hidden = true; fill(nutritionBox); fill(trendBox);
    }
    sync();
  }
  renderLog();
  markDirty(form);
  form.addEventListener('input', update); form.addEventListener('change', update);
  form.querySelector('[name="cat-ideal"]')!.addEventListener('change', renderLog);
  form.addEventListener('submit', event => {
    event.preventDefault();
    try {
      const persisted = ctx.store.commit(candidate()); form.dataset.dirty = 'false';
      // Not persisted (recovery mode or a failed write): the store notice explains it instead of a "saved" flash.
      if (persisted) ctx.notify(t('cat.saved', { name: formText(form, 'cat-name') }), 'success');
      ctx.render();
    }
    catch (err) { error.textContent = errorText(err); }
  });
  update();
  const firstResult = current as { cat: Cat; result: CatResult } | null;
  const stage = firstResult?.result.estimate.stage ?? null;
  return h('div', null, h('header', { class: 'page-heading cat-heading' }, avatar(cat.id, 56, cat.icon),
    h('div', null, h('h1', null, cat.name), h('ul', { class: 'meta-chips', 'aria-label': t('cat.summary') },
      h('li', null, chip(`${num(cat.weightKg, 2)} kg`)), h('li', null, chip(goalLabel(cat.goal))),
      stage ? h('li', null, chip(msg(`stage.${stage}`))) : null))),
    h('div', { class: 'editor-grid' }, panel, form));
}

export function defaultBalanceFood(ctx: AppContext): string | undefined {
  return (ctx.store.plan.foods.find(f => f.type === 'dry') ?? ctx.store.plan.foods[0])?.id;
}
/** Quick add: name, weight and an explicit target only. */
export function addCatDialog(ctx: AppContext): void {
  const dialog = h('dialog', { class: 'modal', 'aria-labelledby': 'quick-add-title' }); const form = h('form'); const error = h('p', { class: 'form-error', role: 'alert' });
  const close = () => { dialog.close(); dialog.remove(); };
  dialog.addEventListener('cancel', close);
  form.append(h('h2', { id: 'quick-add-title' }, t('quick.title')), h('p', { class: 'caption' }, t('quick.help')),
    field(t('profile.name'), 'new-cat-name', ''), field(t('profile.weight'), 'new-cat-weight', '', { numeric: true, maxDecimals: 3, unit: 'kg' }),
    field(t('target.kcal'), 'new-cat-target', '', { numeric: true, maxDecimals: 2, unit: t('unit.kcalPerDay') }), error,
    h('div', { class: 'form-actions' }, button(t('ui.cancel'), close), h('button', { type: 'submit', class: 'button primary' }, t('quick.create'))));
  form.addEventListener('submit', event => { event.preventDefault(); try {
    const balance = defaultBalanceFood(ctx); if (!balance) throw new Error(t('meal.noFood'));
    const cat: Cat = { id: newId('cat'), name: formText(form, 'new-cat-name'), icon: null, weightKg: formNumber(form, 'new-cat-weight', t('profile.weight'), 3),
      targetKcal: formNumber(form, 'new-cat-target', t('target.kcal'), 1), goal: 'maintain', targetSource: 'owner', extraKcal: 0, balanceFoodId: balance, meals: [], profile: defaultProfile(), weightLog: [] };
    ctx.store.commit({ ...ctx.store.plan, cats: [...ctx.store.plan.cats, cat] });
    document.querySelectorAll<HTMLFormElement>('form[data-dirty]').forEach(f => { f.dataset.dirty = 'false'; });
    close(); ctx.navigate({ kind: 'cat', id: cat.id });
  } catch (err) { error.textContent = errorText(err); } });
  dialog.append(form); document.body.append(dialog); dialog.showModal();
}
