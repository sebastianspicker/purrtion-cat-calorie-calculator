import { parsePlanJSON, planToJSON, planToCSV, todayLocalISO, MAX_IMPORT_BYTES } from '../../../packages/core/src/index.js';
import { h, button, download, errorText, notice, type NoticeKind } from './dom.js';
import { PlanStore } from './store.js';
import { t, initLocale, setLocale, getLocale, type UiKey } from './i18n.js';
import type { Page, AppContext } from './context.js';
import { household } from './pages/household.js';
import { catPage, addCatDialog } from './pages/cat.js';
import { foodsPage } from './pages/foods.js';
import { methodPage } from './pages/method.js';
import { openWizard } from './wizard.js';
import { avatar, wizardHat } from './mascot.js';
import { s } from './dom.js';

const THEME_KEY = 'purrtion.theme';
type Theme = 'system' | 'light' | 'dark';
function savedTheme(): Theme {
  try { const v = localStorage.getItem(THEME_KEY); return v === 'light' || v === 'dark' ? v : 'system'; } catch { return 'system'; }
}
function applyTheme(theme: Theme): void {
  if (theme === 'system') document.documentElement.removeAttribute('data-theme');
  else document.documentElement.dataset.theme = theme;
}

async function boot(): Promise<void> {
  initLocale();
  applyTheme(savedTheme());
  const root = document.querySelector<HTMLElement>('#app')!;
  const response = await fetch(new URL('../../../shared/default-plan.json', import.meta.url));
  if (!response.ok) throw new Error(t('boot.sampleMissing'));
  const store = new PlanStore(parsePlanJSON(await response.text()));
  let page: Page = { kind: 'household' }; let appError = '';
  let flash: { text: string; kind: NoticeKind } | null = null;
  let hatOn = false; const brandClicks: number[] = [];
  const isDirty = () => Boolean(root.querySelector('form[data-dirty="true"]'));
  function canLeave(): boolean { return !isDirty() || confirm(t('app.discardConfirm')); }
  function navigate(next: Page): void { if (canLeave()) { page = next; render(); document.querySelector<HTMLElement>('#main-content')?.focus(); window.scrollTo(0, 0); } }
  const ctx: AppContext = { store, navigate, render, canLeave, notify: (text, kind = 'success') => { flash = { text, kind }; } };
  async function importFile(): Promise<void> {
    const input = h('input', { type: 'file', accept: '.json,application/json' });
    input.addEventListener('change', async () => {
      const file = input.files?.[0]; if (!file) return;
      try {
        if (file.size > MAX_IMPORT_BYTES) throw new Error(t('import.tooLarge'));
        const next = parsePlanJSON(await file.text());
        if (!confirm(t('import.confirm', { name: next.name, count: String(next.cats.length) }))) return;
        store.commit(next, true); page = { kind: 'household' }; appError = ''; render();
      } catch (error) {
        appError = errorText(error);
        // Report a rejected import without discarding unsaved editor fields.
        root.querySelector('#import-error')?.replaceChildren(notice(appError, 'error'));
      }
    }); input.click();
  }
  function nav(label: string | Node, target: Page, active: boolean, name?: string): HTMLElement {
    const b = h('button', { type: 'button', class: `nav-link ${active ? 'active' : ''}` }, label);
    if (name) b.setAttribute('aria-label', name);
    b.addEventListener('click', () => navigate(target));
    if (active) b.setAttribute('aria-current', 'page'); return b;
  }
  function brandMark(): HTMLElement {
    const mark = h('button', { type: 'button', class: `brand-mark ${hatOn ? 'with-hat' : ''}`, 'aria-label': t('brand.markLabel') },
      h('img', { src: './assets/purrtion-mark.svg', alt: '', width: 44, height: 44 }),
      hatOn ? s('svg', { class: 'brand-hat', viewBox: '0 -2 64 30', 'aria-hidden': 'true', focusable: 'false' }, wizardHat()) : null);
    // Easter egg: five clicks within three seconds put the wizard hat on and open the guided setup.
    mark.addEventListener('click', () => {
      const now = Date.now(); brandClicks.push(now);
      while (brandClicks.length && now - brandClicks[0]! > 3000) brandClicks.shift();
      if (brandClicks.length >= 5) { brandClicks.length = 0; if (canLeave()) { hatOn = true; render(); openWizard(ctx); } }
      else if (page.kind !== 'household' && brandClicks.length === 1) navigate({ kind: 'household' });
    });
    return mark;
  }
  function render(): void {
    if (page.kind === 'cat' && !store.plan.cats.some(c => c.id === (page as { kind: 'cat'; id: string }).id)) page = { kind: 'household' };
    document.documentElement.lang = getLocale();
    document.title = t('app.title');
    const locale = getLocale();
    const languages = h('div', { class: 'switcher', role: 'group', 'aria-label': t('app.language') },
      ...(['en', 'de'] as const).map(code => {
        const b = button(code === 'en' ? 'English' : 'Deutsch', () => { if (code !== getLocale() && canLeave()) { setLocale(code); render(); } }, `switch ${code === locale ? 'active' : ''}`);
        b.setAttribute('lang', code); b.setAttribute('aria-pressed', String(code === locale)); return b;
      }));
    const theme = savedTheme();
    const themes = h('label', { class: 'theme-select' }, h('span', null, t('app.theme')),
      h('select', { name: 'app-theme' }, ...(['system', 'light', 'dark'] as const).map(v => h('option', { value: v, selected: v === theme }, t(`theme.${v}` as UiKey)))));
    themes.querySelector('select')!.addEventListener('change', event => {
      const value = (event.currentTarget as HTMLSelectElement).value as Theme;
      try { if (value === 'system') localStorage.removeItem(THEME_KEY); else localStorage.setItem(THEME_KEY, value); } catch { /* in-memory only */ }
      applyTheme(value);
    });
    const sidebar = h('aside', { class: 'sidebar no-print' },
      h('div', { class: 'brand' }, brandMark(), h('div', null, h('strong', { class: 'wordmark' }, 'Purrtion'), h('small', null, t('brand.tagline')))),
      h('nav', { 'aria-label': t('nav.label') }, nav(t('nav.plan'), { kind: 'household' }, page.kind === 'household'),
        nav(t('nav.foods'), { kind: 'foods' }, page.kind === 'foods'), nav(t('nav.method'), { kind: 'method' }, page.kind === 'method'),
        h('h2', { class: 'nav-section-label' }, t('nav.cats')),
        ...store.plan.cats.map(c => nav(h('span', { class: 'nav-cat' }, avatar(c.id, 22, c.icon), h('span', null, c.name)), { kind: 'cat', id: c.id }, page.kind === 'cat' && page.id === c.id, c.name)),
        button(t('nav.addCat'), () => { if (canLeave()) openWizard(ctx); }, 'nav-link add-cat'),
        button(t('nav.quickAdd'), () => { if (canLeave()) addCatDialog(ctx); }, 'nav-link quick-add')),
      h('div', { class: 'sidebar-settings' }, languages, themes),
      h('div', { class: 'sidebar-footer' }, h('p', null, h('span', { class: 'local-dot', 'aria-hidden': 'true' }), t('app.local')), h('small', null, t('app.noTracking'))));
    const toolbar = h('div', { class: 'toolbar no-print' }, h('span', { class: 'plan-title' }, store.plan.name),
      h('div', { class: 'toolbar-actions' }, button(t('toolbar.import'), () => { void importFile(); }, 'button subtle'),
        button(t('toolbar.exportJson'), () => download('purrtion-plan.json', planToJSON(store.plan), 'application/json'), 'button subtle'),
        button(t('toolbar.exportCsv'), () => download('purrtion-portions.csv', planToCSV(store.plan, { asOf: todayLocalISO() }), 'text/csv'), 'button subtle'),
        button(t('toolbar.print'), () => { if (canLeave()) { page = { kind: 'household' }; render(); requestAnimationFrame(() => window.print()); } }, 'button')));
    const content = page.kind === 'household' ? household(ctx) : page.kind === 'cat' ? catPage(ctx, page.id) : page.kind === 'foods' ? foodsPage(ctx) : methodPage(ctx);
    const shown = flash; flash = null;
    const storeNotice = store.notice ? notice(t(`store.${store.notice}` as UiKey), store.notice === 'external-conflict' ? 'warning' : 'error') : null;
    const main = h('main', { id: 'main-content', tabindex: '-1', class: 'main-content' },
      h('div', { id: 'app-notices', 'aria-live': 'polite' }, storeNotice, shown ? notice(shown.text, shown.kind) : null),
      h('div', { id: 'import-error' }, appError ? notice(appError, 'error') : null), content,
      h('footer', { class: 'page-footer' }, h('p', null, t('app.footer'))));
    root.replaceChildren(h('div', { class: 'app-shell' }, sidebar, h('div', { class: 'workspace' }, toolbar, main)));
  }
  // Cross-tab sync: reload when nothing is being edited; otherwise warn that saving overwrites the other tab's change.
  window.addEventListener('storage', event => {
    const result = store.external(event.key, event.newValue, isDirty() || Boolean(document.querySelector('dialog[open]')));
    if (result === 'reloaded') { flash = { text: t('sync.updated'), kind: 'note' }; render(); }
    else if (result === 'conflict' || result === 'unreadable') {
      const box = root.querySelector('#app-notices');
      box?.replaceChildren(notice(t(`store.${store.notice}` as UiKey), result === 'conflict' ? 'warning' : 'error'));
    }
  });
  render();
}
void boot().catch(error => {
  document.querySelector('#app')!.replaceChildren(h('main', { class: 'loading' }, h('h1', null, t('boot.failed')), notice(errorText(error), 'error'),
    h('p', null, t('boot.help'))));
});
