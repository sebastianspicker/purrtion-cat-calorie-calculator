# Engine contract, version 2

Normative specification for the schema v2 plan, the energy estimator, the food-analysis
calculator, the monitoring loop and nutrient checks. Both engines (TypeScript
`packages/core`, Swift `packages/swift-core`) implement exactly this. Evidence and sources
for every constant are in [SCIENCE.md](SCIENCE.md); section numbers in brackets such as
(§7.1) refer to it. The model decisions D1–D7 of the 2026-10-09 audit are explained in
SCIENCE.md §16. Allocation arithmetic (portions, rounding, activities) is in
[CALCULATIONS.md](CALCULATIONS.md).

**Principle (unchanged from v1):** the estimator suggests a starting point and a range. It
never writes `targetKcal`. A target changes only through an explicit user action ("Use
estimate", "Apply suggestion"), and a veterinarian-set target is never presented as
something to apply without talking to the veterinarian first.

All constants below live in `shared/energy-model.json` and are generated into both engines
(see "Single source of constants"). Code must not repeat literal coefficients.

Notation: $\mathrm{BW}$ is `cat.weightKg` (kg), $\mathrm{IBW}$ the ideal weight of §3.2 step 5,
$W$ the weight used by an equation, $k$ a maintenance coefficient. Formulas are written in
GitHub math; code identifiers are in backticks.

---

## 1. Schema v2

`schemaVersion: 2`. Decoders accept v1 and v2; v1 is migrated (section 9). Export is always
v2. Nullable fields: decoders accept a missing key or `null`; the TypeScript exporter writes
explicit `null`.

### Food

| Field | Type | Rules |
| --- | --- | --- |
| `id`, `name`, `note` | as v1 | |
| `type` | `wet` \| `dry` | describes the product; no longer restricts where it may be used |
| `energyPerUnit` | number \| null | null only when `energySource = analysis` |
| `energyUnit` | as v1 | display/input unit; also used to show the computed value |
| `energySource` | `label` \| `estimate` \| `analysis` | `analysis`: energy is computed from `analysis` (§4) |
| `completeness` | as v1 | |
| `lifeStageClaim` | `adult` \| `growth` \| `all` \| `unknown` | owner attestation from the label |
| `analysis` | Analysis \| null | required when `energySource = analysis` |

Analysis (percent **as fed**, the EU "analytical constituents" declaration):

| Field | Type | Rules |
| --- | --- | --- |
| `protein`, `fat`, `fibre`, `ash` | number | 0–100 |
| `moisture` | number \| null | 0–100. `null` allowed only for `type = dry` (EU labels need not declare moisture ≤ 14 %); the engine then assumes `defaults.assumedDryMoisture` (8) and emits `assumed-moisture` |
| `kind` | `prepared` \| `fresh` | `fresh` = raw/fresh meat products (BARF), uses the fresh-food equation |

Validation: the sum of the five constituents (with assumed moisture) ≤ 100 (tolerance 1e-9).
The computed density must still be within 0.01–10 kcal/g.

### Meal (fixed portion)

As v1, but `foodId` may reference **any** food (wet or dry). Grams are the amount actually eaten.

### Cat

| Field | Type | Rules |
| --- | --- | --- |
| `id`, `name`, `weightKg`, `goal`, `targetKcal`, `targetSource`, `extraKcal`, `meals` | as v1 | |
| `balanceFoodId` | string | replaces `dryFoodId`; any food. The remaining budget is fed as this food |
| `icon` | `moon` \| `scale` \| `dango` \| `stripes` \| `bolt` \| `paw` \| `fish` \| `yarn` \| `star` \| `heart` \| `leaf` \| `bow` \| null | optional picture, display only (names in `icon.*` messages); missing decodes as null, v1 migration sets null |
| `profile` | Profile | |
| `weightLog` | WeightEntry[] | 0–1000 entries, unique `id` |

**Current weight.** The engine always uses `cat.weightKg` as $\mathrm{BW}$; it never reads the
weight log for the current weight. The UI keeps `weightKg` in sync with the newest weigh-in:
when the owner adds or edits a weight-log entry whose date is on or after the date of every
other entry, the UI sets `weightKg` to that entry's `weightKg`. Editing `weightKg` directly does
not create a log entry.

Profile:

| Field | Type | Rules |
| --- | --- | --- |
| `birthDate` | `YYYY-MM-DD` \| null | valid calendar date |
| `approxAgeYears` | number \| null | 0–30; used only when `birthDate` is null, as age on the `asOf` date |
| `sex` | `female` \| `male` \| `unknown` | |
| `neutered` | `yes` \| `no` \| `unknown` | |
| `neuteredDate` | date \| null | |
| `lifestyle` | `sedentary` \| `typical` \| `active` \| null | null → default from neuter status (§3.2) |
| `bcs` | integer 1–9 \| null | 9-point body condition score |
| `mcs` | `normal` \| `mild` \| `moderate` \| `severe` \| null | muscle condition score |
| `idealWeightKg` | number \| null | 0.1–40. A stored ideal weight, either entered by the veterinarian or an adopted estimate (see `idealWeightSource`). When set it is used as-is (§3.2 step 5) |
| `idealWeightSource` | `veterinarian` \| `estimate` \| null | null if and only if `idealWeightKg` is null. A non-null source with a null `idealWeightKg` is a validation error. A non-null `idealWeightKg` with a missing or null source is decoded as `veterinarian` (documents written before this field existed) |
| `expectedAdultWeightKg` | number \| null | 0.1–40, kittens |
| `reproduction` | `{ status: none \| gestation \| lactation, litterSize: int 1–12 \| null, lactationWeek: int 1–12 \| null, preBreedingWeightKg: number \| null }` | |
| `medical` | MedicalFlag[] | unique values |
| `endOfLife` | boolean | |
| `verifiedIntakeKcal` | number \| null | 1–3000, measured intake of a weight-stable cat |

**Ideal weight in the UI (D3).**
- Entering a veterinary ideal weight writes `idealWeightKg` and `idealWeightSource = veterinarian`.
- When the owner adopts ("Use estimate") a `weight-loss-aaha` estimate whose `idealWeight.source` is
  `bcs-estimate`, the UI writes `idealWeightKg = idealWeight.kg` and `idealWeightSource = estimate`
  in the same action as `targetKcal`. The ideal weight then stays fixed while the cat loses weight
  and its BCS falls, instead of being re-derived from each new BCS.
- When `idealWeightSource = estimate`, the UI offers "Re-estimate from BCS", which sets
  `idealWeightKg` and `idealWeightSource` to null. The engine then re-derives the ideal weight
  from the effective BCS on every calculation.

MedicalFlag: chronic, giving `reference-only` status: `ckd`, `diabetes`, `hyperthyroid`, `gi`,
`pancreatitis`, `urinary`, `cancer`, `prescription-diet`, `other`. Acute, giving `refer` status:
`hepatic-lipidosis`, `hospitalised`, `not-eating`, `clinical-signs`. The UI explains `not-eating`
as "not eating for 24 h or more" (§12.6). `clinical-signs` covers vomiting, diarrhoea,
lethargy, straining to urinate, or drinking/urinating more.

WeightEntry: `{ id, date: YYYY-MM-DD, weightKg: 0.1–40, bcs: 1–9 | null }`.

---

## 2. Calculation API

```ts
calculatePlan(plan: unknown, options: { asOf: string /* YYYY-MM-DD */ }): PlanResult
```

`asOf` is required, which keeps the core pure and the golden cases deterministic. The UI passes today's local date.
Each `CatResult` gains `estimate`, `trend` and `nutrition` (sections 3, 6 and 7). Each food in
`PlanResult.foods` gains `FoodAnalysisResult` (§4).

Dates: parse as UTC midnight. $\mathrm{days}(a, b) = (b - a) / 86\,400\,000$ (milliseconds).
Age in days: from `birthDate` ($\mathrm{days}(\text{birthDate}, \text{asOf})$), else
$\text{approxAgeYears} \times 365.25$.
$\text{ageMonths} = \text{ageDays} / 30.4375$; completed years
$\text{ageYears} = \lfloor \text{ageDays} / 365.25 \rfloor$.
A birth date after `asOf` counts as missing age.

---

## 3. Energy estimator

### 3.1 Output

```text
EnergyEstimate {
  status: 'ok' | 'reference-only' | 'needs-input' | 'refer'
  stage: 'neonate' | 'kitten' | 'adult' | 'senior' | 'gestation' | 'lactation' | 'end-of-life' | null
  lifeStageLabel: 'kitten' | 'young-adult' | 'mature-adult' | 'senior' | null   (AAHA/AAFP 2021)
  ageMonths: number | null
  rerKcal: number                         RER at current weight, always present
  idealWeight: { kg, lowKg, highKg, source: 'veterinarian' | 'estimate' | 'bcs-estimate' | 'current' } | null
  equation: EquationId | null             'adult-fediaf' | 'weight-loss-aaha' | 'adult-gain' | 'kitten-nrc'
                                          | 'kitten-fediaf-band' | 'gestation-fediaf' | 'lactation-fediaf'
  coefficient: number | null              k or factor used, where applicable (§3.3)
  weightUsedKg: number | null
  startKcal, lowKcal, highKcal: number | null     null unless status is ok or reference-only
  floorKcal: number | null                adults/seniors only (§3.3)
  referenceBand: { lowKcal, highKcal } | null     adults/seniors only (§3.3), explanatory
  reasons: ReferCode[]                    why status is 'refer'
  missing: InputCode[]                    why status is 'needs-input'
  notes: NoteCode[]
  comparison: { targetToStartRatio, belowRange, aboveRange, differsOver30Percent, belowFloor } | null
}
```

Code sets:
- ReferCode: `neonate`, `end-of-life`, `acute-medical`, `bcs-low`, `mcs-severe`,
  `rapid-weight-change`, `kitten-not-growing`, `verified-intake-below-floor`.
- InputCode: `age`, `neutered`, `bcs`, `mcs`, `litter-size`, `lactation-week`.
- NoteCode: `loss-not-indicated`, `gain-not-indicated`, `senior-wider-range`,
  `overweight-consider-loss`, `clamped-high`, `recently-neutered`, `medical-vet-plan`,
  `diabetes-low-carb-info`, `kitten-adult-weight-unknown`, `kitten-weigh-weekly`,
  `kitten-transition`, `pre-breeding-weight-assumed`, `free-choice-recommended`,
  `reproduction-vet`, `weaning-transition`, `growth-complete`.

Status precedence: `refer` > `needs-input` > `reference-only` > `ok`. With `refer` or
`needs-input`, every kcal field except `rerKcal` is null, and so are `idealWeight`, `equation`,
`coefficient`, `weightUsedKg`, `referenceBand`, `notes` (empty) and `comparison`. Codes in
`reasons`, `missing` and `notes` are sorted and unique.

### 3.2 Stage and inputs

1. **Refer stops** (§12.6). Each adds a reason:
   - `neonate`: age in days < 56.
   - `end-of-life`: `endOfLife`.
   - `acute-medical`: any acute medical flag.
   - `bcs-low`: BCS ≤ 3. Use the profile BCS if it is non-null (the owner's current assessment); otherwise the BCS of the latest weight-log entry dated ≤ `asOf` that has a non-null BCS. This "effective BCS" is used everywhere below.
   - `mcs-severe`: MCS = severe.
   - Trend stops from section 6: `rapid-weight-change`, `kitten-not-growing`.
   - `verified-intake-below-floor` is evaluated later, inside the weight-loss equation (§3.3), because it needs the ideal weight. It is only reached when no other reason and no missing input exists.
2. **Missing inputs.** Each adds a code:
   - `age`: no usable age.
   - `neutered`: stage adult or senior with `neutered = unknown`.
   - `bcs`: stage adult or senior with no effective BCS.
   - `mcs`: age ≥ 12 completed years and MCS null.
   - `litter-size`, `lactation-week`: lactation without them.
3. **Stage.**
   - Reproduction `gestation` or `lactation` gives that stage.
   - Otherwise, with age known:
     - age in days < 56 is `neonate`;
     - $\text{ageMonths} < 12$ is `kitten`, **except** when `expectedAdultWeightKg` is set and $\mathrm{BW} \ge$ `expectedAdultWeightKg`: then the stage is `adult` and every adult rule applies (including the `neutered` and `bcs` inputs); an `ok` or `reference-only` estimate for such a cat carries the NoteCode `growth-complete`, which explains why the BCS and neuter status are now asked for;
     - age ≥ 11 completed years is `senior`;
     - anything else is `adult`.
   - `lifeStageLabel` always follows age in completed years: < 1 kitten, 1–6 young-adult, 7–10 mature-adult, ≥ 11 senior. A kitten that has reached its expected adult weight therefore has stage `adult` and label `kitten`.
4. **Lifestyle coefficient $k$** (`lifestyleK`): the profile `lifestyle` if set; otherwise
   `neutered = yes` → `typical`, any other value (`no`, `unknown`) → `active`.
   Coefficients: sedentary $63.5$, typical $75$, active $100$. For kittens, `neutered = unknown`
   is not a missing input; it gives `active` through this rule.
5. **Ideal weight (IBW)** (adult and senior stages only):
   - If `idealWeightKg` is non-null, it is used as-is, whatever the BCS:
     - `idealWeightSource = veterinarian`: source `veterinarian`, $\text{low} = \text{high} = \text{kg}$;
     - `idealWeightSource = estimate`: source `estimate`, low/high at $\pm 10\,\%$ of kg.
   - Otherwise, if effective BCS ≥ 6: source `bcs-estimate`, low/high at $\pm 10\,\%$ of
     $$\mathrm{IBW} = \frac{\mathrm{BW}}{1 + 0.10 \times (\mathrm{BCS} - 5)}$$
     This is re-derived from the effective BCS on every calculation.
   - Otherwise $\mathrm{IBW} = \mathrm{BW}$, source `current`, $\text{low} = \text{high} = \mathrm{BW}$.

### 3.3 Equations

$$\mathrm{RER}(w) = 70 \times w^{0.75} \qquad \mathrm{MER}(k, w) = k \times w^{0.67}$$

**Adult / senior, status ok.**

Weight used (D2), for the goals maintain and gain and for the "as maintain" fallbacks:

$$W = \begin{cases} \mathrm{IBW} & \text{if } \mathrm{IBW} < \mathrm{BW} \\ \mathrm{BW} & \text{otherwise} \end{cases}$$

whatever the IBW source. Weight loss uses $\mathrm{IBW}$ (below).

Floor, for every adult/senior equation:

$$\text{floor} = 0.6 \times \mathrm{RER}(\mathrm{IBW})$$

| Goal | Condition | start | low / high | equation |
| --- | --- | --- | --- | --- |
| maintain | — | $\mathrm{MER}(k, W)$, clamped (below) | $\max(\text{floor}, 0.85 \times \text{start})$ / $\text{start} \times h$ | `adult-fediaf` |
| loss | $\mathrm{IBW} < \mathrm{BW}$ | D1, below | $\max(\text{floor}, 0.875 \times \text{start})$ / $1.125 \times \text{start}$ | `weight-loss-aaha` |
| loss | otherwise | as maintain | as maintain | `adult-fediaf`, note `loss-not-indicated` |
| gain | effective BCS = 4 | $\max(\text{floor}, 1.15 \times \mathrm{MER}(k, W))$ | $\max(\text{floor}, 1.10 \times \mathrm{MER}(k, W))$ / $1.20 \times \mathrm{MER}(k, W)$ | `adult-gain` |
| gain | otherwise | as maintain | as maintain | `adult-fediaf`, note `gain-not-indicated` |

- $h = 1.15$, or $1.25$ at ≥ 12 completed years (note `senior-wider-range`, added whenever the
  maintain row is used at that age).
- Maintain start: $\max\big(\text{floor}, \min(\mathrm{MER}(k, W),\ 1.4 \times \mathrm{RER}(\mathrm{BW}))\big)$;
  note `clamped-high` when $\mathrm{MER}(k, W) > 1.4 \times \mathrm{RER}(\mathrm{BW})$ (D7). The cap
  can bind only for very small active cats: $100\,w^{0.67} > 1.4 \times 70\,w^{0.75}$ only for
  $w < 0.98^{-12.5} = 1.29$ kg.
- The gain row has no upper cap.
- Maintain (the goal itself, not a fallback) with effective BCS ≥ 6 adds note `overweight-consider-loss`.
- A neutered date ≤ 182 days before `asOf` adds note `recently-neutered`, and the trend cadence becomes 14 days.
- `coefficient` is $k$ for `adult-fediaf` and `adult-gain`, $0.8$ for `weight-loss-aaha`.
- `weightUsedKg` is $W$; for `weight-loss-aaha` it is $\mathrm{IBW}$.
- `referenceBand` $= [\mathrm{MER}(52, w), \mathrm{MER}(100, w)]$ with $w$ = `weightUsedKg` (explanatory only).
- `idealWeight` is the IBW object of §3.2 step 5; `floorKcal` is the floor.

**Weight-loss start (D1).** Let $V$ = `verifiedIntakeKcal`.

- If $V$ is null:
  $$\text{start} = \max\Big(\text{floor},\ 0.8 \times \min\big(\mathrm{RER}(\mathrm{IBW}),\ \mathrm{MER}(k, \mathrm{IBW})\big)\Big)$$
- If $V$ is set and $V \ge \text{floor}$ (AAHA option 1):
  $$\text{start} = \max(\text{floor},\ 0.8 \times V)$$
- If $V$ is set and $V < \text{floor}$: status `refer`, reason `verified-intake-below-floor`
  (a weight-stable cat eating less than 60 % of ideal-weight RER needs a veterinary work-up).

**Chronic medical flag, status reference-only.** Same as the maintain row with $W = \mathrm{BW}$
and no goal adjustment (no loss, gain, `loss-not-indicated` or `gain-not-indicated` handling;
`overweight-consider-loss` is not added). Notes: `medical-vet-plan`, plus
`diabetes-low-carb-info` if diabetic. Floor, `idealWeight` and `referenceBand` as for adults.

**Kitten, status ok (D4).**

Let $m$ = `ageMonths`, $k_A$ = `lifestyleK(profile)` (§3.2 step 4) and
$\mathrm{MER}_A = \mathrm{MER}(k_A, \mathrm{BW})$.

FEDIAF band multipliers, piecewise-linear between the band centres
$c = (2,\ 6.5,\ 10.5)$ months with $m_{\text{low}} = (2.0,\ 1.75,\ 1.5)$ and
$m_{\text{high}} = (2.5,\ 2.0,\ 1.5)$; constant at the first value for $m \le 2$ and at the last
value for $m \ge 10.5$. For $c_i \le m \le c_{i+1}$:

$$m_x(m) = m_{x,i} + \frac{m - c_i}{c_{i+1} - c_i}\,\big(m_{x,i+1} - m_{x,i}\big)$$

$$\text{bandLow} = m_{\text{low}}(m) \times \mathrm{MER}(75, \mathrm{BW}) \qquad \text{bandHigh} = m_{\text{high}}(m) \times \mathrm{MER}(100, \mathrm{BW})$$

The band is the same in both paths below.

*With `expectedAdultWeightKg` = $A$* (equation `kitten-nrc`, coefficient $100$). Here $p < 1$
because a kitten with $\mathrm{BW} \ge A$ has stage adult:

$$p = \frac{\mathrm{BW}}{A} \qquad \mathrm{NRC} = \mathrm{MER}(100, \mathrm{BW}) \times 6.7 \times \big(e^{-0.189p} - 0.66\big)$$

$$t = \operatorname{clamp}\Big(\max\big(\tfrac{p - 0.8}{0.2},\ \tfrac{m - 10}{2}\big),\ 0,\ 1\Big) \qquad \text{raw} = (1 - t)\,\mathrm{NRC} + t\,\mathrm{MER}_A$$

*Without it* (equation `kitten-fediaf-band`, coefficient null, note `kitten-adult-weight-unknown`):

$$\text{mid} = \tfrac{1}{2}(\text{bandLow} + \text{bandHigh}) \qquad t = \operatorname{clamp}\big(\tfrac{m - 10}{2},\ 0,\ 1\big) \qquad \text{raw} = (1 - t)\,\text{mid} + t\,\mathrm{MER}_A$$

*Both paths:*

$$\text{start} = \min\big(\text{raw},\ 2.5 \times \mathrm{RER}(\mathrm{BW})\big)$$

note `clamped-high` when $\text{raw} > 2.5 \times \mathrm{RER}(\mathrm{BW})$. The cap applies to the
start only; the range high is not capped.

$$\text{low} = \min(0.9 \times \text{start},\ \text{bandLow}) \qquad \text{high} = \max(1.1 \times \text{start},\ \text{bandHigh})$$

When $t > 0$, also $\text{low} \leftarrow \min(\text{low},\ 0.85 \times \mathrm{MER}_A)$ and
$\text{high} \leftarrow \max(\text{high},\ 1.15 \times \mathrm{MER}_A)$.

- Note `kitten-transition` when $0 < t < 1$. Note `kitten-weigh-weekly` always.
- `weightUsedKg` = $\mathrm{BW}$; `idealWeight`, `floorKcal` and `referenceBand` are null.
- There is no separate neutered-kitten factor; neuter status enters only through $k_A$.
- At $m = 12$ (stage adult) or $p = 1$ (stage adult) the kitten start equals $\mathrm{MER}_A$
  before the adult clamps, so the hand-over is continuous.

**Gestation, status reference-only.**
- $W$ = `preBreedingWeightKg`, else $\mathrm{BW}$ (note `pre-breeding-weight-assumed`).
- $\text{start} = 140 \times W^{0.67}$; $\text{low} = \text{start}$; $\text{high} = 1.25 \times \text{start}$; coefficient $140$.
- Notes `free-choice-recommended` and `reproduction-vet`.

**Lactation, status reference-only.**
- $\text{start} = 100 \times \mathrm{BW}^{0.67} + c \times \mathrm{BW} \times L$, coefficient $100$, where:
  - $c = 18$ (litter < 3), $60$ (3–4), $70$ (> 4)
  - $L$ by week $= (0.9, 0.9, 1.2, 1.2, 1.1, 1.0, 0.8)$; weeks > 7 use $0.8$ and add note `weaning-transition`
- $\text{low} = \text{start}$; $\text{high} = 1.25 \times \text{start}$.
- Notes `free-choice-recommended` and `reproduction-vet`.

Kitten, gestation and lactation results have `idealWeight`, `floorKcal` and `referenceBand` null.

### 3.4 Comparison with the chosen target

For status ok or reference-only, with $T$ = `targetKcal`:
- $\text{targetToStartRatio} = T / \text{start}$
- $\text{belowRange} = T < \text{low}$, $\text{aboveRange} = T > \text{high}$
- $\text{differsOver30Percent} = \lvert \text{ratio} - 1 \rvert > 0.30$
- `belowFloor`: `floorKcal` is non-null and $T$ is below it

In the UI, `belowFloor` is a prominent warning: "below 60 % of ideal-weight RER; consult a
veterinarian (hepatic lipidosis risk)".

---

## 4. Food analysis (per food)

Input: an analysis with moisture $M$ (assumed if null), protein $P$, fat $F$, fibre $\mathrm{CF}$
and ash $A$ (% as fed). All energies in kcal/100 g as fed.

$$\mathrm{NFE} = \max(0,\ 100 - M - P - F - \mathrm{CF} - A)$$

Prepared foods (method `fediaf-4-step`; $M = 100$ is invalid):

$$\mathrm{GE} = 5.7P + 9.4F + 4.1(\mathrm{NFE} + \mathrm{CF}) \qquad \mathrm{CF}_{\mathrm{DM}} = \frac{\mathrm{CF}}{100 - M} \times 100 \qquad \text{dig} = 87.9 - 0.88 \times \mathrm{CF}_{\mathrm{DM}}$$

$$\mathrm{ME}_4 = \mathrm{GE} \times \frac{\text{dig}}{100} - 0.77P$$

Fresh foods (method `fediaf-fresh`):

$$\mathrm{ME}_4 = 4P + 8.5F + 4\,\mathrm{NFE}$$

Modified Atwater (cross-check and carbohydrate share):

$$\mathrm{ME}_a = 3.5P + 8.5F + 3.5\,\mathrm{NFE}$$

FoodAnalysisResult:
- `meKcalPer100g` is $\mathrm{ME}_4$.
- `atwaterKcalPer100g` is $\mathrm{ME}_a$.
- `method`.
- `nfe`.
- Dry-matter values for each constituent: $x / (100 - M) \times 100$.
- `proteinGPer1000kcal` $= P / \mathrm{ME}_4 \times 1000$, `fatGPer1000kcal` $= F / \mathrm{ME}_4 \times 1000$.
- `carbGPer100kcal` $= \mathrm{NFE} / \mathrm{ME}_4 \times 100$, labelled "g carbohydrate per 100 kcal
  metabolisable energy (4-step)".
- `energySharePercent`: shares of protein, fat and carbohydrate in percent of $\mathrm{ME}_a$
  (Atwater terms normalised to 100; all three are 0 when $\mathrm{ME}_a = 0$):
  $$\text{protein} = \frac{3.5P}{\mathrm{ME}_a} \times 100 \qquad \text{fat} = \frac{8.5F}{\mathrm{ME}_a} \times 100 \qquad \text{carbohydrate} = \frac{3.5\,\mathrm{NFE}}{\mathrm{ME}_a} \times 100$$
  The carbohydrate share uses the same definition as the per-cat `carbPercentME` (§7, D6), so the
  food card and the cat check agree.
- `warnings`:
  - `assumed-moisture`.
  - `atwater-disagreement` when $\lvert \mathrm{ME}_a - \mathrm{ME}_4 \rvert / \mathrm{ME}_4 > 0.10$.
  - `label-energy-mismatch` when the source is label or estimate, an analysis exists, and the declared kcal/100 g differs from $\mathrm{ME}_4$ by more than 15 % of $\mathrm{ME}_4$. This catches unit errors.

The effective `kcalPerGram(food)` is $\mathrm{ME}_4 / 100$ when `energySource = analysis`, else the v1
conversion.

---

## 5. Allocation changes (see CALCULATIONS.md)

- Fixed meals may use any food. The remainder is fed as the balance food.
- CatResult renames: `wetGrams` → `fixedGrams`, `wetKcal` → `fixedKcal`, `dryKcal` → `balanceKcal`,
  `dryGramsExact` → `balanceGramsExact`, `dryGramsRounded` → `balanceGramsRounded`.
  `balanceFoodId` is added. Totals use the same renames, plus `balanceByFood: [{ foodId, gramsExact, gramsRounded }]`
  (sum of per-cat rounded containers per food, ordered by first appearance in `cats`).
- Warning `complementary-dry-food` becomes `complementary-balance-food`.
- The other v1 warnings and all rounding rules are unchanged.
- The `estimated-energy` warning text adds that label energy itself carries about ±6–8 % error (§10.3).

---

## 6. Monitoring and adjustment (trend)

Input: the cat's weight-log entries dated ≤ `asOf`, sorted by date then id.

```text
Trend {
  entries: number
  latestKg: number | null
  ratePercentPerWeek: number | null
  change28dPercent: number | null
  suggestion: { action, reason, suggestedKcal | null } | null
  nextWeighInDays: number
}
```

**Window.** Entries dated within 28 days before the latest entry, inclusive. The span is
$\mathrm{days}(\text{first window entry}, \text{latest})$, at most 28.

- Rate $r$ (`ratePercentPerWeek`) needs at least 2 entries in the window and a span ≥ 14 days.
  With $x_i$ = days since the first window entry, $y_i$ the weights and $\bar{x}, \bar{y}$ their means:
  $$r = \frac{\sum_i (x_i - \bar{x})(y_i - \bar{y})}{\sum_i (x_i - \bar{x})^2} \times \frac{7}{\bar{y}} \times 100$$
  So $r$ is in percent of the window mean weight per week (not of the initial weight).
- Change $c_{28}$ (`change28dPercent`) needs at least 2 entries and a span ≥ 7 days:
  $$c_{28} = \frac{\text{latest} - \text{first in window}}{\text{first in window}} \times 100$$

**Trend stops** (feed into `estimate.reasons`). `rapid-weight-change` is not evaluated for the
stages kitten, gestation and lactation (weight changes there by design). A missing $r$ or
$c_{28}$ never fires a condition.

| Stop | Goal | Condition |
| --- | --- | --- |
| `rapid-weight-change` | maintain, gain | $\lvert c_{28} \rvert \ge 5$ |
| `rapid-weight-change` | maintain, gain | $r < -2$ |
| `rapid-weight-change` | loss | $c_{28} \ge +5$ |
| `rapid-weight-change` | loss | $r < -3$ (D5) |
| `rapid-weight-change` | loss | $c_{28} \le -8$ (D5) |
| `kitten-not-growing` | any | stage kitten, an entry dated 7–14 days before the latest entry exists, and the latest weight is ≤ the latest such entry's weight |

**Suggestions.** Only computed when the estimate status is ok, the stage is adult or senior, and
$r$ exists. Otherwise `suggestion` is null.
- Increase: $\max(1.10 \times T,\ \text{floor})$; decrease: $\max(0.90 \times T,\ \text{floor})$, where
  $T$ is the cat's **current** `targetKcal` and floor is `floorKcal`.
- Rows are evaluated top to bottom within a goal; the first match wins.

| Goal | Condition | action | reason | suggestedKcal |
| --- | --- | --- | --- | --- |
| loss | latest ≤ IBW | `switch-to-maintenance` | `ideal-weight-reached` | maintain start at $W = \mathrm{IBW}$ (§3.3, same clamps) |
| loss | $r < -2$ | `increase` | `loss-too-fast` | increase |
| loss | $-2 \le r \le -0.5$ | `none` | `on-track` | null |
| loss | $-0.5 < r \le -0.25$ | `hold` | `slow-recheck-2-weeks` | null |
| loss | $r > -0.25$, span < 21 days | `hold` | `slow-recheck-2-weeks` | null |
| loss | $r > -0.25$, span ≥ 21 days, $0.90 \times T <$ floor | `refer` | `at-floor` | null |
| loss | $r > -0.25$, span ≥ 21 days | `decrease` | `plateau` | decrease |
| maintain | $c_{28} \ge +2$ | `decrease` | `gaining` | decrease |
| maintain | $c_{28} \le -2$ | `increase` | `losing` | increase |
| maintain | otherwise | `none` | `stable` | null |
| gain | effective BCS ≥ 5 | `switch-to-maintenance` | `ideal-condition-reached` | null |
| gain | $r > 1$ | `decrease` | `gain-too-fast` | decrease |
| gain | $r \le 0$, span ≥ 21 days | `increase` | `not-gaining` | increase |
| gain | otherwise | `none` | `on-track` | null |

Because of the stop $r < -3$, the `loss-too-fast` row is reached only for $-3 \le r < -2$.

- `nextWeighInDays`: stage kitten 7; goal loss 14; recently neutered 14; otherwise 30 (first match).
- **Not implemented (needs an adjustment history):** "at most one change per 2 weeks" and "second plateau → veterinarian". The UI shows both as advice.

---

## 7. Nutrient checks (per cat)

1. If the estimate status is neither `ok` nor `reference-only`:
   `nutrition = { status: 'not-applicable' }`.
2. Otherwise, if any food with a positive planned intake has no `analysis`, or $\text{kcal} \le 0$:
   `nutrition = { status: 'incomplete-data', missingFoodIds }` (sorted, unique).
3. Otherwise `nutrition = { status: 'ok', kcal, proteinG, proteinPer1000, minProteinPer1000, carbPercentME, warnings, notes }`.

Sums run over the fixed meals and the rounded balance grams; $g_i$ are grams eaten of food $i$,
with its analysis values $P_i$, $\mathrm{NFE}_i$ and $\mathrm{ME}_{a,i}$ (§4):

$$\text{kcal} = \text{roundedDailyKcal} - \text{extraKcal} \qquad \text{(energy from foods; extras carry no analysis)}$$

$$\text{proteinG} = \sum_i g_i \frac{P_i}{100} \qquad \text{proteinPer1000} = \frac{\text{proteinG}}{\text{kcal}} \times 1000$$

$$\text{minProteinPer1000} = \begin{cases} 70 & \text{stage kitten} \\ 75 & \text{stage gestation or lactation} \\ \max\Big(62.5,\ \dfrac{6250}{\text{kcal} / W^{0.67}}\Big) & \text{otherwise} \end{cases}$$

where $W$ is the estimate's `weightUsedKg` if set, else $\mathrm{BW}$.

$$\text{carbPercentME} = \frac{\sum_i g_i \times 3.5\,\mathrm{NFE}_i}{\sum_i g_i \times \mathrm{ME}_{a,i}} \times 100 \qquad (0 \text{ when the denominator is } 0)$$

`carbPercentME` is on the Atwater basis in numerator and denominator (D6); it does not use `kcal`.

Warnings:
- `protein-below-minimum`: $\text{proteinPer1000} < \text{minProteinPer1000}$, **not** emitted when
  `medical` includes `ckd`.
- `protein-below-5g-per-kg-ibw`: estimate equation is `weight-loss-aaha` and
  $\text{proteinG} < 5 \times$ `idealWeight.kg`.
- `carb-above-diabetic-threshold`: `medical` includes `diabetes` and $\text{carbPercentME} > 12$.
  Information for the veterinarian, not a prescription.
- `growth-claim-missing`: stage kitten, gestation or lactation, and any food used has
  `lifeStageClaim` other than `growth` or `all`.

Notes:
- `ckd-protein-vet`: `medical` includes `ckd` (protein for a CKD cat is set by the veterinarian;
  the protein minimum is shown but not checked).

---

## 8. Single source of constants and messages

- `shared/energy-model.json` holds every coefficient, threshold and table above (RER 70/0.75,
  k tiers, 52/100 band, kitten band centres and multipliers, NRC constants and transition
  thresholds, gestation/lactation tables, IBW 10 %/±10 %, loss 0.8/0.6/0.875/1.125, gain factors,
  range factors, clamps, trend thresholds, protein minima, Atwater and FEDIAF factors, assumed
  moisture, warning thresholds 10/15 %), plus `version` and the `references` (SCIENCE.md
  reference numbers) attached to each equation id.
- Keys added or changed by the 2026-10-09 revision:
  - `kitten.bandCentreMonths: [2, 6.5, 10.5]` replaces `kitten.bandMaxMonths`; `bandLow` / `bandHigh` keep their values.
  - `kitten.transitionStartRatio: 0.8`, `kitten.transitionRatioWidth: 0.2`,
    `kitten.transitionStartMonths: 10`, `kitten.transitionMonthsWidth: 2`.
  - `kitten.startLowFactor: 0.9`, `kitten.startHighFactor: 1.1` (renamed from `nrcLowFactor` /
    `nrcHighFactor`; they now multiply the start in both kitten paths). The adult range inside
    the transition uses `maintain.lowFactor` / `maintain.highFactor`.
  - `loss.startFactor: 0.8` (renamed from `startRerFactor`; it now multiplies
    $\min(\mathrm{RER}, \mathrm{MER})$).
  - `trend.plateauMinSpanDays: 21` (was 28), `trend.gainStalledMinSpanDays: 21` (was 28),
    `trend.lossRapidRatePercent: -3`, `trend.lossRapidChangePercent: -8`.
  - `nutrition.growthMinProteinPer1000: 70` (was 75), `nutrition.reproductionMinProteinPer1000: 75`.
- `shared/messages.json`: `{ "en": { code: text }, "de": { code: text } }` for every warning,
  reason, missing-input, note, nutrition status and note, suggestion reason, ideal-weight source
  and equation id.
- `script/gen_shared.mjs` generates `packages/core/src/generated/model.ts`,
  `packages/core/src/generated/messages.ts`, `packages/swift-core/Sources/PurrtionCore/Generated/Model.swift`
  and `.../Generated/Messages.swift`. `--check` fails on drift and is part of `npm run check` and CI.
- Check values for every equation are listed in SCIENCE.md §12.2 and §13.

## 9. Migration v1 → v2

- `dryFoodId` → `balanceFoodId`.
- The profile gets all-null/unknown defaults (`sex` and `neutered` unknown, `reproduction.status`
  none, `medical` [], `endOfLife` false, `idealWeightKg` and `idealWeightSource` null), and
  `weightLog` is [].
- v2 documents without `idealWeightSource`: `veterinarian` if `idealWeightKg` is non-null, else null.
- Foods get `analysis` null and `lifeStageClaim` unknown.
- Browser: read `purrtion.plan.v2`, falling back to `purrtion.plan.v1` (migrate, never delete the v1 key).
- Mac: before the first v2 write over a v1 file, copy it to `plan-v1-backup.json`.
