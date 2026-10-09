import test from 'node:test';
import assert from 'node:assert/strict';
import { decimal, decimalPattern } from '../../../dist/web/apps/web/src/dom.js';
import { detectLocale, translate, ui, setLocale } from '../../../dist/web/apps/web/src/i18n.js';

test('decimal: accepts point or comma, leading and trailing separators', () => {
  setLocale('en');
  for (const [text, value] of [['5', 5], ['4.5', 4.5], ['4,5', 4.5], ['.5', 0.5], [',5', 0.5], ['5.', 5], ['5,', 5], [' 6 ', 6], ['0', 0]])
    assert.equal(decimal(text, 'Weight', 3), value, text);
});
test('decimal: rejects grouping, signs, exponents, blanks and non-finite values', () => {
  setLocale('en');
  for (const text of ['', ' ', '.', ',', '1.000,5', '1,000.5', '1 000', '-1', '+1', '1e3', 'Infinity', 'NaN', '5..', '0x10', '9'.repeat(400)])
    assert.throws(() => decimal(text, 'Weight', 3), /Weight/, text);
});
test('decimal: rejects more decimals than the field allows, so grouped input is not read as a fraction', () => {
  setLocale('en');
  assert.throws(() => decimal('1,200', 'Target', 1), /Target.*thousands separators.*decimal places allowed: 1/);
  assert.throws(() => decimal('1.200', 'Target', 1), /Target/);
  assert.throws(() => decimal('2,55', 'Grams', 1), /Grams/);
  assert.throws(() => decimal('4,1255', 'Weight', 3), /Weight/);
  assert.throws(() => decimal('5.5', 'Months', 0), /Months/);
  assert.equal(decimal('4,125', 'Weight', 3), 4.125);
  assert.equal(decimal('1200,5', 'Target', 1), 1200.5);
  assert.equal(decimal('.25', 'Share', 2), 0.25);
  assert.equal(decimal('5.', 'Months', 0), 5);
  assert.equal(decimal('7', 'Months', 0), 7);
});
test('decimal pattern: matches the same inputs as decimal() for the field limit', () => {
  const matches = (limit, text) => new RegExp(`^${decimalPattern(limit)}$`, 'v').test(text);
  for (const [limit, text, ok] of [[1, '1200', true], [1, '1200,5', true], [1, '1,200', false], [3, '4,125', true], [3, '4,1255', false],
    [2, '.25', true], [2, '.255', false], [2, '5.', true], [1, '.', false], [0, '12', true], [0, '1.5', false]])
    assert.equal(matches(limit, text), ok, `${limit} ${text}`);
});
test('locale detection: saved preference, then a German browser language, else English', () => {
  assert.equal(detectLocale('de', 'en-US'), 'de');
  assert.equal(detectLocale('en', 'de-DE'), 'en');
  assert.equal(detectLocale(null, 'de-AT'), 'de');
  assert.equal(detectLocale(null, 'DE'), 'de');
  assert.equal(detectLocale(undefined, 'fr-FR'), 'en');
  assert.equal(detectLocale('xx', null), 'en');
});
test('i18n: German and English tables have the same keys, no empty texts, and fill placeholders', () => {
  assert.deepEqual(Object.keys(ui.de).sort(), Object.keys(ui.en).sort());
  for (const locale of ['en', 'de']) for (const [key, text] of Object.entries(ui[locale])) assert.ok(text.trim(), `${locale} ${key}`);
  for (const [key, text] of Object.entries(ui.en)) {
    const names = text.match(/\{\w+\}/g)?.sort() ?? [];
    assert.deepEqual(ui.de[key].match(/\{\w+\}/g)?.sort() ?? [], names, `placeholders of ${key}`);
  }
  assert.equal(translate('de', 'wizard.progress', { n: '2', total: '9' }), 'Schritt 2 von 9');
});
