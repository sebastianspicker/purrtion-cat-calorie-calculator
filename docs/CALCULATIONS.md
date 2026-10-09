# Calculation contract: portion allocation

## Scope

This document specifies how a **supplied calorie target** is turned into grams (schema v2).
It does not choose the target. The optional energy estimator (starting point, range, floor)
is specified in [ENGINE.md](ENGINE.md) §3 with its evidence in [SCIENCE.md](SCIENCE.md); it
never writes `targetKcal`. Food energy computed from a label analysis is specified in
ENGINE.md §4; this document only uses its result.

All internal arithmetic uses kcal and grams with no intermediate rounding. Both engines
(TypeScript `packages/core`, Swift `packages/swift-core`) implement this contract and are
checked against the same golden cases (`shared/golden-cases.json`).

## Energy density

Label energy is converted with the thermochemical factor $1\ \mathrm{kcal} = 4.184\ \mathrm{kJ}$.
The four supported units are `kcal/100g`, `kJ/100g`, `kcal/kg` and `kJ/kg`. With $E$ the label
value, $d$ = 100 (per 100 g) or 1000 (per kg) and $u$ = 4.184 for kJ or 1 for kcal:

$$e = \frac{E}{d \cdot u} \quad [\mathrm{kcal/g}]$$

Switching a food's unit converts the number as well, so the density never changes.

**Analysis-sourced energy.** When `energySource = analysis`, `energyPerUnit` is null and the
density is $e = \mathrm{ME}_4 / 100$, where $\mathrm{ME}_4$ is the FEDIAF four-step (prepared)
or fresh-food metabolisable energy in kcal per 100 g as fed (ENGINE.md §4). The food's
`energyUnit` only chooses how the computed value is displayed. The density must lie within
0.01–10 kcal/g, which is also checked for a food that has both a label value and an analysis.
When both exist and the source is `label` or `estimate`, the label value is used; a mismatch of
more than 15 % raises the food warning `label-energy-mismatch` (it catches unit errors).

## Allocation per cat

Let $T$ be `targetKcal`, $X$ `extraKcal`, $g_i$ the grams of each fixed meal (any food, wet or
dry, amount actually eaten) with density $e_i$, and $e_b$ the density of the balance food.

$$K_{\text{fixed}} = \sum_i g_i\, e_i \qquad r = T - K_{\text{fixed}} - X$$

$$K_{\text{balance}} = \max(0,\ r) \qquad \text{over-budget} = \max(0,\ -r)$$

$$G_{\text{exact}} = \frac{K_{\text{balance}}}{e_b} \qquad G = \operatorname{round}(G_{\text{exact}}) \quad \text{(half up)}$$

$$K_{\text{daily}} = K_{\text{fixed}} + X + G\, e_b$$

- `fixedGrams` and `fixedKcal` are $\sum g_i$ and $K_{\text{fixed}}$; `balanceKcal`,
  `balanceGramsExact`, `balanceGramsRounded` are $K_{\text{balance}}$, $G_{\text{exact}}$, $G$;
  `roundedDailyKcal` is $K_{\text{daily}}$. The editor shows $K_{\text{daily}}$ next to $T$; it does
  not hide the small difference that rounding to one gram creates.
- Fixed meals may reference **any** food. The balance food (`balanceFoodId`) may be any food as
  well, for example a dry food, a wet food or a raw mix.
- Fixed meals are the amount actually eaten, not the amount offered. Extras are calories outside
  the planned foods. Do not enter the same food twice, once as a meal and once as an extra.
- When fixed meals and extras already exceed the target, the balance is 0 g and the excess is
  shown. The app does not shrink a meal, change the target or return negative grams.

### Household totals

`totals` sums fixed grams and kcal, targets, exact balance grams and daily kcal over all cats.
`balanceGramsRounded` is the sum of the **per-cat rounded** containers, not the rounded sum of
the exact values. `balanceByFood` lists, per balance food and in order of first appearance in
`cats`, the exact grams and the sum of the per-cat rounded grams: this is what you weigh out per
food. Cats with different balance foods therefore never add into one number.

## Rounding and activities

Each cat's balance ration $G$ is split over the household's activities by their percentage
shares $s_j$ (0–100, summing to 100 within $10^{-6}$ percentage points):

$$a_j = G \cdot \frac{s_j}{100} \qquad p_j = \lfloor a_j \rfloor \qquad R = G - \sum_j p_j$$

The $R$ remaining grams go to the activities with the largest fractional parts $a_j - p_j$, one
gram each; equal fractions are resolved by activity order. Activity grams therefore always add
up to the cat's container $G$. Activities split the balance ration only; fixed meals and extras
are not split. The split is an organisational preference: the app does not compute calories
earned by activity.

## Worked example: Luna, example household

Luna: target $T = 190$ kcal (owner), no extras, two fixed meals of 85 g example chicken pâté
(analysis: protein 11 %, fat 5 %, fibre 0.3 %, ash 2 %, moisture 80 %, prepared), balance food
example dry adult food at 1600 kJ/100 g. Activities 30/30/40 %.

**1. Pâté energy (four-step method).**

$$\mathrm{NFE} = 100 - 80 - 11 - 5 - 0.3 - 2 = 1.7$$

$$\mathrm{GE} = 5.7 \cdot 11 + 9.4 \cdot 5 + 4.1\,(1.7 + 0.3) = 117.9$$

$$\mathrm{CF}_{\mathrm{DM}} = \frac{0.3}{100 - 80} \cdot 100 = 1.5 \qquad \text{dig} = 87.9 - 0.88 \cdot 1.5 = 86.58$$

$$\mathrm{ME}_4 = 117.9 \cdot \frac{86.58}{100} - 0.77 \cdot 11 = 93.608\ \mathrm{kcal/100\ g}$$

**2. Fixed meals.**

$$K_{\text{fixed}} = 2 \cdot 85 \cdot 0.93608 = 159.13\ \mathrm{kcal} \approx 159.1$$

**3. Remaining budget.**

$$r = 190 - 159.13 - 0 = 30.87\ \mathrm{kcal} \approx 30.9$$

**4. Balance food.**

$$e_b = \frac{1600}{100 \cdot 4.184} = 3.824\ \mathrm{kcal/g} \qquad G_{\text{exact}} = \frac{30.87}{3.824} = 8.07\ \mathrm{g} \qquad G = 8\ \mathrm{g}$$

**5. Delivered energy.** $K_{\text{daily}} = 159.13 + 8 \cdot 3.824 = 189.73$ kcal against a
target of 190.

**6. Activities.** $a = (2.4,\ 2.4,\ 3.2)$, floors $(2, 2, 3)$ sum to 7, so $R = 1$ gram.
The fractions are $(0.4,\ 0.4,\ 0.2)$; the tie between the first two goes to the first activity:

| Activity | Share | Exact | Floor | Grams |
| --- | ---: | ---: | ---: | ---: |
| Puzzle feeder | 30 % | 2.4 | 2 | **3** |
| Scatter feeding | 30 % | 2.4 | 2 | **2** |
| Evening bowl | 40 % | 3.2 | 3 | **3** |

The activities add up to 8 g, Luna's container. The result matches the table in the README.

## Warnings, not silent corrections

Per-cat warning codes (sorted, unique). Warnings never make a ration nutritionally complete.

| Code | Raised when |
| --- | --- |
| `estimated-energy` | a food with positive intake has `energySource` `estimate` or `analysis`. The text adds that declared energy can also differ from measured energy; uncertainty depends on food and method |
| `unknown-completeness` | a food with positive intake has `completeness = unknown` |
| `complementary-balance-food` | the balance food is complementary and its grams are above zero |
| `provisional-target` | `targetSource = provisional` |
| `extras-over-10-percent` | extras plus the energy of complementary foods eaten exceed 10 % of $T$ |
| `over-budget` | $r < 0$ (with a tolerance of $10^{-8}$ kcal) |

Foods with zero intake raise no food warning merely by being in the library. Food-level
warnings from the analysis (`assumed-moisture`, `atwater-disagreement`,
`label-energy-mismatch`) and the estimator, trend and nutrient-check results are specified in
ENGINE.md §3, §4, §6 and §7.

## Validation limits

These bounds protect arithmetic, memory and form handling. They are **not** recommended feeding
or physiological ranges.

Plan:
- 1–50 cats, 1–100 foods, 1–12 activities; `name` and labels 1–120 characters, notes up to 1000.
- Activity shares 0–100 %, total 100 % within $10^{-6}$ percentage points.
- Unique IDs within each list; every `balanceFoodId` and meal `foodId` must reference a food in
  the library (any type in v2).
- JSON import up to 1 MiB. `schemaVersion` must be 1 or 2; v1 is migrated (ARCHITECTURE.md).

Cat and meal:
- Body weight 0.1–40 kg, `targetKcal` 1–3000, `extraKcal` 0–3000.
- 0–24 meals per cat, 0–1000 g per meal.
- `icon` one of the 12 names in `brand/cat-icons.svg`, or null.
- `weightLog` 0–1000 entries with unique IDs: date `YYYY-MM-DD`, weight 0.1–40 kg, `bcs` 1–9 or null.

Profile (new in v2):
- `birthDate` a valid calendar date or null; `approxAgeYears` 0–30; `neuteredDate` a date or null.
- `bcs` integer 1–9; `mcs` `normal`, `mild`, `moderate` or `severe`; `lifestyle` `sedentary`, `typical`, `active` or null.
- `idealWeightKg` 0.1–40; `idealWeightSource` is null exactly when `idealWeightKg` is null.
- `expectedAdultWeightKg` 0.1–40; `verifiedIntakeKcal` 1–3000.
- `reproduction`: `litterSize` and `lactationWeek` integers 1–12, `preBreedingWeightKg` 0.1–40.
- `medical` flags unique; `endOfLife` boolean.

Food:
- `energyPerUnit` 0.001–50000 in a supported unit, or null only when `energySource = analysis`;
  the normalised density must be within 0.01–10 kcal/g (a plausibility guard, not a guarantee).
- `analysis` (percent as fed): protein, fat, fibre and ash 0–100; `moisture` 0–100, or null only for
  dry food (then 8 % is assumed); `kind` `prepared` or `fresh`. Moisture must be below 100 %, and the
  five constituents may not add up to more than 100 %. `analysis` is required when
  `energySource = analysis`.
- `lifeStageClaim` one of `adult`, `growth`, `all`, `unknown`.

Other:
- The integer activity allocator accepts at most one million grams; valid plans cannot reach this.
- `calculatePlan` requires `asOf` (`YYYY-MM-DD`).
- Decimal point or comma is accepted in UI number fields. Thousands separators, negative numbers,
  empty required values and non-finite values are rejected. JSON uses the decimal point.
- Validation messages are currently English only (see the roadmap).

## Boundaries

Weight and goal are descriptive. The goal never chooses a target, and the 10 % extras warning
reflects the general guidance for treats (AAHA), not a formulation analysis. Calories alone do
not establish nutritional adequacy; the nutrient checks of ENGINE.md §7 cover protein and
carbohydrate share only, and only for foods with an analysis. Review targets with a
veterinarian where appropriate.
