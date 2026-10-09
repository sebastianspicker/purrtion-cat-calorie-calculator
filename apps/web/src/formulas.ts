import { energyModel as m, rer, mer, effectiveBcs, lifestyleK, kittenBandMultiplier, type Cat, type EnergyEstimate } from '../../../packages/core/src/index.js';
import { texNumber as n } from './math.js';
import { t, msg, type UiKey } from './i18n.js';
/**
 * LaTeX built from `energyModel` constants (docs/ENGINE.md §8): coefficients are never typed literally here.
 * Only numbers (formatted by texNumber) and app-owned i18n words (escaped by word()) are interpolated.
 */
export interface Formula { latex: string; caption?: string }
const KCAL = '\\ \\mathrm{kcal/d}';
const KG = '\\ \\mathrm{kg}';
/** A constant with up to 4 decimals. */
const c = (value: number) => n(value, 4);
/** An app-owned word inside \text{}; LaTeX specials are escaped. */
export function word(key: UiKey): string {
  return `\\text{${t(key).replace(/[\\{}$&#^_%~]/g, ch => `\\${ch === '\\' ? 'textbackslash ' : ch}`)}}`;
}
const pow = (base: string, exponent: number) => `${base}^{${c(exponent)}}`;

/** Generic equations for the method page. */
export const generic = {
  rer: () => `\\mathrm{RER}=${c(m.rer.factor)}\\times ${pow('\\mathrm{BW}', m.rer.exponent)}`,
  mer: () => `\\mathrm{MER}=k\\times ${pow('W', m.mer.exponent)},\\quad k\\in\\{${c(m.mer.sedentary)};\\ ${c(m.mer.typical)};\\ ${c(m.mer.active)}\\}`,
  band: () => `${c(m.mer.referenceBandLow)}\\times ${pow('W', m.mer.exponent)}\\ ${word('math.to')}\\ ${c(m.mer.referenceBandHigh)}\\times ${pow('W', m.mer.exponent)}`,
  ibw: () => `\\mathrm{IBW}=\\dfrac{\\mathrm{BW}}{1+${c(m.idealWeight.fractionPerBcsUnit)}\\times(\\mathrm{BCS}-${m.bcs.ideal})},\\quad \\mathrm{BCS}\\ge ${m.bcs.overweightMin}`,
  maintainRange: () => `${word('math.range')}=[${c(m.maintain.lowFactor)};\\ ${c(m.maintain.highFactor)}]\\times ${word('math.start')},\\quad \\text{start}\\le ${c(m.maintain.maxRerMultiple)}\\times\\mathrm{RER}(\\mathrm{BW})`.replace('\\text{start}', word('math.start')),
  loss: () => `${word('math.start')}=${c(m.loss.startFactor)}\\times\\min\\big(\\mathrm{RER}(\\mathrm{IBW}),\\ \\mathrm{MER}(k,\\mathrm{IBW})\\big),\\quad ${word('math.range')}=[${c(m.loss.lowFactor)};\\ ${c(m.loss.highFactor)}]\\times ${word('math.start')}`,
  floor: () => `${word('math.floor')}=${c(m.floor.rerFactor)}\\times\\mathrm{RER}(\\mathrm{IBW})`,
  gain: () => `${word('math.start')}=${c(m.gain.startFactor)}\\times\\mathrm{MER},\\quad ${word('math.range')}=[${c(m.gain.lowFactor)};\\ ${c(m.gain.highFactor)}]\\times\\mathrm{MER}`,
  kittenNrc: () => `${c(m.kitten.nrcK)}\\times ${pow('\\mathrm{BW}', m.mer.exponent)}\\times ${c(m.kitten.nrcFactor)}\\times\\left(e^{${c(m.kitten.nrcExponent)}\\,p}-${c(m.kitten.nrcOffset)}\\right),\\quad p=\\dfrac{\\mathrm{BW}}{\\mathrm{BW}_{\\mathrm{adult}}}`,
  kittenTransition: () => `t=\\mathrm{clamp}\\!\\left(\\max\\!\\left(\\dfrac{p-${c(m.kitten.transitionStartRatio)}}{${c(m.kitten.transitionRatioWidth)}},\\ \\dfrac{m-${c(m.kitten.transitionStartMonths)}}{${c(m.kitten.transitionMonthsWidth)}}\\right),0,1\\right),\\quad ${word('math.start')}=(1-t)\\times G+t\\times\\mathrm{MER}(k,\\mathrm{BW})`,
  kittenCap: () => `${word('math.start')}\\le ${c(m.kitten.maxRerMultiple)}\\times\\mathrm{RER}(\\mathrm{BW})`,
  kittenBand: () => `m_{\\mathrm{low}}\\times ${c(m.kitten.bandLowK)}\\times ${pow('\\mathrm{BW}', m.mer.exponent)}\\ ${word('math.to')}\\ m_{\\mathrm{high}}\\times ${c(m.kitten.bandHighK)}\\times ${pow('\\mathrm{BW}', m.mer.exponent)}`,
  gestation: () => `${c(m.gestation.k)}\\times ${pow('W', m.mer.exponent)},\\quad ${word('math.range')}=[1;\\ ${c(m.gestation.highFactor)}]\\times ${word('math.start')}`,
  lactation: () => `${c(m.lactation.k)}\\times ${pow('\\mathrm{BW}', m.mer.exponent)}+c\\times\\mathrm{BW}\\times L`,
  lactationC: () => `c=\\begin{cases}${c(m.lactation.litterC[0]!)} & n\\le ${m.lactation.litterMax[0]}\\\\ ${c(m.lactation.litterC[1]!)} & n\\le ${m.lactation.litterMax[1]}\\\\ ${c(m.lactation.litterC[2]!)} & n>${m.lactation.litterMax[1]}\\end{cases}`,
  lactationL: () => `L_{\\text{1..${m.lactation.weekFactors.length}}}=(${m.lactation.weekFactors.map(f => c(f)).join(';\\ ')}),\\quad L_{>${m.lactation.weekFactors.length}}=${c(m.lactation.lateWeekFactor)}`,
  nfe: () => `\\mathrm{NFE}=\\max(0,\\ 100-M-P-F-\\mathrm{CF}-A)`,
  ge: () => `\\mathrm{GE}=${c(m.food.geProtein)}P+${c(m.food.geFat)}F+${c(m.food.geCarbohydrate)}(\\mathrm{NFE}+\\mathrm{CF})`,
  digestibility: () => `d=${c(m.food.digestibilityIntercept)}-${c(m.food.digestibilityFibreSlope)}\\times\\dfrac{100\\,\\mathrm{CF}}{100-M}`,
  me4: () => `\\mathrm{ME}=\\mathrm{GE}\\times\\dfrac{d}{100}-${c(m.food.proteinCorrection)}P`,
  fresh: () => `\\mathrm{ME}_{\\mathrm{fresh}}=${c(m.food.freshProtein)}P+${c(m.food.freshFat)}F+${c(m.food.freshNfe)}\\,\\mathrm{NFE}`,
  atwater: () => `\\mathrm{ME}_{\\mathrm{Atwater}}=${c(m.food.atwaterProtein)}P+${c(m.food.atwaterFat)}F+${c(m.food.atwaterNfe)}\\,\\mathrm{NFE}`,
  protein: () => `\\min_{\\mathrm{protein}}=\\max\\!\\left(${c(m.nutrition.adultMinProteinPer1000)},\\ \\dfrac{${c(m.nutrition.proteinRequirementPer1000)}}{\\mathrm{kcal}/W^{${c(m.mer.exponent)}}}\\right)\\ \\mathrm{g}/1000\\ \\mathrm{kcal}`,
  proteinGrowth: () => `\\min_{\\mathrm{protein}}=${c(m.nutrition.growthMinProteinPer1000)}\\ (${word('math.kitten')});\\ ${c(m.nutrition.reproductionMinProteinPer1000)}\\ (${word('math.queen')})\\ \\mathrm{g}/1000\\ \\mathrm{kcal}`,
  fixed: () => `E_{\\mathrm{fixed}}=\\sum_i g_i\\times e_i`,
  balance: () => `E_{\\mathrm{balance}}=\\max(0,\\ T-E_{\\mathrm{fixed}}-E_{\\mathrm{extras}})`,
  balanceGrams: () => `g_{\\mathrm{balance}}=\\dfrac{E_{\\mathrm{balance}}}{e_{\\mathrm{balance}}}`,
  kj: () => `1\\ \\mathrm{kcal}=${c(m.units.kjPerKcal)}\\ \\mathrm{kJ}`,
};

/** "Why this number": the cat's values substituted into the equation the estimator used. */
export function explain(cat: Cat, e: EnergyEstimate, asOf: string): Formula[] {
  const lines: Formula[] = [];
  const bw = cat.weightKg, x = m.mer.exponent;
  lines.push({ latex: `\\mathrm{RER}=${c(m.rer.factor)}\\times ${pow(n(bw, 2), m.rer.exponent)}=${n(e.rerKcal)}${KCAL}`, caption: t('why.rer') });
  if (e.startKcal === null || e.lowKcal === null || e.highKcal === null || e.equation === null) return lines;
  const start = e.startKcal, w = e.weightUsedKg ?? bw, ibw = e.idealWeight;
  if (ibw?.source === 'bcs-estimate') {
    const bcs = effectiveBcs(cat, asOf) ?? m.bcs.ideal;
    lines.push({ latex: `\\mathrm{IBW}=\\dfrac{${n(bw, 2)}}{1+${c(m.idealWeight.fractionPerBcsUnit)}\\times(${bcs}-${m.bcs.ideal})}=${n(ibw.kg, 2)}${KG}`, caption: t('why.ibw') });
  } else if (ibw?.source === 'veterinarian') lines.push({ latex: `\\mathrm{IBW}=${n(ibw.kg, 2)}${KG}`, caption: t('why.ibwVet') });
  else if (ibw?.source === 'estimate') lines.push({ latex: `\\mathrm{IBW}=${n(ibw.kg, 2)}${KG}`, caption: msg('idealWeight.estimate') });
  const range = { latex: `${word('math.range')}=${n(e.lowKcal)}\\ ${word('math.to')}\\ ${n(e.highKcal)}${KCAL}` };
  const clampedNote = (raw: number) => { if (Math.abs(raw - start) > 0.05) lines.push({ latex: `${word('math.start')}=${n(start)}${KCAL}`, caption: t('why.clamped') }); };
  switch (e.equation) {
    case 'adult-fediaf': case 'adult-gain': {
      const k = e.coefficient ?? m.mer.typical, merValue = mer(k, w);
      lines.push({ latex: `\\mathrm{MER}=${c(k)}\\times ${pow(n(w, 2), x)}=${n(merValue)}${KCAL}`, caption: t('why.mer', { k: n(k, 1).replace('{,}', ',') }) });
      if (e.equation === 'adult-gain') {
        lines.push({ latex: `${word('math.start')}=${c(m.gain.startFactor)}\\times ${n(merValue)}=${n(m.gain.startFactor * merValue)}${KCAL}`, caption: t('why.gain') });
        clampedNote(m.gain.startFactor * merValue);
      } else clampedNote(merValue);
      break;
    }
    case 'weight-loss-aaha': {
      const k = lifestyleK(cat.profile), verified = cat.profile.verifiedIntakeKcal;
      if (verified !== null) {
        const raw = m.loss.verifiedIntakeFactor * verified;
        lines.push({ latex: `${word('math.start')}=${c(m.loss.verifiedIntakeFactor)}\\times ${n(verified)}=${n(raw)}${KCAL}`, caption: t('why.verified') });
        clampedNote(raw);
      } else {
        const rerValue = rer(w), merValue = mer(k, w), raw = m.loss.startFactor * Math.min(rerValue, merValue);
        lines.push({ latex: `${word('math.start')}=${c(m.loss.startFactor)}\\times\\min(${n(rerValue)},\\ ${n(merValue)})=${n(raw)}${KCAL}`, caption: t('why.loss') });
        clampedNote(raw);
      }
      break;
    }
    case 'kitten-nrc': case 'kitten-fediaf-band': {
      const k = m.kitten, months = e.ageMonths ?? 0, adult = cat.profile.expectedAdultWeightKg;
      const lo = kittenBandMultiplier(months, k.bandLow) * mer(k.bandLowK, bw), hi = kittenBandMultiplier(months, k.bandHigh) * mer(k.bandHighK, bw);
      const ageTerm = (months - k.transitionStartMonths) / k.transitionMonthsWidth;
      let base: number, tBlend: number;
      if (e.equation === 'kitten-nrc' && adult !== null) {
        const p = bw / adult;
        base = mer(k.nrcK, bw) * k.nrcFactor * (Math.exp(k.nrcExponent * p) - k.nrcOffset);
        tBlend = Math.min(1, Math.max(0, Math.max((p - k.transitionStartRatio) / k.transitionRatioWidth, ageTerm)));
        lines.push({ latex: `p=\\dfrac{${n(bw, 2)}}{${n(adult, 2)}}=${n(p, 3)}` });
        lines.push({ latex: `\\mathrm{NRC}=${c(k.nrcK)}\\times ${pow(n(bw, 2), x)}\\times ${c(k.nrcFactor)}\\times\\left(e^{${c(k.nrcExponent)}\\times ${n(p, 3)}}-${c(k.nrcOffset)}\\right)=${n(base)}${KCAL}`, caption: t('why.kittenNrc') });
      } else {
        base = (lo + hi) / 2; tBlend = Math.min(1, Math.max(0, ageTerm));
        lines.push({ latex: `${c(kittenBandMultiplier(months, k.bandLow))}\\times ${c(k.bandLowK)}\\times ${pow(n(bw, 2), x)}=${n(lo)}${KCAL}`, caption: t('why.kittenBandLow') });
        lines.push({ latex: `${c(kittenBandMultiplier(months, k.bandHigh))}\\times ${c(k.bandHighK)}\\times ${pow(n(bw, 2), x)}=${n(hi)}${KCAL}`, caption: t('why.kittenBandHigh') });
        lines.push({ latex: `G=\\dfrac{${n(lo)}+${n(hi)}}{2}=${n(base)}${KCAL}`, caption: t('why.kittenBandMid') });
      }
      let raw = base;
      if (tBlend > 0) {
        const merAdult = mer(lifestyleK(cat.profile), bw);
        raw = (1 - tBlend) * base + tBlend * merAdult;
        lines.push({ latex: `${word('math.start')}=(1-${n(tBlend, 2)})\\times ${n(base)}+${n(tBlend, 2)}\\times ${n(merAdult)}=${n(raw)}${KCAL}`, caption: t('why.kittenTransition') });
      }
      clampedNote(raw);
      break;
    }
    case 'gestation-fediaf':
      lines.push({ latex: `${word('math.start')}=${c(m.gestation.k)}\\times ${pow(n(w, 2), x)}=${n(start)}${KCAL}`, caption: t('why.gestation') });
      break;
    case 'lactation-fediaf': {
      const l = m.lactation, litter = cat.profile.reproduction.litterSize ?? 1, week = cat.profile.reproduction.lactationWeek ?? 1;
      let tier = l.litterMax.findIndex(max => litter <= max); if (tier < 0) tier = l.litterC.length - 1;
      const factor = week <= l.weekFactors.length ? l.weekFactors[week - 1]! : l.lateWeekFactor;
      lines.push({ latex: `${word('math.start')}=${c(l.k)}\\times ${pow(n(bw, 2), x)}+${c(l.litterC[tier]!)}\\times ${n(bw, 2)}\\times ${c(factor)}=${n(start)}${KCAL}`,
        caption: t('why.lactation', { litter: String(litter), week: String(week) }) });
      break;
    }
  }
  lines.push(range);
  if (e.floorKcal !== null && ibw)
    lines.push({ latex: `${word('math.floor')}=${c(m.floor.rerFactor)}\\times ${c(m.rer.factor)}\\times ${pow(n(ibw.kg, 2), m.rer.exponent)}=${n(e.floorKcal)}${KCAL}`, caption: t('why.floor') });
  return lines;
}
