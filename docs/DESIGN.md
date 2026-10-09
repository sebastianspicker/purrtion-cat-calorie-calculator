# Design system (locked)

Approved by the owner on 2026-10-09: **"the design is great, please lock this in"**.

This is the binding visual and interaction language of Purrtion on the web and the Mac.
Changes need an explicit decision by the owner. New screens use these rules and do not invent
new ones. The sources of truth are `apps/web/styles.css` (`:root` tokens),
`apps/macos/Sources/Support/Theme.swift` and `brand/`. Keep these three and this document in sync.

## Concept

**A lab notebook for small carnivores.** Japanese kawaii stationery crossed with a veterinary lab
notebook: the surface details are cute, the data is rigorous. The cuteness never touches anything
that could be medically misread.

## Colour tokens

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `paper` | `#F6F4FC` | `#1D1930` | page background, with a graph-paper grid |
| `grid` / `grid-strong` | `#E7E2F5` / `#DAD3EE` | white at 4.5 % / 7.5 % | 8 px millimetre grid; every 5th line strong |
| `panel` | `#FFFFFF` | `#272140` | stickers, tables, inputs |
| `ink` | `#2B2541` | `#EEEAF8` | text, outlines |
| `muted` | `#5E5878` | `#B9B2D2` | secondary text |
| `sakura` / `sakura-ink` | `#E8779E` / `#B3365F` | `#E8779E` / `#F7A3C0` | primary accent: fills / text and buttons |
| `matcha` / `matcha-ink` | `#7CC49A` / `#2D7550` | `#7CC49A` / `#93DDB0` | ok, ideal condition |
| `sky` / `sky-ink` | `#8DBDEB` / `#2C64A0` | `#8DBDEB` / `#A9CFF5` | estimate range, links, focus |
| `yolk` / `yolk-ink` | `#F5CF6B` / `#7A5A00` | `#F5CF6B` / `#F5D57F` | warnings, notes |
| `alert` | `#C8323F` | `#FF8C93` | floor line, errors, referral emphasis |

Every accent has a `-soft` background variant in `styles.css`. Text on any background must pass
WCAG AA in both themes. Dark mode follows the system and can be overridden with `data-theme`.

## Type

- **M PLUS Rounded 1c** (self-hosted woff2, weights 500 and 800, OFL) for headings, numerals, the
  wordmark and chips. On the Mac: the system rounded design (`.fontDesign(.rounded)`).
- `system-ui` for body text. All numbers use tabular figures (`tabular-nums` / `.monospacedDigit()`).
- Formulas are LaTeX rendered to MathML (Temml) with `font-family: math`. On the Mac they are
  Unicode plain text. Coefficients always come from `shared/energy-model.json`, never typed literally.
- Sentence case everywhere. **No** all-caps eyebrow labels, **no** "→" in buttons, **no**
  "A · B · C" meta strings.

## Shapes and surfaces

- **Sticker panels** for primary content: 2 px outline (`ink` at 85 %), 18 px radius (16 pt on
  the Mac), a *hard* offset shadow of `3px 3px 0` at 18 % ink. Never a soft blurred grey shadow.
- Inputs: 12 px radius. Status and code chips: pills.
- **Data stays serious:** tables have 1 px hairlines, a 6 px container radius and no sticker shadow.

## Signature element: the energy ruler

A horizontal kcal/day scale, which is where the visual boldness is spent:

- hatched sky band: typical adult reference
- solid sky capsule: estimate range
- ink diamond: suggested start
- dashed alert line, labelled: floor (60 % of ideal-weight RER)
- sakura paw-print pin: the owner's target

The paw pin's glide (≤ 300 ms, off under reduced motion) is the **only** decorative animation.
The ruler always has a text equivalent with the same numbers.

## Brand and characters

- **Logo** (`brand/purrtion-mark.svg`): a cat peeking out of a sakura food bowl that carries
  beaker graduations, with a die-cut sticker edge. Usage rules are in `brand/README.md`.
- **Cat icons** (`brand/cat-icons.svg`): 12 badges in the same drawing style (1.6 px ink outline,
  brand pastels), shown at the bottom right of a cat's avatar. Per-cat avatars use a pastel
  derived from the cat id.
- **Professor Purr** (de: Professor Schnurr): the guided-setup wizard, the logo's cat face with
  a small wizard hat. Easter egg: five clicks on the brand mark put the hat on the logo.

## Hard rules: where cuteness stops

- No mascot, characters or decoration on **referral, warning or error** panels. Those use a
  plain icon and clear text.
- A `refer` status shows **no kcal numbers anywhere**, including the portions panel and the wizard.
- Copy is warm but precise. It never says "prescription" or "diagnosis", and it never suggests
  a number replaces a veterinarian.
- Targets change only through explicit, confirmed actions. Veterinarian-set targets get the
  "discuss with your vet first" wording.

## Quality floor

- Responsive down to 360 px with no horizontal page scroll. Tables scroll inside their own region.
- Visible keyboard focus. AA contrast in both themes. Reduced motion respected.
- The print stylesheet keeps the household plan readable in black and white.
- No external requests: fonts and libraries are self-hosted, and the CSP is self-only.
