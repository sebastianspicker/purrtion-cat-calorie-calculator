import { calculatePlan, defaultProfile, todayLocalISO, daysBetween, energyModel,
  type Cat, type CatIcon, type CatResult, type Goal, type Lifestyle, type MedicalFlag, type Neutered, type Plan, type ReproductionStatus, type Sex, type TargetSource } from '../../../packages/core/src/index.js';
import { h, fill, button, field, selectField, radioGroup, checkbox, decimal, errorText, newId, notice, formText } from './dom.js';
import { t, num, type UiKey } from './i18n.js';
import { avatar, catFace, type Expression } from './mascot.js';
import { createEstimateView } from './estimate.js';
import { bcsPicker, iconPicker, lifestyleChoices, medicalChecklist, readMedical, defaultBalanceFood } from './pages/cat.js';
import type { AppContext } from './context.js';

/** Answers collected by the guided setup. Nothing is saved until "Create". */
interface Answers {
  name: string; icon: CatIcon | null; sex: Sex;
  ageMode: 'birth' | 'approx' | 'unknown'; birthDate: string; years: string; months: string;
  weight: string; neutered: Neutered; lifestyle: '' | Lifestyle; bcs: string;
  expectedAdult: string; repro: ReproductionStatus; litter: string; week: string;
  medical: MedicalFlag[]; endOfLife: boolean; goal: Goal;
  balanceFoodId: string; mealFoodId: string; mealGrams: string;
  outcome: 'estimate' | 'own'; ownKcal: string; ownSource: TargetSource;
}
interface Step {
  id: string; title: UiKey; bubble: UiKey; expression: Expression;
  skip?: (a: Answers) => boolean;
  render: (a: Answers) => HTMLElement;
  /** Copies the controls into the answers; throws a user-facing error when the step is incomplete. */
  read: (root: HTMLElement, a: Answers) => void;
}
const KITTEN_NEUTER_SKIP_MONTHS = 6;
function ageMonths(a: Answers, asOf: string): number | null {
  if (a.ageMode === 'birth' && a.birthDate) { const days = daysBetween(a.birthDate, asOf); return days < 0 ? null : days / energyModel.units.daysPerMonth; }
  if (a.ageMode === 'approx' && (a.years || a.months)) {
    // Unvalidated text (a step revisited with partial answers) simply gives no age.
    try { return (a.years ? wholeNumber(a.years, '', 0, 30) : 0) * 12 + (a.months ? wholeNumber(a.months, '', 0, 11) : 0); } catch { return null; }
  }
  return null;
}
const isKitten = (a: Answers, asOf: string) => { const months = ageMonths(a, asOf); return months !== null && months < energyModel.age.kittenMaxMonths; };
const reproRelevant = (a: Answers, asOf: string) => a.sex === 'female' && a.neutered !== 'yes' && !isKitten(a, asOf);
function allowedGoals(a: Answers, asOf: string): Goal[] {
  if (isKitten(a, asOf) || a.repro !== 'none' || !a.bcs) return ['maintain'];
  const bcs = Number(a.bcs);
  return bcs >= energyModel.bcs.overweightMin ? ['loss', 'maintain'] : bcs === energyModel.bcs.gainOnly ? ['gain', 'maintain'] : ['maintain'];
}
function wholeNumber(text: string, label: string, min: number, max: number): number {
  const value = decimal(text, label, 3);
  if (!Number.isInteger(value) || value < min || value > max) throw new Error(t('wizard.range', { label, min: String(min), max: String(max) }));
  return value;
}

export function openWizard(ctx: AppContext): void {
  const asOf = todayLocalISO();
  const plan = ctx.store.plan;
  const a: Answers = { name: '', icon: null, sex: 'unknown', ageMode: 'birth', birthDate: '', years: '', months: '', weight: '', neutered: 'unknown',
    lifestyle: '', bcs: '', expectedAdult: '', repro: 'none', litter: '', week: '', medical: [], endOfLife: false, goal: 'maintain',
    balanceFoodId: defaultBalanceFood(ctx) ?? '', mealFoodId: '', mealGrams: '', outcome: 'estimate', ownKcal: '', ownSource: 'owner' };
  let touched = false;
  const foodChoices = plan.foods.map(f => [f.id, f.name] as const);

  const steps: Step[] = [
    { id: 'name', title: 'wizard.name.title', bubble: 'wizard.name.bubble', expression: 'happy',
      render: () => h('div', null, field(t('profile.name'), 'wiz-name', a.name, { required: false }),
        radioGroup(t('profile.sex'), 'wiz-sex', a.sex, [['female', t('sex.female')], ['male', t('sex.male')], ['unknown', t('sex.unknown')]], 'segmented')),
      read: root => {
        a.name = formText(root, 'wiz-name'); a.sex = (formText(root, 'wiz-sex') || 'unknown') as Sex;
        if (!a.name) throw new Error(t('wizard.name.required'));
        if (a.name.length > 120) throw new Error(t('wizard.name.long'));
      } },
    { id: 'icon', title: 'wizard.icon.title', bubble: 'wizard.icon.bubble', expression: 'happy',
      render: () => h('div', null, iconPicker('wiz-icon', a.icon), h('p', { class: 'caption' }, t('wizard.icon.help'))),
      read: root => { a.icon = (formText(root, 'wiz-icon') || null) as CatIcon | null; } },
    { id: 'age', title: 'wizard.age.title', bubble: 'wizard.age.bubble', expression: 'curious',
      render: () => {
        const birth = field(t('profile.birthDate'), 'wiz-birth', a.birthDate, { type: 'date', required: false });
        const approx = h('div', { class: 'fields-grid' }, field(t('wizard.age.years'), 'wiz-years', a.years, { numeric: true, maxDecimals: 0, required: false, unit: t('unit.years') }),
          field(t('wizard.age.months'), 'wiz-months', a.months, { numeric: true, maxDecimals: 0, required: false, unit: t('unit.months') }));
        const group = radioGroup(t('profile.ageMode'), 'wiz-age-mode', a.ageMode, [['birth', t('profile.ageMode.birth')], ['approx', t('profile.ageMode.approx')], ['unknown', t('profile.ageMode.unknown')]], 'segmented');
        const box = h('div', null, group, birth, approx);
        const sync = () => { const mode = formText(box, 'wiz-age-mode'); birth.hidden = mode !== 'birth'; approx.hidden = mode !== 'approx'; };
        group.addEventListener('change', sync); sync(); return box;
      },
      read: root => {
        a.ageMode = (formText(root, 'wiz-age-mode') || 'unknown') as Answers['ageMode'];
        a.birthDate = formText(root, 'wiz-birth'); a.years = formText(root, 'wiz-years'); a.months = formText(root, 'wiz-months');
        if (a.ageMode === 'birth') {
          if (!a.birthDate) throw new Error(t('wizard.age.birthRequired'));
          if (daysBetween(a.birthDate, asOf) < 0) throw new Error(t('wizard.age.future'));
        }
        if (a.ageMode === 'approx') {
          if (!a.years && !a.months) throw new Error(t('wizard.age.approxRequired'));
          if (a.years) wholeNumber(a.years, t('wizard.age.years'), 0, 30);
          if (a.months) wholeNumber(a.months, t('wizard.age.months'), 0, 11);
        }
      } },
    { id: 'weight', title: 'wizard.weight.title', bubble: 'wizard.weight.bubble', expression: 'thinking',
      render: () => h('div', null, field(t('profile.weight'), 'wiz-weight', a.weight, { numeric: true, maxDecimals: 3, required: false, unit: 'kg' }),
        notice(t('wizard.weight.tip'), 'note', t('wizard.weight.tipTitle'))),
      read: root => {
        a.weight = formText(root, 'wiz-weight');
        const kg = decimal(a.weight, t('profile.weight'), 3);
        if (kg < 0.1 || kg > 40) throw new Error(t('log.weightRange'));
      } },
    { id: 'neutered', title: 'wizard.neutered.title', bubble: 'wizard.neutered.bubble', expression: 'curious',
      skip: x => { const months = ageMonths(x, asOf); return months !== null && months < KITTEN_NEUTER_SKIP_MONTHS && x.neutered === 'unknown'; },
      render: () => radioGroup(t('profile.neutered'), 'wiz-neutered', a.neutered, [['yes', t('neutered.yes')], ['no', t('neutered.no')], ['unknown', t('wizard.notSure')]]),
      read: root => { a.neutered = (formText(root, 'wiz-neutered') || 'unknown') as Neutered; } },
    { id: 'lifestyle', title: 'wizard.lifestyle.title', bubble: 'wizard.lifestyle.bubble', expression: 'happy',
      render: () => radioGroup(t('lifestyle.legend'), 'wiz-lifestyle', a.lifestyle, lifestyleChoices()),
      read: root => { a.lifestyle = formText(root, 'wiz-lifestyle') as Answers['lifestyle']; } },
    { id: 'bcs', title: 'wizard.bcs.title', bubble: 'wizard.bcs.bubble', expression: 'thinking',
      render: () => h('div', null, bcsPicker('wiz-bcs', a.bcs ? Number(a.bcs) : null), h('p', { class: 'caption' }, t('wizard.bcs.help'))),
      read: root => { a.bcs = formText(root, 'wiz-bcs'); } },
    { id: 'stage', title: 'wizard.stage.title', bubble: 'wizard.stage.bubble', expression: 'curious',
      skip: x => !isKitten(x, asOf) && !reproRelevant(x, asOf),
      render: () => {
        const box = h('div');
        if (isKitten(a, asOf)) box.append(field(t('weights.expectedAdult'), 'wiz-adult', a.expectedAdult, { numeric: true, maxDecimals: 3, required: false, unit: 'kg', help: t('weights.expectedAdult.help') }));
        if (reproRelevant(a, asOf)) {
          const litter = field(t('repro.litter'), 'wiz-litter', a.litter, { numeric: true, maxDecimals: 0, required: false });
          const week = field(t('repro.week'), 'wiz-week', a.week, { numeric: true, maxDecimals: 0, required: false });
          const group = radioGroup(t('repro.status'), 'wiz-repro', a.repro, [['none', t('repro.none')], ['gestation', t('repro.gestation')], ['lactation', t('repro.lactation')]]);
          const extra = h('div', { class: 'fields-grid' }, litter, week);
          const sync = () => { extra.hidden = formText(box, 'wiz-repro') !== 'lactation'; };
          group.addEventListener('change', sync); box.append(group, extra); sync();
        }
        return box;
      },
      read: root => {
        a.expectedAdult = formText(root, 'wiz-adult');
        if (a.expectedAdult) { const kg = decimal(a.expectedAdult, t('weights.expectedAdult'), 3); if (kg < 0.1 || kg > 40) throw new Error(t('log.weightRange')); }
        a.repro = (formText(root, 'wiz-repro') || 'none') as ReproductionStatus;
        a.litter = formText(root, 'wiz-litter'); a.week = formText(root, 'wiz-week');
        if (a.repro === 'lactation') {
          if (a.litter) wholeNumber(a.litter, t('repro.litter'), 1, 12);
          if (a.week) wholeNumber(a.week, t('repro.week'), 1, 12);
        }
      } },
    { id: 'health', title: 'wizard.health.title', bubble: 'wizard.health.bubble', expression: 'thinking',
      render: () => h('div', null, medicalChecklist('wiz-medical-', a.medical),
        h('fieldset', { class: 'checklist' }, h('legend', null, t('health.other')), checkbox(t('health.endOfLife'), 'wiz-eol', a.endOfLife, t('health.endOfLife.help')))),
      read: root => { a.medical = readMedical(root, 'wiz-medical-'); a.endOfLife = root.querySelector<HTMLInputElement>('[name="wiz-eol"]')!.checked; } },
    { id: 'goal', title: 'wizard.goal.title', bubble: 'wizard.goal.bubble', expression: 'happy',
      render: () => {
        const goals = allowedGoals(a, asOf);
        if (!goals.includes(a.goal)) a.goal = 'maintain';
        const why = isKitten(a, asOf) ? t('wizard.goal.kitten') : a.repro !== 'none' ? t('wizard.goal.repro') : !a.bcs ? t('wizard.goal.noBcs')
          : goals.length === 1 ? t('wizard.goal.ideal') : goals.includes('loss') ? t('wizard.goal.over') : t('wizard.goal.under');
        return h('div', null, radioGroup(t('profile.goal'), 'wiz-goal', a.goal, goals.map(g => [g, t(`goal.${g}`), t(`wizard.goal.${g}.help`)] as [string, string, string])),
          h('p', { class: 'caption' }, why));
      },
      read: root => { a.goal = (formText(root, 'wiz-goal') || 'maintain') as Goal; } },
    { id: 'foods', title: 'wizard.foods.title', bubble: 'wizard.foods.bubble', expression: 'curious',
      render: () => {
        const grams = field(t('meal.grams'), 'wiz-meal-grams', a.mealGrams, { numeric: true, maxDecimals: 2, required: false, unit: 'g' });
        const meal = selectField(t('wizard.foods.meal'), 'wiz-meal-food', a.mealFoodId, [['', t('wizard.foods.noMeal')], ...foodChoices]);
        const box = h('div', null, selectField(t('balance.food'), 'wiz-balance', a.balanceFoodId, foodChoices, t('wizard.foods.balanceHelp')),
          h('div', { class: 'fields-grid' }, meal, grams));
        const sync = () => { grams.hidden = !formText(box, 'wiz-meal-food'); };
        meal.addEventListener('change', sync); sync(); return box;
      },
      read: root => {
        a.balanceFoodId = formText(root, 'wiz-balance'); a.mealFoodId = formText(root, 'wiz-meal-food'); a.mealGrams = formText(root, 'wiz-meal-grams');
        if (!a.balanceFoodId) throw new Error(t('meal.noFood'));
        if (a.mealFoodId) { const g = decimal(a.mealGrams, t('meal.grams'), 1); if (g < 0 || g > 1000) throw new Error(t('wizard.foods.gramsRange')); }
      } },
    { id: 'summary', title: 'wizard.summary.title', bubble: 'wizard.summary.bubble', expression: 'happy',
      render: () => summary(), read: root => readOutcome(root) },
  ];

  function buildCat(targetKcal: number, targetSource: TargetSource): Cat {
    const months = ageMonths(a, asOf);
    const profile = { ...defaultProfile(), sex: a.sex, neutered: a.neutered,
      birthDate: a.ageMode === 'birth' && a.birthDate ? a.birthDate : null,
      approxAgeYears: a.ageMode === 'approx' && months !== null ? Math.round(months / 12 * 100) / 100 : null,
      lifestyle: a.lifestyle || null, bcs: a.bcs ? Number(a.bcs) : null,
      expectedAdultWeightKg: isKitten(a, asOf) && a.expectedAdult ? decimal(a.expectedAdult, t('weights.expectedAdult'), 3) : null,
      reproduction: { status: reproRelevant(a, asOf) ? a.repro : 'none' as ReproductionStatus,
        litterSize: a.repro === 'lactation' && a.litter ? wholeNumber(a.litter, t('repro.litter'), 1, 12) : null,
        lactationWeek: a.repro === 'lactation' && a.week ? wholeNumber(a.week, t('repro.week'), 1, 12) : null, preBreedingWeightKg: null },
      medical: [...a.medical], endOfLife: a.endOfLife };
    return { id: catId, name: a.name, icon: a.icon, weightKg: decimal(a.weight, t('profile.weight'), 3), goal: a.goal, targetKcal, targetSource, extraKcal: 0,
      balanceFoodId: a.balanceFoodId, profile, weightLog: [],
      meals: a.mealFoodId ? [{ id: newId('meal'), label: t('wizard.foods.mealLabel'), foodId: a.mealFoodId, grams: decimal(a.mealGrams, t('meal.grams'), 1) }] : [] };
  }
  const catId = newId('cat');
  const candidate = (cat: Cat): Plan => ({ ...plan, cats: [...plan.cats, cat] });
  function compute(targetKcal: number, source: TargetSource): { cat: Cat; result: CatResult } {
    const cat = buildCat(targetKcal, source);
    return { cat, result: calculatePlan(candidate(cat), { asOf }).cats.find(c => c.id === catId)! };
  }
  /** The estimate does not depend on the target; a placeholder target is used to obtain it. */
  const probe = () => compute(Math.round(energyModel.mer.typical), 'provisional');
  // Only an ok estimate is offered as the starting target (parity with the Mac app).
  const usableStart = (r: CatResult) => r.estimate.status === 'ok' && r.estimate.startKcal !== null
    ? Math.round(r.estimate.startKcal) : null;
  function chosenTarget(start: number | null): { kcal: number; source: TargetSource } | null {
    if (a.outcome === 'estimate' && start !== null) return { kcal: start, source: 'provisional' };
    if (a.outcome === 'own' && a.ownKcal) { const kcal = decimal(a.ownKcal, t('target.kcal'), 1); if (kcal >= 1 && kcal <= 3000) return { kcal, source: a.ownSource }; }
    return null;
  }
  function summary(): HTMLElement {
    const { cat, result } = probe();
    const start = usableStart(result);
    if (start === null) a.outcome = 'own';
    const view = createEstimateView({ why: false, comparison: false }); view.update(cat, result, asOf);
    const portions = h('div', { class: 'wizard-portions', 'aria-live': 'polite' });
    const own = h('div', { class: 'fields-grid' }, field(t('target.kcal'), 'wiz-own-kcal', a.ownKcal, { numeric: true, maxDecimals: 2, required: false, unit: t('unit.kcalPerDay') }),
      selectField(t('wizard.outcome.source'), 'wiz-own-source', a.ownSource === 'veterinarian' ? 'veterinarian' : 'owner',
        [['owner', t('wizard.outcome.owner')], ['veterinarian', t('wizard.outcome.vet')]]));
    const choices: [string, string, string?][] = [];
    if (start !== null) choices.push(['estimate', t('wizard.outcome.use', { kcal: num(start, 0) }), t('wizard.outcome.useHelp')]);
    choices.push(start === null ? ['own', t('wizard.outcome.own'), t('wizard.outcome.ownOnly')] : ['own', t('wizard.outcome.own')]);
    const group = radioGroup(t('wizard.outcome.legend'), 'wiz-outcome', a.outcome, choices);
    const box = h('div', { class: 'wizard-summary' }, h('div', { class: 'summary-cat' }, avatar(catId, 48, a.icon), h('strong', null, a.name)), view.element, group, own, portions);
    const refresh = () => {
      a.outcome = (formText(box, 'wiz-outcome') || 'own') as Answers['outcome'];
      a.ownKcal = formText(box, 'wiz-own-kcal'); a.ownSource = formText(box, 'wiz-own-source') as TargetSource;
      own.hidden = a.outcome !== 'own';
      let target: ReturnType<typeof chosenTarget> = null;
      try { target = chosenTarget(start); } catch { target = null; }
      if (!target) { fill(portions, h('p', { class: 'caption' }, t('wizard.outcome.needTarget'))); return; }
      const final = compute(target.kcal, target.source).result;
      const balance = plan.foods.find(f => f.id === a.balanceFoodId)?.name ?? '';
      fill(portions, h('h3', null, t('portions.title')),
        h('div', { class: 'portion-figure' }, h('span', { class: 'figure-number', 'data-testid': 'wizard-portion' }, String(final.balanceGramsRounded), h('span', { class: 'unit' }, ' g')),
          h('span', { class: 'figure-label' }, t('portions.balanceOf', { food: balance }))),
        final.fixedGrams > 0 ? h('p', { class: 'caption' }, t('wizard.outcome.fixed', { grams: num(final.fixedGrams, 0), kcal: num(final.fixedKcal, 0) })) : null,
        final.overBudgetKcal > 0 ? notice(t('portions.over', { kcal: num(final.overBudgetKcal, 0) }), 'error') : null);
    };
    box.addEventListener('input', refresh); box.addEventListener('change', refresh); refresh();
    serious = result.estimate.status === 'refer';
    return box;
  }
  function readOutcome(root: HTMLElement): void {
    a.outcome = (formText(root, 'wiz-outcome') || 'own') as Answers['outcome'];
    a.ownKcal = formText(root, 'wiz-own-kcal'); a.ownSource = formText(root, 'wiz-own-source') as TargetSource;
    const start = usableStart(probe().result);
    if (a.outcome === 'own') {
      if (!a.ownKcal) throw new Error(t('wizard.outcome.kcalRange'));
      const kcal = decimal(a.ownKcal, t('target.kcal'), 1);
      if (kcal < 1 || kcal > 3000) throw new Error(t('wizard.outcome.kcalRange'));
    } else if (start === null) throw new Error(t('wizard.outcome.ownOnly'));
  }

  // ---- Dialog shell ----
  let index = 0, serious = false;
  const dialog = h('dialog', { class: 'modal wizard', 'aria-labelledby': 'wizard-title' });
  const progress = h('p', { class: 'wizard-progress' });
  const title = h('h2', { id: 'wizard-title', tabindex: '-1' });
  const guide = h('div', { class: 'guide' });
  const content = h('form', { class: 'wizard-step', novalidate: true });
  const error = h('p', { class: 'form-error', role: 'alert' });
  const back = button(t('wizard.back'), () => go(-1), 'button');
  const next = h('button', { type: 'submit', class: 'button primary' });
  const cancel = button(t('ui.cancel'), () => tryClose(), 'button subtle');
  content.addEventListener('submit', event => { event.preventDefault(); go(1); });
  content.addEventListener('input', () => { touched = true; });
  const visible = () => steps.filter(step => !step.skip?.(a));
  function show(): void {
    const list = visible(); const step = list[index]!;
    serious = false;
    // Rendering can throw (the summary computes a plan); it runs before anything on screen is replaced.
    const body = step.render(a);
    fill(content, body, error, h('div', { class: 'form-actions wizard-actions' }, cancel, index > 0 ? back : null, next));
    progress.textContent = t('wizard.progress', { n: String(index + 1), total: String(list.length) });
    title.textContent = t(step.title);
    next.textContent = step.id === 'summary' ? t('wizard.create') : t('wizard.next');
    error.textContent = '';
    // Serious states override cuteness: the guide steps aside on referral screens.
    fill(guide, ...(serious ? [] : [catFace({ hat: true, expression: step.expression, size: 76, label: t('wizard.guideName') }),
      h('p', { class: 'bubble' }, h('strong', null, t('wizard.guideName')), ' ', t(step.bubble))]));
    guide.hidden = serious;
    dialog.classList.toggle('serious', serious);
    title.focus();
  }
  function go(delta: number): void {
    const list = visible(); const step = list[index]!;
    if (delta > 0) {
      try { step.read(content, a); touched = true; } catch (err) { error.textContent = errorText(err); content.querySelector<HTMLElement>('input, select')?.focus(); return; }
      if (step.id === 'summary') { create(); return; }
    } else { try { step.read(content, a); } catch { /* going back keeps partial answers */ } }
    const id = step.id; const after = visible(); const position = after.findIndex(s => s.id === id);
    const previous = index, wasSerious = serious;
    try {
      index = Math.max(0, Math.min(after.length - 1, (position < 0 ? index : position) + delta));
      show();
    } catch (err) {
      // The new step could not be built: stay on the current one, which is still on screen, and say why.
      index = previous; serious = wasSerious; error.textContent = errorText(err);
    }
  }
  function create(): void {
    try {
      const start = usableStart(probe().result);
      const target = chosenTarget(start); if (!target) throw new Error(t('wizard.outcome.needTarget'));
      const cat = buildCat(target.kcal, target.source);
      ctx.store.commit(candidate(cat));
      close(); ctx.notify(t('wizard.created', { name: cat.name }), 'success'); ctx.navigate({ kind: 'cat', id: cat.id });
    } catch (err) { error.textContent = errorText(err); }
  }
  function close(): void { dialog.close(); dialog.remove(); }
  function tryClose(): void { if (!touched || confirm(t('wizard.cancelConfirm'))) close(); }
  dialog.addEventListener('cancel', event => { event.preventDefault(); tryClose(); });
  dialog.append(h('header', { class: 'wizard-head' }, progress, title), guide, content);
  document.body.append(dialog); dialog.showModal(); show();
}
