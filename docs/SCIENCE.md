# Scientific foundation for the Purrtion calculation engine

Status: addendum to `docs/CALCULATIONS.md`. Evidence reviewed as of **2026-10-09**; revised after an
independent math/science audit on the same date (section 16).
Audience: the developer/owner and a reviewing veterinarian.
Scope: evidence, formulas and an engine design for estimating feline energy needs. It is **not** a
clinical protocol. Numbers in square brackets such as [1] refer to the reference list at the end.

## 0. How to read this document

Evidence strength labels used throughout:

| Label | Meaning |
| --- | --- |
| **G** | Guideline or consensus statement from a professional body or industry federation, based on literature plus expert judgement |
| **M** | Meta-analysis or systematic synthesis of experimental data |
| **E** | Controlled experiment or RCT (usually small colony studies) |
| **O** | Observational, retrospective or survey data |
| **X** | Expert opinion or engineering choice made for this document (no direct evidence) |
| **S** | Secondary source only (I read a review, textbook chapter or summary, not the original paper) |

"Verified" means I opened the source and read the number. Anything not verified is listed in
section 15 and flagged inline with **UNVERIFIED**. Where a research subagent supplied a figure that I
did not re-open myself, the reference list says so. "Confirmed in the 2026-10-09 audit" means the
independent auditor opened the cited source and found the number.

Terms: BW body weight (kg); IBW estimated ideal body weight (kg); RER resting energy requirement;
MER maintenance energy requirement; DER daily energy requirement (any life stage); ME
metabolisable energy; BCS body condition score (9-point); MCS muscle condition score; DM dry matter;
NFE nitrogen-free extract (carbohydrate by difference); kcal means kilocalorie (1 kcal = 4.184 kJ).

Formulas are written in GitHub math. Throughout, $\mathrm{RER}(w) = 70 \times w^{0.75}$ and
$\mathrm{MER}(k, w) = k \times w^{0.67}$, with $w$ in kg and the result in kcal ME/day.

---

## 1. Summary of recommended equations

All energies are kcal ME per day. $\mathrm{BW}$ is kg.

| Use | Expression | Valid for | Source / strength |
| --- | --- | --- | --- |
| RER (reference, hospital, weight-loss base) | $70 \times \mathrm{BW}^{0.75}$ | any body weight | [4][5][9]; G |
| Linear RER (do **not** use for cats in the engine) | $30 \times \mathrm{BW} + 70$ | "more than 2 kg and less than 45 kg" per Merck; AAHA 2014 restricts it to dogs 2-25 kg | [5][9]; G |
| Adult MER, neutered and/or indoor, typical | $75 \times \mathrm{BW}^{0.67}$ | healthy adult, ideal BCS | FEDIAF 2025 [1]; G |
| Adult MER, sedentary / obesity-prone | $52$ to $75 \times \mathrm{BW}^{0.67}$; engine uses $k = 63.5$ | healthy adult | FEDIAF Table VII-9 [1]; G. The 63.5 midpoint is the value used by Menniti 2026 [27] as their reference |
| Adult MER, active (incl. most intact cats) | $100 \times \mathrm{BW}^{0.67}$ | lean adult | NRC 2006 [2]; FEDIAF [1]; G |
| Adult MER, NRC "overweight-prone" | $130 \times \mathrm{BW}^{0.4}$ | overweight, uses current BW | NRC 2006 as cited in [7][17]; G, S |
| Kitten (post-weaning) | $100 \times \mathrm{BW}^{0.67} \times 6.7 \times (e^{-0.189p} - 0.66)$, $p = \mathrm{BW} / \text{expected adult BW}$ | weaned kitten up to adult weight; the engine blends into adult MER from 10 months or $p = 0.8$ (section 3.1) | NRC 2006 [2], **not read in primary form**, numerically corroborated (section 3.1); G; blend X |
| Kitten (alternative) | $(2.0\text{–}2.5) \times \mathrm{MER}$ to 4 mo; $(1.75\text{–}2.0) \times \mathrm{MER}$ 4-9 mo; $1.5 \times \mathrm{MER}$ 9-12 mo | kitten | FEDIAF Table VII-10 [1]; G |
| Gestation | $140 \times \mathrm{BW}^{0.67}$ | queen | FEDIAF Table VII-10 [1]; G |
| Lactation | $100 \times \mathrm{BW}^{0.67} + c \times \mathrm{BW} \times L$; $c = 18$ (<3 kittens), $60$ (3-4), $70$ (>4); $L = 0.9$ wk 1-2, $1.2$ wk 3-4, $1.1$ wk 5, $1.0$ wk 6, $0.8$ wk 7 | queen | FEDIAF Table VII-10 [1]; G |
| Weight loss start | $0.8 \times \min\big(\mathrm{RER}(\mathrm{IBW}), \mathrm{MER}(k, \mathrm{IBW})\big)$, or $0.8 \times$ verified intake; floor $0.6 \times \mathrm{RER}(\mathrm{IBW})$ | overweight/obese, no disease | AAHA 2014 [5]; AAHA 2021 [4]; G; the $\min$ is X (section 16, D1) |
| Reintroducing food after prolonged anorexia | start at 25-50 % of RER, reach full RER over about 3-7 days | refer to veterinarian | [28][29]; S/G |
| ME of a food from analysis (cat, FEDIAF/NRC 4-step) | see section 10 | prepared foods | FEDIAF 2025 [1]; G |
| ME of a food, modified Atwater | $3.5P + 8.5F + 3.5\,\mathrm{NFE}$ kcal/100 g | fallback, cross-check, carbohydrate share | [1][21][22]; G/E |

---

## 2. Adult energy requirements

### 2.1 RER

$$\mathrm{RER} = 70 \times \mathrm{BW}^{0.75} \qquad (\text{kcal/day, BW in kg})$$

RER is the energy of a resting, post-absorptive animal in a thermoneutral environment. It is a
**reference**, not a feeding recommendation for a healthy home cat (consistent with the repo's
existing statement). It is the base for hospital feeding and weight-loss plans [4][5].

The linear form $30 \times \mathrm{BW} + 70$ is quoted in the Merck Veterinary Manual for animals over 2 kg and
under 45 kg [9]. AAHA 2014 states the linear equation is for dogs only (2-25 kg) and that the
exponent form "can be used for patients of any weight" [5]. At 4 kg: exponent form 198.0 kcal, linear
190 kcal (4 % lower). **Decision: use only the exponent form**, so kittens and small cats (<2 kg)
are not mishandled and the engine has a single function. This is not a claim that all AAHA publications exclude linear RER for cats: the 2021 feline life-stage guideline prints it too [10].

### 2.2 Adult maintenance equations compared

Reference values for a lean 4 kg adult (kcal/day):

| Equation | 4 kg | kcal/kg | Notes |
| --- | ---: | ---: | --- |
| FEDIAF low end of "neutered/indoor" $52 \times \mathrm{BW}^{0.67}$ | 131.6 | 33 | FEDIAF Table VII-9 range lower bound [1] |
| FEDIAF neutered/indoor $75 \times \mathrm{BW}^{0.67}$ | 189.9 | 47 | FEDIAF states "189 kcal/d for 4 kg cat" [1] |
| AAHA $1.0 \times \mathrm{RER}$ (inactive/obese-prone) | 198.0 | 50 | [6] |
| Bermingham 2010 all cats $77.6 \times \mathrm{BW}^{0.711}$ | 207.9 | 52 | meta-analysis [3] |
| Bermingham light+normal $56.2 \times \mathrm{BW}^{0.966}$ | 214 | 54 | [3] |
| NRC overweight-prone $130 \times \mathrm{BW}^{0.4}$ | 226.3 | 57 | [7] |
| WSAVA table "average healthy adult cat in ideal condition" | 225-250 | 56-62 | built from NRC $100 \times \mathrm{BW}^{0.67}$ and $130 \times \mathrm{BW}^{0.4}$ [7] |
| AAHA $1.2 \times \mathrm{RER}$ (neutered adult, low) | 237.6 | 59 | [6] |
| NRC lean/active $100 \times \mathrm{BW}^{0.67}$ | 253.2 | 63 | FEDIAF "253 kcal/d for 4 kg cat" [1] |
| AAHA $1.4 \times \mathrm{RER}$ (neutered high / intact low) | 277.2 | 69 | [6] |

The published spread for the **same** lean 4 kg cat is therefore about 130 to 280 kcal (a factor of two).
This is the central fact the engine must communicate: the output is a **starting point inside a range**,
and the cat's own weight and BCS trend decide the final amount.

Source details:

* **FEDIAF 2025** (Table VII-9, verified in the PDF): neutered and/or indoor adult cats
  $52\text{–}75 \times \mathrm{BW}^{0.67}$ (35-45 kcal/kg for a 4 kg cat as printed); active cats $100 \times \mathrm{BW}^{0.67}$.
  The printed per-kg figures do not match the formula: $52 \times 4^{0.67} / 4 = 32.9$ and
  $75 \times 4^{0.67} / 4 = 47.5$ kcal/kg. This is FEDIAF's own rounding or inconsistency; the engine uses
  the coefficients, not the printed per-kg values.
  Text: "For indoor and/or neutered adult cats the average maintenance energy requirement is estimated
  to be 75 kcal/kg BW^0.67 (Fettman 1997, Harper 2001)". FEDIAF recommends using the 0.67 exponent for
  cats and notes that although NRC specifies 100 only for lean cats, "many lean cats may need less
  energy" (Riond 2003, Wichert 2007) [1]. Strength G.
  The 2025 edition (September 2025) retained the values of the 2024 edition that appear in secondary
  summaries; I did not find a change to the cat energy section.
* **NRC 2006**: $100 \times \mathrm{BW}^{0.67}$ for lean adult cats and $130 \times \mathrm{BW}^{0.4}$ for overweight cats; the
  Guelph 2025 thesis and Bermingham both attribute these to NRC [3][17]. I could not open the NRC
  chapter itself (the National Academies "OpenBook" blocks full text), so NRC figures are **S** except
  where FEDIAF restates them.
* **AAHA 2021 Box 1** (verified, PDF from aaha.org): $\mathrm{MER} = \mathrm{RER} \times \text{life-stage factor}$ with feline factors
  neutered adult 1.2-1.4, intact adult 1.4-1.6, inactive/obese-prone 1.0, weight loss 0.8, gestation
  1.6-2.0, lactation 2.0-6.0, growth 2.5. The box states "Sedentary and/or indoor pets may require less
  caloric intake than indicated above. Adjustment of caloric intake should be done by monitoring BW and
  BCS" [6]. Strength G. The Merck manual lists neutered $1.2 \times \mathrm{RER}$ and intact $1.4 \times \mathrm{RER}$ [9].
* **WSAVA** publishes a calorie table for a healthy adult cat in ideal condition (1 kg: 100-130 kcal/day
  to 7 kg: 280-370), derived from NRC lean $100 \times \mathrm{BW}^{0.67}$ and obese-prone $130 \times \mathrm{BW}^{0.4}$, "for guidance
  only. Cats are individuals" [7]. Strength G.
* **Bermingham et al. 2010** (meta-analysis, 115 treatment groups, verified in full text via a subagent):
  mean maintenance 55.1 ± 1.2 (SE) kcal/kg BW. Table 3 equations are $Y = a \times \mathrm{BW}^{b}$ with $Y$ in kcal/day
  (the abstract prints the exponent with a misleading minus sign). All cats $77.6 \times \mathrm{BW}^{0.711}$
  (adj. R² 0.448); light (<3 kg) $53.7 \times \mathrm{BW}^{1.061}$; normal (3-5.5 kg) $46.8 \times \mathrm{BW}^{1.115}$
  (R² 0.425); heavy (>5.5 kg) $131.8 \times \mathrm{BW}^{0.366}$ (R² 0); neutered female $53.7 \times \mathrm{BW}^{1.023}$;
  neutered male $77.6 \times \mathrm{BW}^{0.754}$; entire female $49.0 \times \mathrm{BW}^{1.193}$; entire male $70.8 \times \mathrm{BW}^{0.882}$;
  per kg lean mass $58.4 \times \mathrm{LBM}^{1.140}$ (R² 0.694). Individual cat range 122.5-401.0 kcal/day
  (29.0-85.5 kcal/kg) [3][19]. Strength M. The weight categories light/normal/heavy were a proxy for
  leanness, which the authors acknowledge as a limitation. Neutered cats needed 10.4 % less per kg than
  entire cats (56.6 vs 63.2 kcal/kg; P < 0.05) [3].

### 2.3 Individual variation and what it implies

* Bermingham: within-study SDs in Table 1 correspond to CVs of roughly 10-30 % (computed by the
  subagent from Table 1; the paper reports no overall CV). Body weight explains only about 45 % of the
  variance (R² 0.45) and lean mass about 69 % [3][19]. Strength M.
* Wichert 2012: overweight-prone entire male cats needed 162.6 kJ/kg fat-free mass/day versus 246 kJ/kg
  in lean cats, a 34 % gap at similar condition [19]. Strength E (small).
* Riond 2003 (respiration chamber): activity-induced heat production was 13.5 % of total daily heat
  production; ME for maintenance 153 kJ/kg BW/day (about 36.6 kcal/kg) in lab cats [19]. Strength E.
* Seasonal: intake about 15 % lower in summer than winter in 38 colony cats, weight unchanged
  (Serisier 2014) [19]. Strength O.
* FEDIAF 2025 chapter 7.2.3: formulas "give average metabolisable energy needs, actual needs ... may vary
  greatly" [1]. AAHA: use as a starting point and adjust by monitoring [4][6].
* A 2025 University of Guelph thesis states the NRC active-cat value "is likely too high for neutered
  cats, those living indoors and those already overweight" [17]. Strength S.
* A spaying study (PubMed 22005410) reported mean MER after reaching BCS 5 of 313.6 kJ/kg^0.67
  (= 75 kcal/kg^0.67, which the abstract describes as 25 % below NRC) [26]. A study of cats after controlled
  weight loss (PubMed 34148606) reported a weight-maintenance MER of 273 ± 56.7 kJ/kg^0.67 IBW/day
  (= 65 ± 13.5 kcal/kg^0.67) [26]. Both consistent with the lower half of FEDIAF's range.
  Authors/years of these two were not captured in my session; see the reference list.

**Engine consequences (X, derived from the above):**

1. Output = `startKcal` plus a range `[lowKcal, highKcal]`.
2. Default range: $0.85 \times \text{start}$ to $1.15 \times \text{start}$ (an app-selected planning band, not an estimated standard deviation, confidence interval or validated prediction interval). For cats aged 12 y or more use
   $0.85 \times$ to $1.25 \times \text{start}$, because energy per kg rises after about 12 y (section 3.4).
3. The published "literature envelope" (52 to 100 coefficient) is shown only as an explanatory band, never
   as a target.
4. Final amount is determined by the monitor-and-adjust loop (section 12.4), in ±10 % steps.

---

## 3. Life stages

Life-stage definitions follow the 2021 AAHA/AAFP Feline Life Stage Guidelines [10] (full primary PDF checked in the D9 review): **Kitten** birth to 1 year; **Young adult**
1-6 years; **Mature adult** 7-10 years; **Senior** older than 10 years; **End-of-life** any age. In completed
years this is: mature adult 7-10 completed years, senior from 11 completed years (i.e. older than 10). The guideline has no separate geriatric age stage, and notes that age boundaries are approximate. Engine mapping:

| Engine stage | Rule | Notes |
| --- | --- | --- |
| `neonate` | age < 8 weeks | out of scope: refer (section 12.6) |
| `kitten` | 8 weeks up to 12 months; reaching an expected adult weight prompts reassessment (D9) | growth equation blending into adult MER (3.1) |
| `adult` | 1 to 10 completed years | maintenance equation |
| `senior` | ≥ 11 completed years | same equation; wider upper range from 12 y, monitoring emphasis |
| `end_of_life` | user/vet flag | no calculation, comfort-feeding message only |

The engine's senior stage and the AAHA/AAFP senior label coincide (≥ 11 completed years). The wider energy
range starts one year later, at 12 y, because the measured turning point is about 11.6-12 y (see 3.4).

### 3.1 Kitten growth

NRC 2006 expresses post-weaning kitten energy relative to the growth stage
$p = \text{current BW} / \text{expected adult BW}$. The commonly cited expression is:

$$\mathrm{ME}_{\text{kitten}} = 100 \times \mathrm{BW}^{0.67} \times 6.7 \times \big(e^{-0.189p} - 0.66\big) \qquad (\text{kcal/day})$$

$$f(p) = 6.7 \times \big(e^{-0.189p} - 0.66\big) \qquad (\text{multiplier of NRC adult MER})$$

Status: **not verified from the primary NRC text** (I could not open it). Evidence for the expression:
(a) a Guelph study states NRC describes kitten energy by the BW/adult BW ratio; (b) a published case series
(Vecchiato 2021, Front Vet Sci 8:707741) applied "the NRC equations proposed for growth kittens after
weaning" and tabulated 0.85 kg → 180, 2.35 kg → 280, 3.20 kg → 292 kcal ME/day [25]. Using the expression
above with an expected adult weight of 4.0 kg gives 180.6, 279.0 and 291.6 kcal/day for the three cases (published:
180, 280, 292); back-solving the adult weight from each case gives 3.89-4.04 kg, i.e. the formula gives close numerical agreement for one adult weight of about 4 kg, without proving that these were the original inputs. That cross-check is why the formula is adopted, but it
should be confirmed against the NRC text by the reviewing veterinarian before release. The follow-up audit also
found the same expression used explicitly in the methods of a primary kitten study [40]; this corroborates
the transcription but does not validate the app's later transition blend.

Multiplier table, computed from the formula (relative to $100 \times \mathrm{BW}^{0.67}$):

| $p$ | 0.1 | 0.2 | 0.3 | 0.4 | 0.5 | 0.6 | 0.7 | 0.8 | 0.9 | 1.0 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| $f(p)$ | 2.153 | 2.029 | 1.909 | 1.790 | 1.674 | 1.560 | 1.448 | 1.338 | 1.230 | 1.124 |

FEDIAF 2025 Table VII-10 instead gives multiples of MER by age: up to 4 months 2.0-2.5; 4-9 months
1.75-2.0; 9-12 months 1.5 [1]. It does not say which MER is multiplied (UNVERIFIED); the engine interprets it
as $k \times \mathrm{BW}^{0.67}$ with $k$ from 75 (lower) to 100 (upper). AAHA Box 1 uses a flat growth factor of
$2.5 \times \mathrm{RER}$ [6]; Merck also gives $2.5 \times \mathrm{RER}$ and says kittens "can alternatively be fed free choice" [9].

Practical growth markers (S, from Hand et al., Small Animal Clinical Nutrition, ch. 24 [12]): kittens
gain about 100 g/week until about 20 weeks; reach about 80 % of adult size at about 30 weeks; adult weight
at about 40 weeks (10 months); skeletal maturity about 10 months; "over-nutrition is of greater concern
than undernutrition in growing kittens"; ten-week-old kittens have a DER of about 200 kcal/kg falling to
about 80 kcal/kg at 10 months; food energy density 4.0-5.0 kcal ME/g DM for growth; obesity prevalence
rises sharply after one year.

**Engine rule (X; section 16, D4).** Let $A$ be the expected adult weight, $m$ the age in months and
$k_A$ the adult tier the cat would get from its neuter status and lifestyle (section 12.2).

* FEDIAF band: the multipliers are placed at the band centres (2, 6.5 and 10.5 months: $[2.0, 2.5]$,
  $[1.75, 2.0]$, $[1.5, 1.5]$), interpolated linearly between them and held flat outside, so the band has no
  steps at 4 and 9 months. $\text{bandLow} = m_{\text{low}} \times \mathrm{MER}(75, \mathrm{BW})$,
  $\text{bandHigh} = m_{\text{high}} \times \mathrm{MER}(100, \mathrm{BW})$.
* With $A$ known: $\mathrm{NRC} = \mathrm{ME}_{\text{kitten}}$ above, and a transition weight
  $$t = \operatorname{clamp}\Big(\max\big(\tfrac{p - 0.8}{0.2},\ \tfrac{m - 10}{2}\big),\ 0,\ 1\Big) \qquad \text{start} = (1 - t)\,\mathrm{NRC} + t\,\mathrm{MER}(k_A, \mathrm{BW})$$
* With $A$ unknown: $\text{mid} = (\text{bandLow} + \text{bandHigh})/2$,
  $t = \operatorname{clamp}\big(\tfrac{m - 10}{2}, 0, 1\big)$ and $\text{start} = (1 - t)\,\text{mid} + t\,\mathrm{MER}(k_A, \mathrm{BW})$.
  The app asks for the adult weight (parents' size, vet estimate). Do **not** guess adult weight from breed alone.
* In both paths the **start only** is capped at $2.5 \times \mathrm{RER}(\mathrm{BW})$ (AAHA growth factor). The range
  is $[\min(0.9 \times \text{start}, \text{bandLow}),\ \max(1.1 \times \text{start}, \text{bandHigh})]$ and is not capped;
  when $t > 0$ it also includes the adult range $[0.85, 1.15] \times \mathrm{MER}(k_A, \mathrm{BW})$.
* The kitten stage ends at 12 months. Reaching $A$ earlier does not establish maturity: the app refers for growth/weight reassessment without an energy estimate (D9). Growth-diet advice remains visible in the referral.

Example, 4-month kitten, 2.0 kg, expected adult 4.0 kg ($p = 0.5$, $t = 0$): NRC = 266.3 kcal; interpolated
multipliers at 4.0 months 1.889-2.278, band 225.4-362.4; cap $2.5 \times \mathrm{RER}(2\ \text{kg}) = 294.3$ does not bind.
Start 266.3, range 225.4-362.4, with the instruction to adjust to growth rate. Without the adult weight the start is
the band midpoint 293.9. More examples, including the transition, are in section 13 (C, C2, C3).

The previous rule (NRC until 12 months, then adult) made a step at the first birthday: at $p \to 1$ the NRC
start is $1.124 \times 100 \times \mathrm{BW}^{0.67} = 112.4 \times \mathrm{BW}^{0.67}$, while a neutered adult gets $75 \times \mathrm{BW}^{0.67}$,
a 33 % drop overnight (section 16, D4).

Weaning: dams usually wean at 4-5 weeks, as early as 3 weeks in orphans; nutritional weaning typically
completed by about 6 weeks (Fontaine 2012) [13]; neonate energy 130-150 kcal/kg/day in the first 3 weeks,
200-220 kcal/kg after 4 weeks (same source, S). These are shown for context only; neonates are
out of scope.

Early-age neutering: in kittens neutered at 7 weeks or 7 months, heat coefficient later was higher in intact
than neutered cats; the abstract reports no growth difference (Root 1996) and AAHA/Hand state age at neutering
does not alter growth rate [12][14]. See section 5 for the energy effect.

### 3.2 Adult (young and mature)

Use section 2. The default tier follows neuter status and lifestyle (section 12.2). Young cats (0.5-2 y)
in Bermingham had a per-kg mean of 59.4 vs 48.4 kcal/kg for 2-7 y (sparse data) [19]; the engine ignores
this and relies on monitoring.

### 3.3 Weight categories and body composition

Light cats (<3 kg) have higher per-kg requirements (62.8 kcal/kg) than normal (56.3) and heavy (43.9)
cats [19]. The 0.67 exponent already encodes much of this scaling; the engine does not add a size term.

### 3.4 Senior and geriatric

* Laflamme 2005 (verified, full PDF): maintenance requirement per kg fell with age to about 11 years, then
  rose; "by approximately 12 years of age onward ... MERs per unit of body weight actually increased"
  (cross-sectional fit $\mathrm{MER}\ (\text{kcal/kg}) = 89.576 - 7.771\,a + 0.334\,a^{2}$ with age $a$ in years,
  $r^{2} = 0.34$, minimum at $a = 7.771 / (2 \times 0.334) = 11.6$ y).
  A second cohort of 85 cats aged 10-15 y confirmed rising MER, greatest after 13 y [18]. Strength O.
* Digestibility: fat digestibility is reduced in about one third of cats over 12 y; protein digestibility is
  reduced in about 20 % of cats over 14 y (Perez-Camargo 2004 as cited in [18]; S). AAHA 2021: "In cats, fat,
  protein, and energy digestibility can decrease with advanced aging. Energy intake can be higher for senior
  cats to compensate" [4]. A greater proportion of cats over 12 y are underweight [18].
* Harper 1998 (older): MER constant through adult life; do not routinely give reduced-energy diets to old
  cats [19]. Conflicts mildly with Laflamme 2005; the newer, larger data (Laflamme) are preferred, and both
  agree on **not reducing energy for age**.
* Protein: Laflamme & Hannah 2013 (24 neutered males, mean 4.9 y): nitrogen-balance needs about 1.5 g/kg but
  maintaining lean body mass needed at least 5.2 g protein/kg/day (7.8 g/kg^0.75); the authors say needs of
  females and geriatric cats "may differ" [16]. Laflamme 2005 text: adult cats need more than 5 g protein/kg
  BW, about 34 % of calories as protein, to support lean mass; age data for cats are lacking [18]. A 2026 JFMS
  review states "anabolic resistance ... may result in increased dietary protein requirements" and that there are
  "no official guidelines for senior or geriatric cats" (relayed by subagent, not opened) [19].
* Sarcopenia and condition: Teng 2018 (2,609 cats): compared with BCS 6 as maximum reference, hazard ratios for
  death were 4.67 at BCS 3, 2.61 at BCS 4, 1.43 at BCS 5 and 1.80 at BCS 9; BCS <5 and BCS 9 were associated with
  shorter survival [19]. Strength O. Low BCS and low MCS in seniors are health signals, not diet targets.
* Muscle condition score: four grades (normal, mild, moderate, severe loss) assessed at spine, scapulae, skull,
  wings of the ilia [WSAVA, summaries only]; inter-rater kappa 0.43-0.53 in two studies [19]. MCS is therefore a
  coarse, subjective input.

**Engine rules (X):** no age-based energy cut. For ≥12 y use the wider upper range, require MCS and BCS entry, and
treat unintended weight loss (≥5 % over 4 weeks, or any weight loss with BCS ≤4) as a **veterinary referral**.
Recommend a complete senior protein check against section 9, using at least the minimum of the 75-kcal tier
(83.3 g/1000 kcal), which is the scaled minimum $6250 / 75$ for a cat eating $75 \times \mathrm{BW}^{0.67}$.

### 3.5 End of life

No evidence-based energy formula. The AAHA/AAFP guideline defines end-of-life as a stage at any age [10]. The engine
shows no kcal target; only a fixed message to follow the veterinary team's plan (appetite, comfort, quality of life).

---

## 4. Reproduction

### 4.1 Gestation

$$\mathrm{ME}_{\text{gestation}} = 140 \times \mathrm{BW}^{0.67} \qquad (\text{FEDIAF 2025 Table VII-10; G})$$

BW is not defined in the FEDIAF table; NRC practice is BW at breeding (**UNVERIFIED**). The engine uses the queen's
pre-breeding (ideal) weight. For a 4 kg queen: 354.4 kcal/day ($1.40 \times$ the active adult MER of 253). Queens gain up
to about 38 % of pre-pregnancy weight, rate linear; energy rises about 10 %/week from early pregnancy,
ending at 25-50 % above maintenance (Fontaine 2012) [13], consistent with $140 / 100 = 1.4$. Guidance
for the food: at least 4000 kcal ME/kg DM and free-choice feeding of a nutrient-dense growth/reproduction diet
[13]. Strength G/S.

AAHA Box 1 gives $1.6\text{–}2.0 \times \mathrm{RER}$ for feline gestation [6]; for 4 kg that is 317-396 kcal (RER 198). FEDIAF (354) is inside
this band. Use FEDIAF.

### 4.2 Lactation

$$\mathrm{ME}_{\text{lactation}} = 100 \times \mathrm{BW}^{0.67} + c \times \mathrm{BW} \times L$$

with $c = 18$ (fewer than 3 kittens), $60$ (3 to 4 kittens), $70$ (more than 4 kittens) and
$L = 0.9$ (weeks 1-2), $1.2$ (weeks 3-4), $1.1$ (week 5), $1.0$ (week 6), $0.8$ (week 7).

(FEDIAF Table VII-10; G.) kJ versions: $418 \times \mathrm{BW}^{0.67} + \lbrace 75, 250, 293 \rbrace \times \mathrm{BW} \times L$. The table does not say how to define BW
during lactation (current vs. pre-breeding; **UNVERIFIED**); the engine uses the queen's current weight and
shows a note. Computed for a 4 kg queen (kcal/day):

| Litter | wk 1-2 (0.9) | wk 3-4 (1.2) | wk 5 (1.1) | wk 6 (1.0) | wk 7 (0.8) |
| --- | ---: | ---: | ---: | ---: | ---: |
| < 3 kittens | 318 | 340 | 332 | 325 | 311 |
| 3-4 kittens | 469 | 541 | 517 | 493 | 445 |
| > 4 kittens | 505 | 589 | 561 | 533 | 477 |

Comparators: AAHA $2.0\text{–}6.0 \times \mathrm{RER}$ (4 kg → 396-1188) [6]; Fontaine 2012 says queens consume 1-1.5 × maintenance in
week 1, 2 × in week 2 and 2.5-3 × in weeks 3-4, and quotes "250 to 354 kcal ME/kg BW", a figure that is
inconsistent with the FEDIAF formula (541 kcal for 4 kg is 135 kcal/kg) and that I could not reconcile
(treat as unreliable) [13]. Queens are normally unable to cover lactation energy needs from food alone and
mobilise fat stores [13]. **Recommendation:** use FEDIAF as the *floor* and encourage free-choice feeding
(`ad libitum`) of a growth/reproduction diet, because needs vary widely with milk output. Quantitative
rationing of a lactating queen by the app is not appropriate; show a range $[\text{FEDIAF},\ 1.25 \times \text{FEDIAF}]$ for
information only and a veterinary-referral banner (section 12.6).

Weaning of kittens at weeks 4-6 [13]; after week 7 return gradually to maintenance (X, no source).

---

## 5. Neutering, activity, indoor and outdoor

| Finding | Source | Strength |
| --- | --- | --- |
| Spayed females: fasting metabolic rate fell from 83.7 to 67.2 kcal/kg^0.75/day; males had minimal change; neutered males gained 30.2 % vs 11.8 % in entire; females 40.0 % vs 16.1 % | Fettman 1997 [14] | E |
| Males: intake rose about 12 % rapidly after gonadectomy, body weight +27-29 % (mostly fat); energy expenditure did not differ: "a stair-step increase in energy intake, and not decreased energy expenditure, appears to drive the weight gain" | Kanchuk 2003 [14] | E |
| Females: intake had to be cut 30 % to hold weight after spaying; activity fell to about 20 % of baseline in the dark period at week 12 | Belsito 2009 [14] | E |
| Females: weight-maintenance calories significantly lower 8 and 16 weeks after neutering; no change in males | Hoenig & Ferguson 2002 [14] | E |
| Ad libitum cats gained 31 % of weight in 12 months after OVH vs 3.1 % before; under controlled feeding mean +7.5 %; weight gain inversely related to age/weight at neutering | Harper 2001 [14] | O/E |
| Neutering reduces energy requirements by 24-33 % regardless of age at neutering | Root 1995, Flynn 1996 as quoted in [12] | S |
| Meta-analysis: neutered 10.4 % less per kg than entire | Bermingham 2010 [3] | M |
| Indoor neutered cats have higher body fat than outdoor intact cats at the same BCS | Hoelmkjaer & Bjornvad 2014 [13b] | S |

Synthesis:

* Direction is clear (energy need falls and appetite rises after gonadectomy). Magnitude varies by sex and
  study (0 to 33 %); the intake rise is rapid (days to weeks) and the weight gain accrues over about 6-12
  months, so waiting for weight gain delays the correction.
* Engine (X): at neutering (or when "recently neutered" is selected) switch from the `100` tier to the `75` tier
  (a 25 % reduction, matching the 25 % lower MER in the spayed-cat study and the 24-33 % range) and prompt
  fortnightly weighing for 6 months. The reduction is a default; the user can override.
* Activity (Riond): 13.5 % of heat production; activity falls after neutering (Belsito). Because lifestyle is
  coarse, the engine has three activity tiers (sedentary 63.5, typical 75, active 100) rather than free
  multipliers.
* Seasonal swings of about 15 % are within the ±15 % range and need no separate factor.
* Early-age (prepubertal) neutering: energy effects not separately quantified in anything I could open;
  growth is not impaired [12]. No kitten-specific evidence for a neutered-kitten energy factor was found, so the
  engine has none. A neutered kitten gets the same growth equation; its neuter status enters only through the
  adult tier $k_A$ that the kitten start blends into from 10 months or $p = 0.8$ (section 3.1).

---

## 6. Body condition, ideal weight, muscle

### 6.1 BCS and body fat

Laflamme 1997 introduced the 9-point scale (1 emaciated, 5 ideal, 9 grossly obese) [15]. The original paper was not
opened; AAHA 2021: "Every incremental increase in BCS is equivalent to a 5 % increase in BF % while each BCS
>5/9 is equivalent to being 10 % overweight" [4]; Hoelmkjaer & Bjornvad: each unit above ideal is about 10-15 % over
ideal weight [13b]. Intra-observer CV 8.1 %, inter-observer 11.6-15 %; BCS is imprecise at the extreme top [13b].

DXA body fat in indoor neutered pet cats (Bjornvad 2011) [11][13b]:

| BCS | Male %BF | Female %BF |
| ---: | --- | --- |
| 4 | – | 21.4 ± 0.5 (n = 2) |
| 5 | 30.1 ± 4.1 (n = 8) | 31.6 ± 4.6 (n = 10) |
| 6 | 34.6 ± 2.1 (n = 7) | 39.3 ± 4.8 (n = 10) |
| 7 | 41.8 ± 5.9 (n = 5) | 42.3 ± 3.9 (n = 9) |
| 8 | 46.9 ± 3.8 (n = 14) | 48.6 ± 3.2 (n = 4) |
| 9 | 49.0 (n = 1) | 50.7 ± 4.1 (n = 3) |

(Female BCS 7-9 values are the 2011 pet-cat columns; the table in the review is garbled in places, so verify
individual cells against the paper.) Bjornvad's conclusion: cats scoring 5 averaged about 32 % fat, above the 30 %
upper limit usually considered ideal; the ideal BCS for inactive neutered cats "may need to be redefined to include a
score of 4" [11]. FEDIAF repeats: neutered cats should be fed to keep BCS 4/9 [1]. The AAFP 2018 feeding
statement targets BCS 4-5/9 [11b]. Teng 2018 mortality data favour 5 over 4 (HR 1.43 vs 2.61 against a reference of
6) [19]. **Recommendation:** target range BCS 4-5, weight-loss end point BCS 5 (reassess then), never push to 4
automatically.

### 6.2 Ideal-weight estimation

Two methods; both are estimates.

(A) BCS shortcut (AAHA 2021/2014), for $\mathrm{BCS} \ge 5$:

$$\mathrm{IBW} = \frac{\mathrm{BW}}{1 + 0.10 \times (\mathrm{BCS} - 5)}$$

(B) Body-fat mass balance (lean mass held constant):

$$\mathrm{IBW} = \mathrm{BW} \times \frac{100 - \mathrm{BF}_{\text{now}}}{100 - \mathrm{BF}_{\text{target}}} \qquad (\mathrm{BF} \text{ in } \%)$$

Method B is standard arithmetic; I found no published validation of it for cats, so
treat it as **X**. $\mathrm{BF}_{\text{now}}$ comes from the table in 6.1 (use the female/male average), $\mathrm{BF}_{\text{target}}$ 31 % for BCS 5
(Bjornvad pet-cat mean) or 21-25 % for BCS 4. Worked: 6 kg cat, BCS 8: (A) $6 / 1.3 = 4.62$ kg;
(B) $6 \times (100 - 47) / (100 - 31) = 4.61$ kg; with a BCS 4 target (BF 21.4) B gives 4.05 kg. Error: BF% SD within a BCS class is 2-6 points, which
alone is about ±5-8 % of IBW; with BCS inter-observer CV up to 15 %, the app **chooses a ±10 % IBW planning band (X)**. Those observations do not establish a ±10 % error bound or coverage probability. The engine should
display IBW as a rounded value with that assumed band and compute weight goals in steps (reassess at each 10 % of loss).

Persistence (X; section 16, D3): once the owner adopts a weight-loss plan, the BCS-derived IBW is **stored** as an
estimate and no longer re-derived from each new BCS, because a cat that is losing weight and dropping in BCS would
otherwise get a shrinking ideal weight and a moving target. The app offers "re-estimate from BCS" (for example when
the BCS has changed by ≥1 and the owner or veterinarian wants a new end point); a veterinary IBW always wins.

### 6.3 Body fat index (BFI) and zoometric methods

AAHA 2021 mentions BFI is a validated scale for BF% in dog and cat and is useful for BCS ≥8/9 [4]. The
Hawthorne & Butterwick feline BFI, as quoted in a 2026 review (Iwazaki & Mori, eq. 4; I did not open the original paper) is:

$$\mathrm{BF}\,\% = \frac{\mathrm{RC} / 0.7067 - \mathrm{LIM}}{0.9156} - \mathrm{LIM}$$

where $\mathrm{RC}$ is the rib-cage circumference at the 9th rib (cm) and $\mathrm{LIM}$ the leg index measurement, patella
middle to calcaneal tip (cm).

Caveats: my own recollection of the divisor 0.7062 differs from the review's 0.7067 (UNVERIFIED); the 9th rib is hard to locate
in obesity; breathing changes the measure; reproducibility data are scarce [20]. **Recommendation: do not implement BFI in
the consumer engine**; BCS plus an optional vet-entered BF% is enough.

### 6.4 Muscle condition score

Enter MCS (normal / mild / moderate / severe loss). Any loss is a risk flag in AAHA 2021 ("BCS <4/9 or >5/9, MCS with any degree of loss" trigger an
extended assessment) [4]. MCS is subjective (kappa 0.4-0.5) [19]; it can only trigger recommendations, never lower a
target.

---

## 7. Weight loss, weight gain and refeeding

### 7.1 Weight loss: energy

Sources:

| Source | Starting energy | Strength |
| --- | --- | --- |
| AAHA 2014 Weight Management (Brooks) [5] | Option 1 "80 % of the current caloric intake" (suits stable-weight pets with accurate diet history; more reduction if still gaining). Option 2 $0.8 \times \mathrm{RER}(\mathrm{IBW})$: "there is no established standard reduction, feeding 80 % of ideal-weight RER is effective and well tolerated" | G |
| AAHA 2021 [4][6] | Box 1: weight-loss factor $0.8 \times \mathrm{RER}$; "Base these calculations on ideal weight"; mean intake achieved over 12 weeks of loss was 52 ± 4.9 kcal/kg^0.711 in cats (confirmed in the 2026-10-09 audit; AAHA's underlying references not opened) | G |
| Hoelmkjaer & Bjornvad 2014 [13b] | 80 % of RER, or 80 % of intake recorded in a 2-week diary; about 39 kcal/kg initial for a 4 kg target; adjust ±10 %. Reports a hepatic-lipidosis case in a cat fed about 30 kcal/kg target BW (confirmed in the 2026-10-09 audit) | S |
| FEDIAF [1] | no weight-loss equation | |

Both AAHA options are reasonable; the first needs a trustworthy diet history, which a consumer app rarely has.
Evidence base: **expert consensus**, with a modest empirical support (the 52 kcal/kg^0.711 average achieved).

Cross-check against maintenance at the ideal weight:

$$\frac{0.8 \times \mathrm{RER}(\mathrm{IBW})}{\mathrm{MER}(k, \mathrm{IBW})} = \frac{56}{k} \times \mathrm{IBW}^{0.08}$$

For the typical tier ($k = 75$) at 4.6 kg IBW this is 175.9 vs 208.5 kcal, i.e. 84 % of the FEDIAF neutered MER; at
4 kg 158.4 vs 189.9 (83 %), a roughly 16-17 % deficit. For the sedentary tier ($k = 63.5$) the ratio is 0.985 at
4 kg, 0.996 at 4.6 kg and **reaches 1 at IBW 4.81 kg**: "80 % of ideal-weight RER" then feeds a sedentary cat its full
sedentary maintenance at the ideal weight, so it would not lose weight on the expected schedule. Alternative
$\mathrm{NRC}\ 130 \times \mathrm{BW}^{0.4}$ at current weight 6 kg is 266.2 kcal; the typical-tier start below (166.8 kcal at
IBW 4.6 kg) is a 37 % deficit relative to that figure; the rate check below governs.

**Recommendation (engine; section 16, D1):**

$$\text{floor} = 0.6 \times \mathrm{RER}(\mathrm{IBW})$$

$$\text{start} = \max\Big(\text{floor},\ 0.8 \times \min\big(\mathrm{RER}(\mathrm{IBW}),\ \mathrm{MER}(k, \mathrm{IBW})\big)\Big)$$

i.e. 80 % of the lower of the inactive-maintenance anchor ($1.0 \times \mathrm{RER}$, AAHA "inactive/obese-prone") and the
cat's own tier at its ideal weight. Range: $[\max(\text{floor}, 0.875 \times \text{start}),\ 1.125 \times \text{start}]$.

If the user supplies a verified current intake $V$ of a weight-stable cat, the engine uses AAHA option 1 instead:

$$\text{start} = \max(\text{floor},\ 0.8 \times V)$$

and if $V < \text{floor}$ it refers to the veterinarian (a weight-stable cat that eats less than 60 % of its
ideal-weight RER needs a work-up, not a further cut). The earlier rule "use the higher of $0.8 \times \mathrm{RER}(\mathrm{IBW})$
and $0.8 \times$ intake" is withdrawn: for a cat that holds its weight on 150 kcal it gave 176.3 kcal, more than the cat
already eats.

**Floor.** The follow-up audit verified AAHA 2014, printed page 8 [5]: the authors describe
clinical experience with restriction down to 60 % of ideal-weight RER, and warn of nutrient,
behavioural and feline hepatic-lipidosis risks with greater restriction. This is clinical guidance,
not proof that the threshold is safe for every cat. The app's hard floor remains an engineering
policy (X), including its extension to maintenance and gain. Hoelmkjaer & Bjornvad report a
hepatic-lipidosis case at about 30 kcal/kg target BW [13b]; the floor is 28.7 kcal/kg at IBW 4.6 kg.
Close monitoring and an appropriate diet remain necessary; the floor is not a recommended target.

### 7.2 Rate, monitoring and plateaus

* Target rate: "in cats 0.5-2 %/wk" (AAHA 2014) [5]; Hoelmkjaer: 0.5-2 % of initial BW per week [13b];
  iCatCare 2025 for diabetic obese cats: "a maximum weight loss of around 0.5-1 % per week is generally suggested" [30].
  **Engine: aim 0.5-1 %/wk; accept up to 2 %/wk; suggest +10 % when faster than 2 %/wk; refer to the veterinarian when
  faster than 3 %/wk or ≥ 8 % in 28 days (section 16, D5).** For a 6 kg cat: 30-60 g/wk target, 120 g/wk upper,
  180 g/wk referral. The engine's rate is in % of the current (28-day window mean) weight, not of the initial weight.
* Adjustment: "If weight loss is greater than the above-described desired rates, increase calories by 10 % and monitor
  response" [5]. Insufficient loss: after checking adherence and risk, reduce calories by 10-20 % and/or change activity [5, printed p. 8; verified in the follow-up audit]. If still losing at IBW: increase calories by 10 % to move to maintenance [5].
* Schedule: first contact after week 1, weigh every 2 weeks until a stable loss rate, then monthly [5]; recalc IBW when
  BCS changes. If MCS worsens, check protein intake and rate of loss [5].
* Plateau: the sources give no cat-specific plateau rule beyond the 10-20 % step; metabolism may "reset at a lower rate"
  [5]. Engine (X): when the loss is slower than 0.25 %/wk over a weighing window spanning at least 21 days, decrease by
  10 %, never below the floor; after two such steps refer to veterinarian (check disease, food measurement error, treats).
* Diet: therapeutic weight-loss diets are recommended when restricting to ≤ RER; high protein spares lean mass;
  protein and fibre add satiety; high-moisture foods may help in cats; change diets over 4-7 days [4][5].
  Protein at least 5 g/kg of **target** body weight per day during loss (Hoelmkjaer; S) [13b]. Example, IBW 4.6 kg: 23 g
  protein/day from the typical-tier start of 166.8 kcal = **137.9 g/1000 kcal** (about 55 % of ME at 4 kcal/g protein) –
  usually only met by a veterinary weight-loss wet diet.
* Hepatic lipidosis (HL): obese cats are at risk if intake falls or anorexia occurs; excessive restriction raises lipid
  mobilisation [13b][5]. Safety rules: floor above, no fasting, ≤2 %/wk, referral above 3 %/wk, any cat not eating for >24 h on a diet →
  contact veterinarian (X; AAHA 2021 uses 72 h at ≤1/3 RER as the tube-feeding trigger in hospitals [4]).
* Rebound: 46 % of cats regained weight and 27 % regained more than 50 % of lost weight in cat studies cited in the
  Hoelmkjaer review [13b] (S). After the end point: raise by ~10 % steps to maintenance, monitor every 2 weeks until stable then monthly [5], keep the
  weight-loss food or portion control, and treat with a lifelong monitoring plan.

### 7.3 Underweight and weight gain

* BCS ≤3/9, unexplained weight loss or low MCS are **medical** problems (disease, dental, endocrine, CKD, neoplasia).
  Teng: HR for death 4.67 at BCS 3 [19]. Engine: refer, no calculation.
* BCS 4/9 healthy cat wanting to gain (e.g. after illness, with vet agreement): start $1.15 \times \mathrm{MER}(k, W)$ within
  $[1.10, 1.20] \times \mathrm{MER}(k, W)$, with start and both endpoints raised to the floor when needed (X; derived from AAHA 10-20 % adjustment steps) and review in 2 weeks; stop when BCS 5
  (or 4-5 in neutered) is reached. No evidence-based gain-rate target exists in cats; use 1 %/wk as an upper alert (X).
* AAHA 2021: for hospitalised animals base calculations on current weight if ideal or underweight [4].

### 7.4 Refeeding syndrome and prolonged anorexia

* AAHA 2021: enteral tube feeding is strongly recommended within 72 h of intake ≤1/3 RER, including time before
  hospitalisation; oral syringe feeding is no longer recommended [4].
* MSPCA-Angell: start at 25-50 % of RER, increase over 2-3 days, reach RER in 4-7 days in refeeding-syndrome risk; monitor
  phosphorus/potassium/magnesium; suspect if a >20 % fall in any; cut rate by 50-75 % [28]. Kidder (dvm360 2010): $\mathrm{RER} = 30 \times \mathrm{BW} + 70$, no illness
  factor, full volume increased gradually over 3-7 days [29]. Armitage-Chan 2006 case report (JVECC 16(2):S34-S41): refeeding syndrome
  in a cat [23] (content not opened). Thiamine and electrolyte doses are not verified (UNVERIFIED).
* Strength: G/S, small evidence base. **A consumer calculator must not schedule refeeding**; it shows only the
  referral message in section 12.6.

---

## 8. Special needs and disease

Rule: **any disease flag turns the engine into "reference only" mode** (RER and maintenance reference shown, no goal
engine, no label recommendations beyond arithmetic). The table lists what is known, for the reviewing veterinarian.

| Condition | Diet goals (evidence) | Energy considerations | What the calculator must NOT do |
| --- | --- | --- | --- |
| **CKD** | IRIS 2026: phosphate restriction by renal diet from stage 2 (plasma phosphate <1.5 mmol/L; stage 3 <1.6; stage 4 <1.9), binders if needed; renal diets are protein- and phosphate-restricted with higher calorie density; moderate protein restriction with monitoring of lean mass; "phosphate restriction is thought to be mainly responsible" for longer survival (median survival 633 vs 264, 480 vs 210 days, and RCT Ross 2006: 0 % vs 26 % uraemic episodes) [31][32] | Maintain weight and MCS; prevent protein-calorie malnutrition; tube feeding in stage 4 | Calorie-restrict, suggest a renal diet without veterinary staging, choose phosphate targets, warn that a renal diet is "below the protein minimum" (the engine skips that check for CKD) |
| **Hyperthyroidism** | ISFM/AAFP 2016: iodine-restricted diet (0.2 ppm DM) can control T4 in 75 % within 28 days, up to 83 % remission in a one-year study but must be the only food; unsuitable for multi-cat or outdoor access; long-term effects unknown [33] | Cats are typically thin and hungry before treatment; weight rises after treatment | Combine such a diet with other foods/treats; compute weight loss |
| **Diabetes mellitus** | iCatCare 2025 (uses ALIVE terminology): low-carbohydrate diet ideally ≤12 % ME carbohydrate (confirmed in the 2026-10-09 audit [39]; alternatively <25 % DM, <15 % ME, <5 g/100 kcal); wet food for all; avoid diet change at insulin start; obese: BCS 5/9 by 0.5-1 %/wk loss (early weight loss tied to 15-fold higher remission odds); remission 11 to >60 % in reports; stay at BCS 4-5 in remission [30]. AAHA 2026 section 8 recommends about 12 % ME carbohydrate for most diabetic cats, while allowing moderate-carbohydrate weight-loss diets (15-25 % ME) in obese cats; the threshold is not a universal diet-suitability test [34] | Insulin dose and food are coupled | Change food/amount without veterinary insulin plan; claim carbs cause DM |
| **Obesity** | section 7 | section 7 | Go below floor; skip veterinary screen when comorbidity |
| **Critical care / hospital** | RER only; abandoned illness factors: Kidder 2010 "Current recommendations are to just use the RER without the illness factor" [29]. Remillard 2001, Walton 2001 not verified | Start fractionally; feeding within 72 h | Any hospital feeding calculation |
| **Hepatic lipidosis** | Do not restrict protein (Merck, S: "protein restriction compromises survival"), no fat restriction; esophagostomy tube preferred; energy about $60 \times \mathrm{BW}$, starting near half, full by days 3-5 (Merck, S) [9b] | Early assisted enteral feeding | Any HL feeding |
| **GI disease / pancreatitis** | ACVIM 2021 (Forman): withholding food is not recommended; early enteral feeding; cats tolerate fat better than dogs; highly digestible diets; no evidence that fat is deleterious in chronic pancreatitis; "The dietary needs for cats with acute pancreatitis have not been determined" [35] | High-fat foods may help meet calories in low volume | Apply the dog rule "restrict fat" to cats |
| **Urinary / FLUTD** | ACVIM 2016 uroliths consensus (Lulich): struvite dissolution diets take 2-5 weeks; low Mg/P, urine pH <6.5; high moisture (>75 % water) is a cornerstone for prevention [36] | Not energy-driven | Prescribe stone-specific diets |
| **Cancer cachexia** | Low BCS and muscle wasting are common (44 % BCS <3/5, >90 % muscle wasting in one series; Baez 2007, S) | Maintain intake; weight loss ≥5 % at 1 month tied to shorter lymphoma survival (Krick 2011, S) | Weight-reduction advice |
| **Hyperlipidemia** | Not verified (Xenoulis 2016 not retrieved; UNVERIFIED). Low-carb diets are usually high-fat, caution in hyperlipidaemia (VIN review, S) | | Recommend low-carb/high-fat without vet |
| **Food allergy / IBD** | limited-antigen or hydrolysed diet (iCatCare notes many hydrolysed diets exceed low-carbohydrate limits) [30] | | Make elimination-diet recommendations |

Evidence quality is generally low to moderate (small trials, observational, expert consensus), with the CKD phosphate
and hyperthyroid iodine data the strongest, and the hepatic lipidosis, cachexia and hyperlipidaemia statements the
weakest in this review.

---

## 9. Macronutrients and key nutrient minima

### 9.1 Obligate carnivore physiology, carbohydrate and fat

* Free-choice cats (Hewson-Hughes 2011, J Exp Biol 214:1039-1051; abstract/summary only) select about 52 % of
  energy from protein, 36 % fat, 12 % carbohydrate, with a carbohydrate intake ceiling; this is a choice-feeding result
  with no health outcome [24] (S).
* Diabetes risk factors with good evidence: obesity, inactivity, indoor confinement, greed [19b]. Slingerland 2009 case-control:
  dry-food proportion not significant (P = 0.29) while indoor confinement and inactivity were [19b]. That carbohydrate intake
  *causes* feline diabetes is **not proven**; a low-carbohydrate diet probably helps glycaemic control and remission in
  diabetic cats (uncontrolled and observational: Roomp & Rand 2009 64 % remission on ≤10 % ME carbohydrate; Rothlin-Zachrisson 2023
  29 % overall remission with wet-food OR 3.16 vs prescription diabetes diet) while iCatCare states "Remission can still be achieved in
  cats eating higher carbohydrate diets" [30][19b].
* Obesity: energy balance is the driver. High-protein and high-moisture foods help satiety and lean-mass retention [4]. The claim that
  high-carbohydrate diets cause feline obesity independent of calories is **contested/unproven**; the claim that low-fat vs low-carb
  matters for weight loss is also unsettled in this review. The engine must therefore **not** give a carbohydrate target to healthy cats; it
  only reports carbohydrate %ME (Atwater basis, section 10.4) and flags it for diabetic cats (via the vet).
* Fat: no minimum except essential fatty acids; FEDIAF minimum 22.5 g/1000 kcal (9 % DM at 4000 kcal/kg), not adjusted for lower energy
  intake [1]. Fat restriction is a weight-loss tool via energy density only.

### 9.2 Protein and amino acids (adult)

| Standard | Adult | Growth / reproduction | Notes |
| --- | --- | --- | --- |
| FEDIAF 2025 (MER 75 tier) | 83.3 g/1000 kcal (33.3 g/100 g DM) | growth 70.0, reproduction 75.0 g/1000 kcal; 28 / 30 g/100 g DM | [1]; growth/reproduction assignment confirmed in FEDIAF 2025 Table III-4b (2026-10-09 audit) |
| FEDIAF 2025 (MER 100 tier) | 62.5 g/1000 kcal (25.0 g/100 g DM) | same | [1] |
| AAFCO (via Merck, S) | 65 g/1000 kcal (26 % DM) | 75 g/1000 kcal (30 % DM) | not read in primary form [9] |
| NRC 2006 RA (via Merck, S) | 40 g/1000 kcal | 45 g/1000 kcal | [9] |
| Practical protein per kg | ≥5 g/kg BW/day to hold lean mass (Laflamme & Hannah) | – | [16] |

FEDIAF's logic: the minimum is expressed per kcal and **must be raised when a cat eats less per kg^0.67** (it was derived from
an assumed energy intake). The general rule in the guideline text:

$$\text{units per 1000 kcal} = \frac{\text{nutrient requirement per day (units/kg}^{0.67}) \times 1000}{\text{DER (kcal/kg}^{0.67})}$$

For protein, the requirement is 6.25 g/kg^0.67 ($62.5 \times 100 / 1000$; same as $83.3 \times 75 / 1000$) [1]. So the
minimum protein density is

$$\text{min protein (g/1000 kcal)} = \max\Big(62.5,\ \frac{6250}{k_{\text{actual}}}\Big) \qquad k_{\text{actual}} = \frac{\text{daily kcal}}{W^{0.67}}$$

Weight-loss example: whenever the start is $0.8 \times \mathrm{MER}(75, \mathrm{IBW})$ (typical tier, section 7.1),
$k_{\text{actual}} = 60$ exactly and the minimum is **104.2 g/1000 kcal**; for the sedentary tier ($k_{\text{actual}} = 50.8$ at
IBW 4.615 kg) it is 123.0. The same scaling applies to every essential nutrient (taurine, Ca, P,
vitamins), which is why unrestricted calorie cuts of complete maintenance food produce deficiency risks, and why therapeutic
weight-loss diets exist [1][4]. Use this scaling in label checks (section 12.5). Kittens use the growth minimum (70) and
queens the reproduction minimum (75) without scaling. For cats with CKD the protein minimum is not checked, because protein for
those cats is a veterinary decision (section 8).

Other FEDIAF numbers used by the engine (per 1000 kcal, adult 75 tier | adult 100 tier | growth/reproduction): taurine wet 0.67 | 0.50 | 0.63 g,
dry 0.33 | 0.25 | 0.25 g; fat 22.5 | 22.5 | 22.5 g; linoleic 1.67 | 1.25 | 1.38 g; calcium 1.33 | 1.00 | 2.50 g; phosphorus 0.85 | 0.64 | 2.10 g
(maximum for phosphorus is footnote-dependent; FEDIAF cites tolerance of 1 g P/1000 kcal in healthy adult cats) [1].

### 9.3 Fibre

FEDIAF Table III-4b has no fibre minimum. Fibre reduces energy digestibility in the prediction equation (section 10) and adds satiety in
weight-loss diets [4]. Starch digestibility and hairball data were not retrieved (UNVERIFIED).

---

## 10. Food energy from labels

### 10.1 Prefer the declared value

Use the manufacturer's declared ME (kcal/100 g or kcal/kg, kJ allowed) whenever available. In the EU the declared value should come from
the FEDIAF predictive equations or a feeding trial. In the US, AAFCO requires calorie statements but "does not standardize this process" [4].
Guaranteed analysis values are minima/maxima (not measured means), so computing energy from them is approximate **(AAFCO guaranteed-analysis convention
not re-verified here)**.

### 10.2 FEDIAF/NRC 4-step (cats) – primary, verified in the 2025 FEDIAF guideline

All percentages are **as fed** except where noted; $P$ crude protein, $F$ crude fat, $\mathrm{CF}$ crude fibre, $A$ crude ash, $M$ moisture.

$$\mathrm{NFE} = 100 - M - P - F - \mathrm{CF} - A \qquad (\%)$$

$$\mathrm{GE} = 5.7P + 9.4F + 4.1(\mathrm{NFE} + \mathrm{CF}) \qquad (\text{kcal/100 g})$$

$$\mathrm{CF}_{\mathrm{DM}} = \frac{\mathrm{CF}}{100 - M} \times 100 \qquad (\% \text{ in dry matter})$$

$$\text{digestibility}\ (\%) = 87.9 - 0.88 \times \mathrm{CF}_{\mathrm{DM}}$$

$$\mathrm{DE} = \mathrm{GE} \times \frac{\text{digestibility}}{100} \qquad \mathrm{ME} = \mathrm{DE} - 0.77P \qquad (\text{kcal/100 g})$$

kJ versions: $\mathrm{GE} = 23.8P + 39.3F + 17.1(\mathrm{NFE} + \mathrm{CF})$; $\mathrm{ME} = \mathrm{DE} - 3.22P$ [1]. The note in FEDIAF warns that for dog foods with high crude fibre the
prediction underestimates; no cat caveat. For "prepared" foods only; for fresh/natural products (meat, offal, milk, cooked starch)
use $\mathrm{ME} = 4P + 8.5F + 4\,\mathrm{NFE}$ (cats; kJ $16.7P + 35.6F + 16.7\,\mathrm{NFE}$) [1].

### 10.3 Modified Atwater (AAFCO tradition, fallback)

$$\mathrm{ME}_a\ (\text{kcal/100 g}) = 3.5P + 8.5F + 3.5\,\mathrm{NFE} \qquad (\text{cat/dog modified Atwater: 3.5 / 8.5 / 3.5 kcal per g})$$

Accuracy: for cats Hall 2013 (PLoS ONE 8:e54405) found modified Atwater on average within 1.57 % and NRC within 1.80 % of measured ME, but
mean absolute differences of 173 and 180 kcal/kg [21]. In Jewell & Jackson 2023, Table 4's independent check dataset
(859 dry and 601 wet observations from a study of 847 feline foods), mean absolute errors were dry 347 (modified Atwater)
versus 173 (NRC), wet 61 versus 52 kcal/kg [22]. Relative to that same check dataset's means (4198 dry, 970 wet), the
Atwater errors are 8.3 % and 6.3 %. The earlier document mixed these check-set errors with training-set means.
Both food types had prediction errors; this does not establish universal accuracy for wet foods. The four-step method
performed better on average in this dataset, not necessarily for every food.
These are study-average absolute prediction errors, not a symmetric uncertainty interval for every label;
the follow-up audit removed that overgeneralisation from the UI.

### 10.4 Derived quantities

$\mathrm{ME}_4$ is the 4-step (or fresh-food) ME of 10.2, $\mathrm{ME}_a$ the modified Atwater ME of 10.3, both kcal/100 g as fed.

$$\text{kcal per g} = \mathrm{ME}_4 / 100 \qquad \text{protein (g/1000 kcal)} = \frac{P}{\mathrm{ME}_4} \times 1000$$

$$\text{carbohydrate } \%\mathrm{ME} = \frac{3.5\,\mathrm{NFE}}{\mathrm{ME}_a} \times 100$$

$$\text{carbohydrate (g per 100 kcal ME, 4-step)} = \frac{\mathrm{NFE}}{\mathrm{ME}_4} \times 100$$

$$\text{nutrient (\% DM)} = \frac{\text{nutrient (\% as fed)}}{100 - M} \times 100 \qquad \text{nutrient (\% as fed)} = \text{nutrient (\% DM)} \times \frac{100 - M}{100}$$

The carbohydrate energy share uses the Atwater basis in numerator **and** denominator (section 16, D6). That is the
convention the iCatCare-style "% ME" thresholds use, and it equals the Atwater-normalised energy share shown on the food card,
so the food card and the per-cat check give the same number. For a mixed diet the per-cat value is
$\sum_i g_i \times 3.5\,\mathrm{NFE}_i \,/\, \sum_i g_i \times \mathrm{ME}_{a,i} \times 100$ over grams $g_i$ eaten. The gram-based
figure is per 100 kcal of 4-step ME, because that is the energy the cat is fed.

Worked examples (verified by computation):

| | Wet food | Dry food |
| --- | ---: | ---: |
| Moisture / protein / fat / fibre / ash (% as fed) | 78 / 10 / 5 / 0.5 / 2 | 8 / 34 / 14 / 3 / 7 |
| NFE (by difference) | 4.5 | 34.0 |
| Modified Atwater $\mathrm{ME}_a$ (kcal/100 g) | 93.25 | 357.0 |
| FEDIAF GE / digestibility / DE / $\mathrm{ME}_4$ | 124.5 / 85.9 % / 106.9 / **99.2** | 477.1 / 85.0 % / 405.7 / **379.5** |
| Energy shares protein / fat / carbohydrate (% of $\mathrm{ME}_a$; engine) | 37.5 / 45.6 / 16.9 | 33.3 / 33.3 / 33.3 |
| Carb % ME (engine, $3.5\,\mathrm{NFE} / \mathrm{ME}_a$) | 16.9 % | 33.3 % |
| Carb % ME, mixed basis $3.5\,\mathrm{NFE} / \mathrm{ME}_4$ (not used) | 15.9 % | 31.4 % |
| Carb g/100 kcal ME, 4-step (engine) | 4.5 | 9.0 |
| Carb g/100 kcal, Atwater (not used) | 4.8 | 9.5 |
| Protein g/1000 kcal (4-step, engine / Atwater) | 101 / 107 | 90 / 95 |

Mixed example: 100 g of the wet food plus 30 g of the dry food gives $51.45 / 200.35 = 25.7\ \%$ ME carbohydrate.

The two methods differ by 6 % (wet) and 6 % (dry) in this example; the engine should show the 4-step as primary and
Atwater as a cross-check, and mark ME as "estimated from analysis" (existing repo warning).
Ash is often missing on labels; if absent the engine must either require it or flag the result as ±(unverifiable). Typical default values
(wet 2 %, dry 7 % as fed) are engineering assumptions, **UNVERIFIED**, and the label estimate must be marked low-confidence.

kcal–kJ: $\text{kcal} = \text{kJ} / 4.184$ (existing repo behaviour). Example: 1600 kJ/100 g = 382.4 kcal/100 g.

---

## 11. Practical feeding science

* **Treats and non-complete items ≤10 % of daily calories** (AAHA 2014: "treat allowance of up to 10 % of total calories"; AAHA 2021:
  main complete diet ≥90 % of intake, other items ≤10 %) [4][5]. Matches existing repo warning. Strength G.
* **Weigh food, do not scoop.** Measuring cups for dry kibble: intra-subject CV 2-13 %, inter-subject 2-28 %; portion errors from −18 %
  to +80 %, larger for small portions (German et al. 2011; primary abstract checked, not full text) [37]; cups can give portions "up to 40 % larger" [13b]. Use grams.
* **Feeding programmes** (AAFP consensus statement 2018, Sadek et al.; AAFP statement, not an AAFP/ISFM joint document): several small meals across
  24 h (no specific number), multiple separated feeding stations in multi-cat homes, away from litter boxes, puzzle feeders and hidden kibble to
  increase activity; feed to BCS 4-5/9; monitor weight [11b][38]. Strength G (consensus). Hunting-based frequency "about 10-20 small meals" is folk
  knowledge and not stated in the statement; do not encode a number.
* **Multi-cat households:** separate calorie budgets per cat, prevent food theft; microchip feeders are suggested [38]. Existing app model
  already per-cat.
* **Monitoring cadence (X from AAHA):** weight loss: first contact after 1 week, weigh every 2 weeks, monthly when stable [5]. Maintenance: weigh monthly,
  implemented as every 4 weeks (28 days) so that the reminder fits the 28-day trend window (section 16, D8), BCS at least every 3 months, clinic recheck annually (AAHA: nutritional assessment at every visit [4]). Kittens: weekly (Hand: monthly vet checks until 4 months,
  owner weighs weekly [12]).
* **Step size:** ±10 % of the daily energy per adjustment (AAHA 2014, Hoelmkjaer) [5][13b]; re-evaluate after at least 2 weeks.
* **Accuracy of household weighing:** kitchen-scale versus baby-scale accuracy in cats was not found (UNVERIFIED); recommend a scale with 1-5 g
  resolution (pet/baby scale) and the same conditions each time.

---

## 12. Proposed calculation model for Purrtion

Principle (unchanged): **the engine suggests a range and a starting point; it never silently overrides a vet-set target.**
A target the user enters (or marks "set by vet") always wins; the engine's number is shown beside it with the difference.
The normative rules are in `docs/ENGINE.md`; this section gives the model and its reasoning. The decisions D1-D7 from the
2026-10-09 audit are marked and explained in section 16.

### 12.1 Inputs

| Input | Type | Notes |
| --- | --- | --- |
| `ageMonths` | number | determines stage; date of birth preferred |
| `bwKg` | number | current weight, scale reading, 0.1-40 (existing bounds); kept in sync with the newest weigh-in by the UI |
| `neutered` | `yes`/`no`/`unknown`; `monthsSinceNeuter` optional | default tier |
| `lifestyle` | `sedentary`/`typical`/`active` | default from neuter status (neutered → typical, otherwise → active) |
| `bcs` | 1-9 integer | required for adults; images/definitions in UI |
| `mcs` | `normal`/`mild`/`moderate`/`severe` | optional but required ≥12 y |
| `idealBwKg` + `idealBwSource` | number + `veterinarian`/`estimate` | stored ideal weight; a vet value, or the BCS estimate the owner adopted with a weight-loss plan (D3). Used as-is; re-derived from BCS only when empty |
| `expectedAdultBwKg` | number | kittens; ends the kitten stage when reached |
| `repro` | `none`/`gestation`/`lactation` + `litterSize`, `lactationWeek` | queens |
| `medical` | list of flags (CKD, DM, hyperthyroid, GI, HL, urinary, cancer, hospitalised, other) | any → reference only or referral |
| `vetTargetKcal` | number | optional, wins |
| `intakeHistory` | verified kcal/day of a weight-stable cat (optional) | replaces the weight-loss start by $0.8 \times$ intake (AAHA option 1, D1) |
| `food(s)` | ME label values or analysis | for label checks |

### 12.2 Pipeline

0. Validate; run the hard stops (12.6); if a stop fires, output the referral only.
1. **Stage** from age, reproduction and end-of-life status. A kitten reaching its estimated adult weight remains a kitten and is referred for growth reassessment (D9).
2. **Ideal weight** (D3): stored value (vet or adopted estimate) as-is; else $\mathrm{BW} / (1 + 0.10 \times (\mathrm{BCS} - 5))$
   when BCS ≥ 6; else $\mathrm{BW}$.
3. **Base kcal** by stage:
   * kitten: NRC growth (or the FEDIAF band midpoint) blending into $\mathrm{MER}(k_A, \mathrm{BW})$ from 10 months or $p = 0.8$
     (3.1, D4); start capped at $2.5 \times \mathrm{RER}(\mathrm{BW})$;
   * adult/senior: $\mathrm{MER}(k, W)$ with $k = 63.5$ (sedentary), $75$ (typical) or $100$ (active), and
     $W = \mathrm{IBW}$ whenever $\mathrm{IBW} < \mathrm{BW}$, else $\mathrm{BW}$ (D2);
   * gestation: $140 \times \mathrm{BW}_0^{0.67}$ ($\mathrm{BW}_0$ = pre-breeding weight);
   * lactation: $100 \times \mathrm{BW}^{0.67} + c \times \mathrm{BW} \times L$.
4. **Modifiers:** recent neutering → typical tier ($k = 75$, already the default); no age, breed or season factors.
5. **Goal:**
   * maintain: start = base;
   * lose (only when $\mathrm{IBW} < \mathrm{BW}$): $\text{start} = \max\big(\text{floor}, 0.8 \times \min(\mathrm{RER}(\mathrm{IBW}), \mathrm{MER}(k, \mathrm{IBW}))\big)$,
     or $\max(\text{floor}, 0.8 \times V)$ with a verified intake $V$; $V$ below the floor → refer (D1);
   * gain: $1.15 \times \mathrm{MER}(k, W)$ (BCS 4 only, vet-confirmed).
6. **Clamps:** $\text{floor} = 0.6 \times \mathrm{RER}(\mathrm{IBW})$ for every adult/senior start and range low; adult maintenance start
   is capped at $1.4 \times \mathrm{RER}(\mathrm{BW})$ before applying the floor, which takes precedence (D7); kitten start $\le 2.5 \times \mathrm{RER}(\mathrm{BW})$;
   round to 1 kcal for display.
7. **Range:** maintain $[\max(\text{floor}, 0.85 \times \text{start}), 1.15 \times \text{start}]$ ($1.25$ high factor for ≥12 y); lose
   $[\max(\text{floor}, 0.875 \times \text{start}),\ 1.125 \times \text{start}]$; gain $[1.10, 1.20] \times \mathrm{MER}(k, W)$ with both endpoints floored; kitten as in 3.1.
8. **Compare:** if a vet target is present, show it as THE target; list the engine range; warn if outside the range.
9. **Label checks:** section 12.5, only when the estimate is usable (status ok or reference-only).
10. **Loop:** section 12.4.

Reference TypeScript (all constants sourced above):

```ts
const rer = (w: number) => 70 * w ** 0.75;
const mer = (k: number, w: number) => k * w ** 0.67;
const clamp01 = (x: number) => Math.min(1, Math.max(0, x));

// D4: kitten start. kAdult is the adult tier from neuter status and lifestyle (63.5 | 75 | 100).
const bandCentres = [2, 6.5, 10.5], bandLowM = [2.0, 1.75, 1.5], bandHighM = [2.5, 2.0, 1.5];
const interp = (months: number, ys: number[]): number => {
  if (months <= bandCentres[0]) return ys[0];
  for (let i = 0; i < bandCentres.length - 1; i++) {
    const c0 = bandCentres[i], c1 = bandCentres[i + 1];
    if (months <= c1) return ys[i] + (months - c0) / (c1 - c0) * (ys[i + 1] - ys[i]);
  }
  return ys[ys.length - 1];
};
const kittenBand = (bw: number, months: number) =>
  [interp(months, bandLowM) * mer(75, bw), interp(months, bandHighM) * mer(100, bw)] as const;
const kittenNrc = (bw: number, adultBw: number) => mer(100, bw) * 6.7 * (Math.exp(-0.189 * bw / adultBw) - 0.66);
const kittenStart = (bw: number, months: number, kAdult: number, adultBw: number | null) => {
  const [low, high] = kittenBand(bw, months);
  const base = adultBw === null ? (low + high) / 2 : kittenNrc(bw, adultBw);
  const t = clamp01(Math.max(adultBw === null ? 0 : (bw / adultBw - 0.8) / 0.2, (months - 10) / 2));
  return Math.min((1 - t) * base + t * mer(kAdult, bw), 2.5 * rer(bw));
};

const gestation = (bw0: number) => 140 * bw0 ** 0.67;
const lactationL = [0, 0.9, 0.9, 1.2, 1.2, 1.1, 1.0, 0.8] as const; // index = week (1-7)
const lactation = (bw: number, kittens: number, week: number) => {
  const c = kittens < 3 ? 18 : kittens <= 4 ? 60 : 70;
  return 100 * bw ** 0.67 + c * bw * lactationL[week];
};

const idealWeightBcs = (bw: number, bcs: number) => bw / (1 + 0.10 * Math.max(0, bcs - 5));
const weightUsed = (bw: number, ibw: number) => (ibw < bw ? ibw : bw); // D2
const weightLossFloor = (ibw: number) => 0.6 * rer(ibw);
// D1. null = refer ('verified-intake-below-floor').
const weightLossStart = (ibw: number, k: number, verifiedIntake: number | null): number | null => {
  const floor = weightLossFloor(ibw);
  if (verifiedIntake === null) return Math.max(floor, 0.8 * Math.min(rer(ibw), mer(k, ibw)));
  return verifiedIntake < floor ? null : Math.max(floor, 0.8 * verifiedIntake);
};

// D6
const minProteinGPer1000kcal = (stage: string, kcalPerDay: number, w: number) =>
  stage === 'kitten' ? 70 : stage === 'gestation' || stage === 'lactation' ? 75
    : Math.max(62.5, 6250 / (kcalPerDay / w ** 0.67));
const atwater = (p: number, f: number, nfe: number) => 3.5 * p + 8.5 * f + 3.5 * nfe;
const carbPercentMe = (items: { grams: number; protein: number; fat: number; nfe: number }[]) => {
  const carb = items.reduce((s, i) => s + i.grams * 3.5 * i.nfe, 0);
  const me = items.reduce((s, i) => s + i.grams * atwater(i.protein, i.fat, i.nfe), 0);
  return me > 0 ? carb / me * 100 : 0;
};
```

Test vectors (to 2 decimals):

* `mer(75, 4) = 189.86`; `mer(100, 4) = 253.15`; `rer(4) = 197.99`; `gestation(4) = 354.41`;
  `lactation(4, 4, 4) = 541.15` (3-4 kittens, week 4).
* Kittens: `kittenNrc(2, 4) = 266.32`; `kittenStart(2, 4, 100, 4) = 266.32` ($t = 0$; band 225.40-362.41);
  `kittenStart(2, 4, 100, null) = 293.91` (band midpoint); `kittenStart(3.4, 11, 75, 4) = 230.85` ($t = 0.5$ from age);
  `kittenStart(3.4, 11, 75, null) = 234.13`; `kittenStart(3.6, 9, 75, 4) = 233.54` ($t = 0.5$ from weight);
  `kittenStart(0.8, 2, 100, 4) = 148.03` (capped at $2.5 \times \mathrm{RER}(0.8)$; NRC 174.76).
* Weight loss, 6 kg at BCS 8 (`ibw = 6 / 1.3 = 4.615`): `weightLossFloor(ibw) = 132.25`;
  `weightLossStart(ibw, 75, null) = 167.17`; `weightLossStart(ibw, 63.5, null) = 141.54`;
  `weightLossStart(ibw, 100, null) = 176.34`; `weightLossStart(ibw, 75, 200) = 160.00`;
  `weightLossStart(ibw, 75, 150) = 132.25` (floor); `weightLossStart(ibw, 75, 120) = null` (refer).
* Nutrition: `minProteinGPer1000kcal('adult', 167.17, ibw) = 104.17`; kitten `70`; lactation `75`.
  `carbPercentMe` of 100 g of the section 10.4 wet food = 16.89, of the dry food = 33.33, of 100 g wet + 30 g dry = 25.68.

### 12.3 Output

`{ stage, startKcal, lowKcal, highKcal, basis: string[], warnings: string[], stops: string[], rerKcal, referenceBand, idealWeight }`.
`basis` lists the equation, coefficients and sources so the UI can show "why this number". `referenceBand` is the $[52, 100]$
coefficient range converted to kcal for adults. `idealWeight` carries its source (veterinarian, stored estimate, BCS estimate,
current weight) and its app-selected ±10 % planning band for estimates.

### 12.4 Monitoring and adjustment loop

* Weigh on the same scale at the same time of day. The rate $r$ is the least-squares slope over the weigh-ins of the last
  28 days, in % of the mean weight of that window per week; it needs a span of at least 14 days. $c_{28}$ is the change from
  the first to the last weigh-in of the window.
* Maintenance (BCS 4-5): $c_{28} \ge +2\ \%$ → −10 % energy; $c_{28} \le -2\ \%$ → +10 % energy; recheck in 2-4 weeks.
  $\lvert c_{28} \rvert \ge 5\ \%$ or $r < -2$ %/wk → veterinarian.
* Weight loss: target $r$ between −0.5 and −1.0 %/wk, acceptable to −2 %/wk.
  * $r < -3$ %/wk or $c_{28} \le -8\ \%$ → veterinarian (D5); $c_{28} \ge +5\ \%$ → veterinarian.
  * $-3 \le r < -2$ → +10 % energy.
  * $-2 \le r \le -0.5$ → on track, no change.
  * $-0.5 < r \le -0.25$, or $r > -0.25$ over a window spanning less than 21 days → no change, recheck in 2 weeks.
  * $r > -0.25$ over a window spanning ≥ 21 days → −10 % (not below the floor; if that would go below the floor → veterinarian);
    second plateau → veterinarian (D5 for the 21 days).
  * Weight reaches the ideal weight → move to maintenance at $\mathrm{MER}(k, \mathrm{IBW})$, then +10 % steps until stable,
    recheck monthly for 6 months.
* Gain: $r > 1$ %/wk → −10 %; $r \le 0$ over a window spanning ≥ 21 days → +10 %; BCS 5 reached → maintenance.
* Kitten: weekly weighing; expect about 100 g/week to about 20 weeks; weight not above the weigh-in of 7-14 days earlier → vet.
* Step size always 10 % of current kcal; at most one change per 2 weeks.
* Suggested cadence of reminders: weight loss and weight gain every 2 weeks; maintenance every 4 weeks (AAHA "monthly", D8); kittens weekly;
  seniors every 4 weeks plus BCS/MCS quarterly.

These thresholds are X, derived from AAHA 2014 (10 % steps, 0.5-2 %/wk, 2-week/monthly cadence) [5]; the 3 %/wk and 8 %/28 d
referral limits and the 21-day plateau span are section 16, D5.

### 12.5 Nutrient and label checks

Run only when the estimate is usable (status ok or reference-only); otherwise report "not applicable". Given a food's ME and
analysis (as-fed %):

1. ME per 100 g: declared value, else FEDIAF 4-step (primary) with Atwater cross-check (differences >10 % → warn). Mark source (`declared`, `4-step`, `atwater`).
2. $\text{proteinPer1000} = P / \mathrm{ME} \times 1000$. Required minimum: adult maintenance
   $\max(62.5, 6250 / k_{\text{actual}})$ where $k_{\text{actual}} = \text{plannedKcal} / W^{0.67}$ (so 83.3 for $k = 75$, higher when the plan is below that).
   Weight loss (the `weight-loss-aaha` equation only): also check ≥5 g protein/kg IBW/day.
   Kitten ≥ 70 and queen ≥ 75 g/1000 kcal (FEDIAF growth / reproduction) – and a "complete for growth" claim is required (label statement; cannot be verified by the app).
   CKD: the minimum is not checked (protein is the veterinarian's decision); a note says so.
3. Carbohydrate: report carbohydrate % ME ($3.5\,\mathrm{NFE} / \mathrm{ME}_a$, gram-weighted over the cat's foods) and g per 100 kcal ME
   (4-step); **informational only** for healthy cats; for the diabetic flag show the iCatCare thresholds (≤12 % ME ideal; <15 % ME; <5 g/100 kcal) as vet-owned information only.
4. Taurine/Ca/P cannot be checked without analysis; if present compare with the 75/100 tier table in 9.2 scaled by $k_{\text{actual}}$.
5. Treats and complementary items ≤10 % (existing).
6. Complete-and-balanced claim must be recorded as a user attestation; the app cannot assess micronutrients.
7. Display `kcal/kg` and `g/day` with an "estimated" tag; explain that prediction error varies by food and equation; study averages are not a universal ± error bound for labels [22].

### 12.6 Hard "refer to a veterinarian" stops (no calculation shown)

| Trigger | Rationale |
| --- | --- |
| age < 8 weeks, orphan or hand-reared | neonatal energy 130-220 kcal/kg, milk replacers; outside evidence reviewed [13] |
| any `medical` flag, hospitalised, post-op, or on a prescription diet | section 8 (chronic flags give a reference-only calculation, acute flags a referral) |
| BCS ≤3/9 or MCS severe, or BCS 9 with any other sign | HR 4.67 at BCS 3 [19]; emaciation requires work-up; refeeding risk [28] |
| unintended weight change ≥5 % in 4 weeks, or any loss > 2 %/wk outside a weight-loss plan | disease signal; AAHA upper rate [5] |
| on a weight-loss plan: loss faster than 3 %/wk, or ≥ 8 % in 28 days, or a gain ≥ 5 % in 28 days | hepatic-lipidosis safety, above the AAHA 2 %/wk alert (X, D5) |
| verified intake of a weight-stable cat below $0.6 \times \mathrm{RER}(\mathrm{IBW})$ | a further cut would go below the floor; needs a work-up (X, D1) |
| not eating (anorexia) ≥ 24 h (cat on weight-loss plan or BCS ≥7) or ≥ 48 h (any cat) | HL risk; AAHA 72 h/≤1/3 RER tube trigger is the hospital limit [4]; the 24/48 h figures are X (conservative) |
| `repro` ≠ none (pregnant/lactating) | calculation shown as reference only, plus banner: lactation needs vary widely; queens usually cannot meet needs [13] |
| goal `lose` with kcal would fall below $0.6 \times \mathrm{RER}(\mathrm{IBW})$ | app referral policy (X), informed by AAHA's restriction risks [5, printed p. 8]; section 7.1 |
| kitten with adult weight unknown **and** age < 4 months | cannot apply NRC; show FEDIAF band only and ask |
| user/vet target differs from engine range by >30 % | show both, never overwrite; recommend vet confirmation |
| vomiting, diarrhoea, lethargy, straining to urinate, drinking/urinating more | any clinical sign → vet; (X, standard practice) |

---

## 13. Worked examples

All numbers recomputed to full precision; rounding at the last step only.

**A. 4 kg neutered indoor adult, BCS 5, typical lifestyle, maintain.**
$\text{start} = 75 \times 4^{0.67} = 189.9$ kcal/day (47 kcal/kg). Range $\times 0.85 / \times 1.15$ = **161-218 kcal** (161.4-218.3).
Reference band 131.6-253.2. RER = 198.0. If the cat is a sedentary tier: $63.5 \times 4^{0.67} = 160.8$. Comparators: AAHA $1.2 \times \mathrm{RER} = 237.6$; WSAVA 225-250.
Plan: weigh every 4 weeks (D8); if the 28-day change is ≤ −2 % choose +10 % (208.8), if it is ≥ +2 % choose −10 % (170.9).
Food check (wet food of 10.4, 99.2 kcal/100 g): 189.9 kcal = 191.3 g/day; protein $10 \times 1.913 = 19.1$ g/day = 100.8 g/1000 kcal ≥ 83.3
($k_{\text{actual}} = 75$) OK. Carbohydrate 16.9 % ME (information only).

**B. 6 kg cat, BCS 8/9, weight loss.**
$\mathrm{IBW} = 6 / (1 + 0.10 \times 3) = 4.615$ kg (method B: 4.61 kg; BCS-4 target alternative 4.05 kg), shown as 4.2-5.1 kg (±10 %) and stored as
an estimate when the owner adopts the plan (D3). $\mathrm{RER}(\mathrm{IBW}) = 70 \times 4.615^{0.75} = 220.4$; floor $0.6 \times 220.4 = 132.3$ (28.7 kcal/kg IBW).

| Tier at IBW | $\mathrm{MER}(k, \mathrm{IBW})$ | start | kcal/kg IBW | range | min protein (g/1000 kcal) |
| --- | ---: | ---: | ---: | --- | ---: |
| typical, $k = 75$ (neutered default) | 209.0 | **$0.8 \times 209.0 = 167.2$** | 36.2 | 146.3-188.1 | 104.2 |
| sedentary, $k = 63.5$ | 176.9 | **$0.8 \times 176.9 = 141.5$** | 30.7 | 132.3 (floor)-159.2 | 123.0 |
| active, $k = 100$ | 278.6 | **$0.8 \times 220.4 = 176.3$** (RER bound) | 38.2 | 154.3-198.4 | 98.8 |

With a verified intake of 200 kcal: start 160.0; of 150 kcal: start 132.3 (floor, since $0.8 \times 150 = 120$); of 120 kcal (< floor): refer.
The previous rule ($0.8 \times \mathrm{RER}(\mathrm{IBW}) = 176.3$ for every tier) gave the sedentary cat 99.7 % of its own maintenance at the ideal weight.
Expected loss: 0.5-1 % of initial BW per week = 30-60 g/week, so the 1.38 kg to IBW take about **23-46 weeks**. The engine's rate is in % of the
current (window-mean) weight, which shrinks as the cat loses: at 0.5-1 % of current weight per week the same loss takes about **26-52 weeks**
($\ln(6 / 4.615) / {-\ln(1 - r)}$). Above 2 %/wk (120 g/week at 6 kg) the engine suggests +10 %; faster than 3 %/wk (180 g/week) it refers.
Protein, typical tier: FEDIAF scaling $k_{\text{actual}} = 167.2 / 4.615^{0.67} = 60.0$ → ≥ 104.2 g/1000 kcal; plus ≥5 g/kg IBW = 23.1 g/day = **138.0 g/1000 kcal**.
The wet food (100.8 g/1000 kcal) would give 168.4 g food and 16.8 g protein/day (3.6 g/kg IBW): fails both; recommend a veterinary weight-loss diet.
Treats ≤10 % (16.7 kcal). Re-check every 2 weeks; reassess the stored IBW with the veterinarian when BCS reaches 6 or 5.
(The repo's sample 220 kcal equals $\mathrm{RER}(4.6) = 219.9$, i.e. 100 % rather than 80 % of ideal-weight RER if IBW is 4.6 kg.)

**C. 4-month kitten, 2.0 kg, expected adult 4.0 kg, intact.**
$p = 0.5$; $f = 1.674$; $\mathrm{ME} = 100 \times 2^{0.67} \times 1.674 = 266.3$ kcal/day (133 kcal/kg); $t = 0$. FEDIAF band at 4.0 months (interpolated
multipliers 1.889 and 2.278): $1.889 \times 75 \times 2^{0.67}$ to $2.278 \times 100 \times 2^{0.67}$ = 225.4-362.4. AAHA $2.5 \times \mathrm{RER} = 294.3$ (not binding).
Start 266.3; range 225.4-362.4 shown as a band; adjust by weekly weight (about 100 g/week) and BCS 4-5. Without the adult weight: start 293.9 (band midpoint).
Food: ≥ 4.0 kcal/g DM, protein ≥ 70 g/1000 kcal (growth), Ca:P 1:1 to 1.5:1 [1][12].

**C2. 11-month kitten, 3.4 kg, expected adult 4.0 kg, neutered, typical tier (transition from age).**
$p = 0.85$ → weight term $(0.85 - 0.8) / 0.2 = 0.25$; age term $(11 - 10) / 2 = 0.5$; $t = 0.5$. NRC 291.4; adult $\mathrm{MER}(75, 3.4) = 170.3$.
$\text{start} = 0.5 \times 291.4 + 0.5 \times 170.3 = 230.9$ kcal/day (68 kcal/kg). Band (flat after 10.5 months, $1.5\times$) 255.4-340.6; adult range
$[0.85, 1.15] \times 170.3$ = 144.7-195.8. Range = $[\min(207.8, 255.4, 144.7),\ \max(253.9, 340.6, 195.8)]$ = **144.7-340.6**; note `kitten-transition`.
Without the adult weight: $\text{mid} = 298.0$, start $0.5 \times 298.0 + 0.5 \times 170.3 = 234.1$. For unchanged maintenance inputs and BCS 5, the raw start approaches the adult value 170.3 at 12 months. Adult goal/ideal-weight rules can change the result at the age boundary.

**C3. 9-month kitten, 3.6 kg, expected adult 4.0 kg, neutered (transition from weight).**
$p = 0.9$ → $t = 0.5$ (age term 0). NRC 290.2; adult $\mathrm{MER}(75, 3.6) = 176.9$; start 233.5; band at 9 months (multipliers 1.594 and 1.688)
282.0-398.1; range 150.4-398.1. At 4.0 kg before 12 months the cat remains a kitten and is referred for growth/weight reassessment, with no energy estimate (D9).

**D. Lactating queen, 4 kg, 4 kittens, week 4.**
$\mathrm{ME} = 100 \times 4^{0.67} + 60 \times 4 \times 1.2 = 253.15 + 288 = 541.2$ kcal/day (135 kcal/kg). Week 6: 493; week 7: 445. AAHA $2.0\text{–}6.0 \times \mathrm{RER}$ (396-1188). Status: reference-only (not the no-number refer status); free-choice feeding of
a growth/reproduction diet; weigh the queen weekly; wean kittens from 4-6 weeks. Protein ≥ 75 g/1000 kcal (reproduction).

**E. Gestation (4 kg queen).** $140 \times 4^{0.67} = 354.4$ kcal/day, introduced gradually (about 10 %/wk from early pregnancy) [13].

---

## 14. Discrepancies between the repo documents and the evidence

1. `CALCULATIONS.md` states RER = $70 \times \mathrm{BW}^{0.75}$ as the only physiology: correct and consistent with AAHA/Merck/WSAVA. However, the Merck page it links also
   offers the linear equation, which is **not valid below 2 kg or for cats per AAHA 2014**; do not add it for cats.
2. The doc says RER "is a starting reference, not synonymous with maintenance intake": correct (AAHA: RER is the base, not MER). Missing: the **0.67** allometric exponent
   that FEDIAF and NRC use for cat maintenance (FEDIAF: 0.67 "has recently been confirmed to be more accurate than 0.75"); the engine uses 0.75 only for RER-based plans.
3. The linked Merck page gives **MER factors** (neutered $1.2 \times \mathrm{RER}$, intact 1.4, obesity-prone 1.0, kitten 2.5). For a 4 kg neutered cat $1.2 \times \mathrm{RER}$ (238 kcal) is 25 % higher than
   FEDIAF 189.9 kcal and the AAHA box range 1.2-1.4. The engine should state which of these is used and show the others as a reference.
4. The sample "weight-loss cat, 6 kg, 220 kcal target" is 82 % of **current-weight** RER (268.4) – but AAHA bases $0.8 \times \mathrm{RER}$ on **ideal** weight, so for a BCS 8 cat (IBW about
   4.6 kg) 220 kcal is **100 %** of ideal RER, 25 % above AAHA's starting energy (176) and 32 % above the engine's typical-tier start (167). For a BCS 6/7 cat of 6 kg (IBW 5.5/5.0) it would be
   $0.88\text{–}0.94 \times \mathrm{RER}(\mathrm{IBW})$. The sample is explicitly labelled an assumption, so no change is required, but any engine-generated weight-loss target must use IBW.
5. Sample "maintenance cat 5.5 kg, 270 kcal": FEDIAF neutered 235 kcal (115 %); NRC active 313; inside the literature band, no problem. "Weight-gain cat 4.2 kg, 270 kcal": 270/196 = 138 % of FEDIAF neutered MER;
   a gain plan per section 7.3 would be 216-235 kcal; sample is outside but plausible for an underweight cat – the engine should flag BCS <4.
6. The 10 % "general guidance": correct, from AAHA 2014/2021. The doc cites the AAHA prevention page [AAHA] for it; the 2021 PDF text is the primary location (page 158). The app counts
   complementary foods toward the 10 % limit: consistent with AAHA's "complete and balanced food ≥90 %".
7. Label uncertainty should be explained without treating study-average prediction errors as a universal ±6-8 % bound (corrected in the follow-up audit; [22]).
8. Validation bounds: nothing in the evidence contradicts 0.1-40 kg and 1-3,000 kcal limits; kcal/g 0.01-10 is fine (dry cat food about 3.5-4.5 kcal/g, wet about 0.7-1.2). Not a clinical range (existing statement is right).
9. The brief for this addendum referred to the 2018 feeding consensus as "AAFP/ISFM". It is an **AAFP** consensus statement (Sadek et al., JFMS 2018) [38]. Also, no AAFP/ISFM weight-management guideline was found; the 2014 weight-management
   guideline is AAHA's (Brooks et al.) endorsed by AAFP.

---

## 15. What I could not verify

* The NRC 2006 chapter text itself (OpenBook blocks it). Growth equation $6.7 \times (e^{-0.189p} - 0.66)$, $100 \times \mathrm{BW}^{0.67}$, $130 \times \mathrm{BW}^{0.4}$ were checked through secondary reproductions; the kitten expression is additionally corroborated by a primary study [40] and the numeric cross-check in 3.1. The NRC chapter itself remains unread.
* Whether FEDIAF's "times MER" for kittens uses $k = 75$ or $100$ (or an unspecified MER); which body weight FEDIAF uses for gestation and lactation.
* Resolved in the follow-up audit: AAHA 2014 printed page 8 contains the 60 %-of-RER guidance and the 10-20 % reduction step. Their clinical context remains essential (section 7.1).
* Full AAHA 2021 JAAHA DOI was relayed by a search result (10.5326/JAAHA-MS-7232); the PDF I read confirms the content.
* Resolved in the follow-up audit: AAHA 2026 section 8 was accessible and its dietary guidance checked [34]; iCatCare 2025 numbers were read via a copy of the full text by a subagent (the ≤12 % ME carbohydrate threshold was confirmed in the 2026-10-09 audit [39]).
* Laflamme 1997 original; Hawthorne & Butterwick 2000 original and the exact divisor (0.7067 quoted vs 0.7062 recalled); "German and Martin" BF equation; any published validation of the mass-balance IBW method and DXA-based IBW errors.
* Remillard 2001, Walton 2001, Chan, Brenner 2011, ACVECC/WSAVA refeeding statements; thiamine and electrolyte doses.
* Xenoulis 2016 hyperlipidaemia; IBD/hypoallergenic diet primary evidence; Cupp 2004; Armstrong/Lund 1996; Kruger FLUTD wet-food paper; hairball/starch digestibility; typical wet cat food composition ranges.
* AAFCO 2023 profile numbers (adult 26 % DM, 65 g/1000 kcal etc. come from Merck, secondary).
* Cat kitchen scale vs baby scale accuracy; evidence-based feeding frequency numbers.
* Consumer-grade accuracy of owner-entered BCS (only clinician inter-observer CVs found).
* Early-age neutering energy effects beyond Root 1996/Hand; any energy factor for neutered kittens.
* Any evidence for the shape or timing of the kitten-to-adult energy transition (D4 is an engineering choice).
* No 2024-2026 owner-intake study that supersedes FEDIAF 2025 was found; a 2026 Belgian label study (Menniti) showed 79-91 % of label recommendations fall within the FEDIAF band, with wet food for 3 kg cats 19 % above and neutered/indoor products 17-24 % above the reference [27].

(Resolved in the 2026-10-09 audit: the FEDIAF protein column assignment, growth 70 and reproduction 75 g/1000 kcal, confirmed in FEDIAF 2025 Table III-4b [1].)

---

## 16. Model revisions after the 2026-10-09 audit

An independent audit recomputed every number in this document and the engine contract. This section records what changed
and why. Section 16.1 lists corrections of text and arithmetic; section 16.2 lists the model decisions, approved by the owner,
that change the engine. `docs/ENGINE.md` contains the normative rules.

### 16.1 Corrections

| # | Where | Was | Now |
| --- | --- | --- | --- |
| 1 | 3.1 Vecchiato reproduction, 2.35 kg | 278 | 279.0 (and 180.6, 291.6; back-solved adult weight 3.89-4.04 kg) |
| 2 | 2.2 $130 \times 4^{0.4}$ | 226.4 | 226.3 |
| 3 | 13 B time to ideal weight | 23-46 weeks | 23-46 weeks for a rate in % of initial BW; 26-52 weeks for the engine's rate in % of current weight |
| 4 | 14 item 4 | $0.8\text{–}0.9 \times \mathrm{RER}(\mathrm{IBW})$ | $0.88\text{–}0.94 \times \mathrm{RER}(\mathrm{IBW})$ |
| 5 | 3.4 Laflamme quadratic minimum | near 11.5 y | 11.6 y |
| 6 | 3 life stages | "senior 10 years and older" next to "mature adult 7-10" | mature adult 7-10 completed years, senior from 11 completed years (older than 10) |
| 7 | 3.4 senior protein check | "100 kcal tier minimum, 83.3 g/1000 kcal" | 83.3 g/1000 kcal is the 75-kcal tier minimum |
| 8 | 13 A adjustment rule | weight falls > 1 % | ±2 % change over 28 days, as in the engine |
| 9 | 2.2 FEDIAF per-kg values | 35-45 kcal/kg | printed 35-45; the coefficients give 32.9-47.5 (FEDIAF's own rounding/inconsistency) |
| 10 | 3.1 kitten range | range "clipped to $\le 2.5 \times \mathrm{RER}$" while the example showed 239-398 with a cap of 294 | the cap applies to the start only, in both kitten paths; the range high is not capped |
| 11 | 7.1 verified intake | "use the higher of $0.8 \times \mathrm{RER}(\mathrm{IBW})$ and $0.8 \times$ intake" | withdrawn; replaced by D1 |
| 12 | 7.1, 12.6 floor wording | AAHA 2014 "as low as 60 % of RER" quoted as verified | marked UNVERIFIED; Hoelmkjaer HL case at about 30 kcal/kg target BW added; floor kept |
| 13 | 9.2 FEDIAF protein | growth/reproduction assignment inferred | confirmed: growth 70, reproduction 75 g/1000 kcal (Table III-4b) |
| 14 | 10.4 carbohydrate definitions | carb g/100 kcal labelled Atwater, engine used 4-step; carb %ME had two bases | carb %ME on Atwater basis in numerator and denominator; carb g per 100 kcal of 4-step ME (D6) |
| 15 | 10.4, 13 A wet-food ME | 99.3 kcal/100 g | 99.2 (99.2455 rounds down) |

### 16.2 Model decisions

**D1. Weight-loss start (X on top of AAHA G).**
*Problem:* $0.8 \times \mathrm{RER}(\mathrm{IBW})$ can be at or above maintenance for sedentary cats.
*Numbers:* $0.8 \times \mathrm{RER}(\mathrm{IBW}) / \mathrm{MER}(k, \mathrm{IBW}) = (56 / k) \times \mathrm{IBW}^{0.08}$, which is ≥ 1 for $k = 63.5$ at
$\mathrm{IBW} \ge (63.5 / 56)^{12.5} = 4.81$ kg (for $k = 75$ only at 38.5 kg). At IBW 4.615 kg the old start, 176.3 kcal, was 99.7 % of sedentary maintenance (176.9).
The old verified-intake rule (the higher of the two figures) gave a cat that holds its weight on 150 kcal a start of 176.3.
*Decision:* $\text{start} = \max\big(\text{floor}, 0.8 \times \min(\mathrm{RER}(\mathrm{IBW}), \mathrm{MER}(k, \mathrm{IBW}))\big)$, i.e. 80 % of the lower of the
inactive-maintenance anchor and the cat's own tier at ideal weight. With a verified intake $V$: $\max(\text{floor}, 0.8 \times V)$ (AAHA option 1);
$V < \text{floor}$ → refer (`verified-intake-below-floor`). Range $[\max(\text{floor}, 0.875 \times \text{start}), 1.125 \times \text{start}]$; floor
$0.6 \times \mathrm{RER}(\mathrm{IBW})$. For the 6 kg BCS 8 cat: typical 167.2 (−5.2 % vs 176.3), sedentary 141.5, active 176.3 (unchanged).
*Caveat:* the sedentary start (30.7 kcal/kg IBW) is near the Hoelmkjaer HL case (about 30 kcal/kg); the floor (28.7 kcal/kg) stays the hard minimum.

**D2. Weight used (X).**
*Problem:* the maintenance and gain equations used IBW only when BCS ≥ 6, while weight loss used any IBW below BW. A cat with a
veterinary IBW below its weight but an owner-scored BCS of 5 was maintained at its current weight.
*Numbers:* BW 5.0 kg, vet IBW 4.5 kg, typical tier: maintenance 220.5 kcal at BW versus 205.5 at IBW (−6.8 %), while loss used 4.5 kg (164.4).
*Decision:* $W = \mathrm{IBW}$ whenever $\mathrm{IBW} < \mathrm{BW}$, whatever the IBW source, else $\mathrm{BW}$; for maintain and gain as well as loss.

**D3. Ideal weight persists (X).**
*Problem:* the BCS-derived IBW was recomputed from every new BCS. As a cat loses weight and its BCS falls, the estimate drifts and the
loss end point moves; a single optimistic BCS changes the start.
*Numbers:* 6 kg at BCS 8 → IBW 4.615; after losing to 5.4 kg, BCS 7 gives 4.50 kg and BCS 6 gives 4.91 kg, so the typical start jumps between
164.4 and 174.2 kcal although nothing about the cat's lean mass changed.
*Decision:* the profile stores `idealWeightKg` with `idealWeightSource` (`veterinarian` | `estimate` | null). A stored value is used as-is
(range ±0 for veterinarian, ±10 % for estimate). Only when it is empty is IBW re-derived from the effective BCS. The UI stores the BCS-derived IBW as
`estimate` when the owner adopts a weight-loss estimate and offers "re-estimate from BCS" (clears it). Documents written before the field existed:
`veterinarian` if `idealWeightKg` is set, else null. The current weight is `weightKg`, which the UI keeps in sync with the newest weigh-in.

**D4. Kitten transition (X).**
*Problem:* the kitten start dropped by a third at the first birthday.
*Numbers:* $f(1) = 1.124$, so near adult weight the NRC start is $112.4 \times \mathrm{BW}^{0.67}$; a neutered adult gets $75 \times \mathrm{BW}^{0.67}$ (−33 %),
an intact one $100 \times \mathrm{BW}^{0.67}$ (−11 %). Example: 3.8 kg kitten of a 4.0 kg adult at 11.9 months: 287.9 kcal, at 12.0 months (neutered) 183.4 (−36 %).
The FEDIAF band also stepped at 4 and 9 months.
*Decision:* blend the growth start into $\mathrm{MER}(k_A, \mathrm{BW})$ with $t = \operatorname{clamp}(\max((p - 0.8) / 0.2, (m - 10) / 2), 0, 1)$ (age term only when the adult
weight is unknown); interpolate the band multipliers between band centres (2, 6.5, 10.5 months); cap the start only at $2.5 \times \mathrm{RER}(\mathrm{BW})$;
include the adult range $[0.85, 1.15] \times \mathrm{MER}(k_A, \mathrm{BW})$ once $t > 0$; end the kitten stage at 12 months. The original earlier promotion at expected adult weight is withdrawn by D9.
No separate neutered-kitten factor: no kitten-specific evidence was found, and the adult tier inside the blend already reflects neuter status.
The age term reflects skeletal maturity and adult weight at about 10 months [12]; the weight term mirrors the 80 % of adult size around 30 weeks [12].

**D5. Trend (X).**
*Problem:* the plateau and "not gaining" rules needed a window span of 28 days inside a 28-day window, i.e. a weigh-in exactly 28 days before
the latest; a fortnightly schedule that slips by one day never reaches it. And a weight-loss plan had no referral for loss that is too fast.
*Numbers:* 21 days leaves a 7-day tolerance (any weigh-in 21-28 days back). −8 % over 28 days is about −2.1 %/wk compounded, i.e. just above the AAHA 2 %/wk alert;
3 %/wk is 180 g/week for a 6 kg cat.
*Decision:* plateau and gain-stalled minimum span 21 days; new loss-goal stop `rapid-weight-change` when $r < -3$ %/wk or $c_{28} \le -8\ \%$
(X: above the AAHA 2 %/wk alert, for hepatic-lipidosis safety). All other trend rules are unchanged (ENGINE.md §6 restates the table).

**D6. Nutrition (X on FEDIAF/iCatCare G).**
*Problem:* the carbohydrate share of a cat's diet divided Atwater carbohydrate energy by 4-step or label energy (wet example 15.9 %), while the food card
showed the Atwater share (16.9 %); `carb g/100 kcal` was labelled Atwater but computed on 4-step ME; kittens got the reproduction protein minimum 75 instead of the
growth minimum 70; CKD cats on renal diets got a "below minimum" protein warning; the checks also ran on unusable estimates.
*Decision:* carbohydrate % ME $= 3.5\,\mathrm{NFE} / \mathrm{ME}_a \times 100$ everywhere, gram-weighted per cat; the food card shares stay Atwater-normalised;
$\text{carbGPer100kcal} = \mathrm{NFE} / \mathrm{ME}_4 \times 100$ labelled "per 100 kcal metabolisable energy (4-step)"; protein minimum kitten 70, gestation/lactation 75,
otherwise $\max(62.5, 6250 / (\text{kcal} / W^{0.67}))$; no `protein-below-minimum` for CKD (note `ckd-protein-vet`); nutrition checks only for status ok or
reference-only (otherwise not applicable); the 5 g/kg-IBW warning only for the `weight-loss-aaha` equation.

**D7. Adult cap (X).**
The raw adult maintenance start is capped at $1.4 \times \mathrm{RER}(\mathrm{BW})$ (the top of AAHA's neutered range). It is a guard, not a model term:
$100 \times w^{0.67} > 1.4 \times 70 \times w^{0.75}$ only for $w < 0.98^{-12.5} = 1.29$ kg, so it binds only for very small active cats. The floor is applied afterwards and overrides this cap if they conflict; the maintenance/gain floor extension is unvalidated (section 7.1).

**D8. Default weigh-in cadence (X; Claude review, 2026-10-09).**
*Problem:* the trend window is 28 days (12.4), but the default reminder for maintenance cats was every 30 days. An owner who
follows the reminder never has two weigh-ins inside the window, so $r$, $c_{28}$, every maintenance suggestion and the
`rapid-weight-change` safety stop never exist for that cat. Gain plans used the same 30 days although 7.3 asks for a review in 2 weeks.
*Numbers:* with weigh-ins on days 0 and 30 the window holds one entry; the maintenance rule ($\lvert c_{28} \rvert \ge 2\ \%$) and the
referral ($\ge 5\ \%$) can only fire if the owner weighs more often than asked.
*Decision:* keep the clinical cadences and count them in weeks, as AAHA does: maintenance every 4 weeks (28 days, "monthly"), which the
inclusive 28-day window accepts exactly; gain plans every 2 weeks like every other active plan (AAHA rechecks every 2 weeks, 7.2 and 7.3).
Kitten (7) and recently neutered (14) cadences are unchanged. No threshold and no target changes. A weigh-in later than 28 days after the
previous one skips that one comparison; the next on-time weigh-in restores the trend. A cadence of 21 days would add slack but is not
what the sources recommend, so it was not chosen.

**D9. Expected adult weight is not maturity (X; source review, 2026-10-09).**
AAHA defines the kitten stage through the first year [10] and recommends growth diets through skeletal maturity,
typically about one year [41]. An owner-estimated mass cannot establish maturity. Previously an 8-month, 4 kg kitten
with expected adult weight 4 kg became an adult; selecting loss at BCS 8 enabled the adult restriction equation.
The stage now stays kitten until 12 months. At or above the entered expected adult weight it returns
`refer` / `kitten-adult-weight-reached`, without a calorie estimate, adult trend suggestion or adult nutrient check.
The referral asks for growth/weight reassessment and retains growth-diet advice. This exact referral trigger is an
app policy, not a guideline threshold. Below that weight, the existing blend is unchanged and remains unvalidated.

**D10. Food warnings use delivered energy (arithmetic contract, 2026-10-09).**
Balance-food warning checks now use whole-gram delivered energy, matching the nutrient checks. With a 190 kcal
target and 189.6 kcal fixed food, balance at 1 kcal/g rounds from 0.4 g to 0 g and raises no food warning.
With a 199 kcal target and 179.4 kcal fixed food, complementary balance rounds from 19.6 g to 20 g: 20 kcal
exceeds 10 % of the target (19.9 kcal), so the extras warning must fire. The allocation itself is unchanged.

### 16.3 Follow-up correctness audit (Codex, 2026-10-09)

- Independently recomputed CALCULATIONS.md's Luna allocation, the README household, food-analysis
  examples and section 13 A–E. The numeric examples agree at their displayed precision. Section 13 B
  now says **above** 2 %/week, matching the strict comparison; D correctly calls lactation reference-only.
- Fixed the gain interval when a high stored ideal weight makes the floor exceed the raw high bound:
  all three values now respect the floor. Example: BW 4 kg, IBW 8 kg, BCS 4, sedentary gives floor
  199.79 kcal; the old high was 192.90. Both engines now return an ordered interval.
- A maintenance/gain reduction below the floor previously became a larger target labelled “decrease”.
  All three goals now refer when the proposed 10 % reduction crosses the floor. This extends the
  existing loss-goal rule; no target changes automatically.
- Formula cards now include the operative floor clamps and verified-intake alternative. The web
  evidence labels identify the model choices in maintenance, weight loss and kitten transition.
- The primary-source checks resolved AAHA floor wording and the newer diabetes guidance, and
  corroborated the kitten equation transcription. FEDIAF's prepared/fresh food equations, adult
  coefficients, reproduction equations and protein scaling were cross-checked against [1].
- The minimum-of-RER-and-MER loss rule, interpolated kitten bands and transition timing remain
  **unvalidated app choices**, not published AAHA/NRC equations. Reaching an owner-estimated adult
  weight does not itself establish biological maturity; D4 requires veterinary review; D9 above removes the early adult-goal eligibility. Arithmetic tests cannot establish clinical safety.

---

## 17. References

Identifier status: "opened" = I (or a subagent) read the cited page or file in this session; "relayed" = a subagent supplied the identifier and I did not open it.

1. FEDIAF. *Nutritional Guidelines for Complete and Complementary Pet Food for Cats and Dogs*. September 2025. https://europeanpetfood.org/wp-content/uploads/2025/09/FEDIAF-Nutritional-Guidelines_2025-ONLINE.pdf (opened, text extracted; Table III-4b protein minima, growth 70 and reproduction 75 g/1000 kcal, confirmed in the 2026-10-09 audit). The 2024 edition is at https://europeanpetfood.org/wp-content/uploads/2024/09/FEDIAF-Nutritional-Guidelines_2024.pdf (listed, not opened).
2. National Research Council. *Nutrient Requirements of Dogs and Cats*. National Academies Press, 2006. https://nap.nationalacademies.org/read/10668 (page opened; text not accessible).
3. Bermingham EN, Thomas DG, Morris PJ, Hawthorne AJ. Energy requirements of adult cats. *Br J Nutr* 2010;103(8):1083-1093. doi:10.1017/S000711450999290X (opened; full text via subagent).
4. Cline MG, Burns KM, Coe JB, Downing R, Durzi T, Murphy M, Parker V. 2021 AAHA Nutrition and Weight Management Guidelines for Dogs and Cats. *J Am Anim Hosp Assoc* 2021;57(4):153-178. doi:10.5326/JAAHA-MS-7232 (DOI relayed). PDF opened: https://www.canadianveterinarians.net/media/iuqg3rfp/cline-2021-aaha-nutrition-and-weight-management-guidelines-for-dogs-and-cats-jaaha-2021.pdf (weight-loss intake 52 ± 4.9 kcal/kg^0.711 confirmed in the 2026-10-09 audit).
5. Brooks D, Churchill J, Fein K, Linder D, Michel KE, Tudor K, Ward E, Witzel A. 2014 AAHA Weight Management Guidelines for Dogs and Cats. *J Am Anim Hosp Assoc* 2014;50(1):1-11. https://www.aaha.org/wp-content/uploads/globalassets/02-guidelines/weight-management/2014-AAHA-Weight-Management-Guidelines-for-Dogs-and-Cats (primary PDF opened in the follow-up audit; printed p. 8 confirms the floor context and reduction step).
6. AAHA. Box 1: Energy Requirement Calculations (2021 Nutrition and Weight Management Guidelines). http://www.aaha.org/wp-content/uploads/globalassets/02-guidelines/2021-nutrition-and-weight-management/resourcepdfs/nutritiongl_box1.pdf (opened).
7. WSAVA. Calorie Needs for an Average Healthy Adult Cat in Ideal Body Condition (updated July 2020). https://wsava.org/wp-content/uploads/2020/07/Calorie-Needs-for-Healthy-Adult-Cats-updated-July-2020.pdf (opened).
8. WSAVA Nutritional Assessment Guidelines Task Force. WSAVA Nutritional Assessment Guidelines. *J Feline Med Surg* 2011;13(7):516-525. doi:10.1016/j.jfms.2011.05.009 (relayed); also *J Small Anim Pract* 2011;52(7):385-396. https://wsava.org/global-guidelines/global-nutrition-guidelines/ (listed).
9. Merck Veterinary Manual. Nutritional Requirements of Small Animals. https://www.merckvetmanual.com/management-and-nutrition/nutrition-small-animals/nutritional-requirements-of-small-animals (opened). 9b: Merck Veterinary Manual, nutrition in hepatic disease (relayed by subagent, secondary).
10. Quimby J, Gowland S, Carney HC, DePorter T, Plummer P, Westropp J. 2021 AAHA/AAFP Feline Life Stage Guidelines. *J Feline Med Surg* 2021;23:211-233. doi:10.1177/1098612X21993657. Full primary PDF: https://www.aaha.org/aaha-guidelines/2021-aaha-aafp-feline-life-stage-guidelines/ (read in source review; printed pp. 53 and 63 for stages and kitten nutrition; author list confirmed).
11. Bjornvad CR, Nielsen DH, Armstrong PJ, et al. Evaluation of a nine-point body condition scoring system in physically inactive pet cats. *Am J Vet Res* 2011;72:433-437. doi:10.2460/ajvr.72.4.433. 11b: Sadek T, Hamper B, Horwitz D, Rodan I, Rowe E, Sundahl E. Feline feeding programs: addressing behavioural needs to improve feline health and wellbeing. *J Feline Med Surg* 2018;20(11):1049-1055. doi:10.1177/1098612X18791877 (opened; see also ref 38).
12. Gross KL, Becvarova I, Debraekeleer J. Feeding growing kittens: postweaning to adulthood. In: Hand MS, et al. *Small Animal Clinical Nutrition*, 5th ed., ch. 24, p. 429-. https://s3.amazonaws.com/mmi_sacn5/2019/SACN5_24.pdf (opened).
13. Fontaine E. Food intake and nutrition during pregnancy, lactation and weaning in the dam and offspring. *Reprod Domest Anim* 2012;47(Suppl 6):326-330. doi:10.1111/rda.12102 (opened). 13b: Hoelmkjaer KM, Bjornvad CR. Management of obesity in cats. *Vet Med Res Rep* 2014;5. doi:10.2147/VMRR.S40869; also https://pmc.ncbi.nlm.nih.gov/articles/PMC7337193/ (opened; hepatic-lipidosis case at about 30 kcal/kg target BW confirmed in the 2026-10-09 audit).
14. Neutering studies: Fettman MJ et al. *Res Vet Sci* 1997;62:131-136, https://pubmed.ncbi.nlm.nih.gov/9243711/ ; Kanchuk ML, Backus RC, et al. *J Nutr* 2003;133:1866-1874, doi:10.1093/jn/133.6.1866 ; Root MV, Johnston SD, Olson PN. *Am J Vet Res* 1996;57:371-374, https://pubmed.ncbi.nlm.nih.gov/8669771/ ; Hoenig M, Ferguson DC. *Am J Vet Res* 2002;63:634-639 (no identifier captured) ; Harper EJ et al. *J Small Anim Pract* 2001;42:433-438 (no identifier captured) ; Belsito KR et al. *J Anim Sci* 2009;87:594-602 (no identifier captured). All via subagent PubMed lookups (relayed).
15. Laflamme DP. Development and validation of a body condition score system for cats: a clinical tool. *Feline Pract* 1997;25:13-18 (not opened; no DOI).
16. Laflamme DP, Hannah SS. Discrepancy between use of lean body mass or nitrogen balance to determine protein requirements for adult cats. *J Feline Med Surg* 2013;15(8):691-697 (opened by subagent; no DOI captured).
17. Poblanno Silva FM. *Energy requirements and feeding guidelines in cats: evaluating commercial label feeding directions and the 13C-bicarbonate method for measuring energy expenditure*. DVSc thesis, University of Guelph, 2025. https://atrium.lib.uoguelph.ca/bitstreams/7319d668-dbee-4a6d-aed6-049f37ff5a64/download (opened).
18. Laflamme DP. Nutrition for aging cats and dogs and the importance of body condition. *Vet Clin North Am Small Anim Pract* 2005;35:713-742. http://pawsoflife-org.k9handleracademy.com/Library/Health/Laflamme_2005.pdf (opened by subagent; title as recalled).
19. Further subagent-read sources (all relayed, identifiers as stated): Riond JL et al. *J Anim Physiol Anim Nutr* 2003;87:221-228; Wichert B et al. *ScientificWorldJournal* 2012, https://pubmed.ncbi.nlm.nih.gov/22623906/ ; Serisier S et al. *PLoS ONE* 2014;9:e96071; Harper EJ. *J Nutr* 1998;128:2623S-2635S; Teng KT et al. *J Feline Med Surg* 2018;20:1110-1118; Michel KE et al. *Br J Nutr* 2011;106(Suppl 1):S57-S59; Freeman LM et al. *Am J Vet Res* 2020;81:254-259. 19b: Slingerland LI et al. *Vet J* 2009;179:247-253; Öhlund M et al. *J Vet Intern Med* 2017;31:29; Rothlin-Zachrisson N et al. *J Vet Intern Med* 2023;37(1):58-69; Roomp K, Rand J. *J Feline Med Surg* 2009;11(8):668-682.
20. Hawthorne AJ, Butterwick RF. Predicting the body composition of cats: development of a zoometric measurement for estimation of percentage body fat in cats. *J Vet Intern Med* 2000;14:365 (abstract, original not opened). Formula as quoted in Iwazaki E, Mori A. *Animals* 2026;16:528. https://mdpi-res.com/d_attachment/animals/animals-16-00528/article_deploy/animals-16-00528.pdf (opened by subagent).
21. Hall JA, Melendez LD, Jewell DE. Using gross energy improves metabolizable energy predictive equations for pet foods whether or not they contain animal byproducts. *PLoS ONE* 2013;8(1):e54405. doi:10.1371/journal.pone.0054405.
22. Jewell DE, Jackson MI. Predictive equations for dietary energy are improved when independently developed for dry and wet food … *Front Vet Sci* 2023;10:1104695. doi:10.3389/fvets.2023.1104695. https://www.frontiersin.org/journals/veterinary-science/articles/10.3389/fvets.2023.1104695/full (primary methods and Table 4 checked; title abbreviated).
23. Armitage-Chan E, O'Toole T, Chan DL. Management of prolonged food deprivation, hypothermia, and refeeding syndrome in a cat. *J Vet Emerg Crit Care* 2006;16(2):S34-S41. doi:10.1111/j.1476-4431.2006.00132.x (not opened).
24. Hewson-Hughes AK et al. Geometric analysis of macronutrient selection in the adult domestic cat, *Felis catus*. *J Exp Biol* 2011;214:1039-1051. doi:10.1242/jeb.049429 (summary only).
25. Vecchiato CG et al. Case report: a case series linked to vitamin D excess in pet food: cholecalciferol (vitamin D3) toxicity observed in five cats. *Front Vet Sci* 2021;8:707741. doi:10.3389/fvets.2021.707741 (opened; used only for numerical cross-check).
26. Maintenance energy requirement determination of cats after spaying. PubMed 22005410 https://pubmed.ncbi.nlm.nih.gov/22005410/ (title seen in search; authors/journal not captured). Maintenance energy requirements in cats following controlled weight loss: an observational study. PubMed 34148606 https://pubmed.ncbi.nlm.nih.gov/34148606/ (title seen; authors/journal not captured).
27. Menniti MF, Dewulf A, Poblanno F, Witzel-Rollins A, Verbrugghe A, Hesta M. An investigation of feeding instructions on cat food labels in Belgium and comparison with European industry energy intake recommendations. *Vet Rec* 2026;199(2):e87-e97. doi:10.1002/vetr.70802 (opened).
28. Sumner C. Refeeding syndrome. MSPCA-Angell. https://www.mspca.org/clinical/refeeding-syndrome/ (opened by subagent).
29. Kidder AC. Management of the anorexic cat (proceedings). dvm360, 2010-11-01. https://www.dvm360.com/view/management-anorexic-cat-proceedings (opened by subagent).
30. Taylor S, Cannon M, Church D, Fleeman L, Fracassi F, Gilor C, Mott J, Niessen S. 2025 iCatCare consensus guidelines on the diagnosis and management of diabetes mellitus in cats. *J Feline Med Surg* 2025. doi:10.1177/1098612X251399103 (full text read by subagent from a copy); landing page https://www.rcvsknowledge.org/resource/2025-icatcare-consensus-guidelines-on-the-diagnosis-and-management-of-diabetes-mellitus-in-cats/ ; ≤12 % ME carbohydrate confirmed in the 2026-10-09 audit via ref 39.
31. International Renal Interest Society. Treatment recommendations for CKD in cats (2026). iris-kidney.com (PDF text read by subagent; exact URL not captured).
32. Sparkes AH, et al. ISFM consensus guidelines on the diagnosis and management of feline chronic kidney disease. *J Feline Med Surg* 2016;18(3):219-239. doi:10.1177/1098612X16631234 (read first half via PMC11148907); Ross SJ et al. *J Am Vet Med Assoc* 2006;229(6):949-957 (search summary only).
33. Carney HC, et al. 2016 AAFP guidelines for the management of feline hyperthyroidism (ISFM/AAFP). *J Feline Med Surg* 2016;18(5):400-416. doi:10.1177/1098612X16643252 (read via PMC11132203, ~80 %).
34. AAHA 2026 Diabetes Management Guidelines for Cats. https://www.aaha.org/resources/2026-aaha-diabetes-management-guidelines-for-cats/section-8-dietary-management/ (primary section opened in the follow-up audit).
35. Forman MA, et al. ACVIM consensus statement on pancreatitis in cats. *J Vet Intern Med* 2021;35:703-723. doi:10.1111/jvim.16053 (first ~40 % read via PMC7995362).
36. Lulich JP, et al. ACVIM small animal consensus recommendations on the treatment and prevention of uroliths in dogs and cats. *J Vet Intern Med* 2016;30(5):1564-1574. doi:10.1111/jvim.14559 (read by subagent).
37. German AJ, Holden SL, Mason SL, Bryner C, Bouldoires C, Morris PJ, Deboise M, Biourge V. Imprecision when using measuring cups to weigh out extruded dry kibbled food. *J Anim Physiol Anim Nutr* 2011;95(3):368-373. doi:10.1111/j.1439-0396.2010.01063.x. https://pubmed.ncbi.nlm.nih.gov/21039926/ (primary abstract read; confirms 12 studies and observed portion-error range).
38. AAFP. How to feed a cat: AAFP consensus statement on feline feeding programs and client brochure. https://catvets.com/wp-content/uploads/2024/08/2018-How-to-Feed.pdf (PDF listed; text not read). Primary paper: ref 11b.
39. ABVP. Summary of the 2025 iCatCare feline diabetes mellitus consensus guidelines, March 2026. https://abvp.com/wp-content/uploads/2026/02/2026-03-March-Feline-icc-DM.pdf (opened in the 2026-10-09 audit; used only to confirm the ≤12 % ME carbohydrate threshold of [30]; title inferred from the file name, verify).

40. Godfrey H, et al. Dietary choline in gonadectomized kittens improved food intake and body composition but not satiety, serum lipids, or energy expenditure. *PLOS ONE* 2022. https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0264321 (primary study; methods reproduce the NRC kitten energy expression; opened in the follow-up audit).

41. AAHA. Age-specific and Breed-specific Diets, 2021 Nutrition and Weight Management Guidelines. https://www.aaha.org/resources/2021-aaha-nutrition-and-weight-management-guidelines/age-specific-and-breed-specific-diets/ (opened; growth diets through skeletal maturity, typically about one year in cats).
