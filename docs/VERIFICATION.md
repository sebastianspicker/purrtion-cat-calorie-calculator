# Verification

What was actually run for the v2 work (engine, schema v2, estimator, UI, brand), and what was
not. These are results of executed commands, not CI results inferred from workflow files. The
workflows in `.github/workflows` have not yet run on GitHub.

## Executed

| Check | Result |
| --- | --- |
| `npm run check` | Passed: generated-file drift check, shared-file drift check, strict TypeScript type-check, build, Node tests: 358 of 358 pass |
| Swift core (`PurrtionCore`) | 55 XCTest methods passed via real `swift test`, including all 117 shared golden cases and the new floor/range regressions |
| Earlier v2 math audit | Every golden case was recomputed independently: 0 mismatches between code and specification. Defects in the model itself were found and fixed ([SCIENCE.md](SCIENCE.md) section 16) |
| Earlier v2 jsdom drive | Ran with 0 runtime errors. This is a script-level exercise, not a browser |
| Earlier v2 correctness review | The estimator was re-implemented independently and compared on 6,000 random cats: 0 mismatches. The TS and Swift engines were compared function by function. Ten UI and parity defects were found and fixed |
| Earlier v2 security review | No critical or high findings. Nine low or informational items were fixed. `apps/web/vendor/temml/temml.min.js` is byte-identical to the official npm `temml@0.13.5` file |
| Browser smoke test (`tests/browser_smoke.py`) | Passed in Chromium on a real HTTP origin, see below |

The golden cases are the same 117 for both engines (`shared/golden-cases.json`).

### SwiftPM: built, linked and tested

On 2026-10-09 the follow-up audit ran real `swift test` with permission to run outside the
filesystem sandbox. It passed all 55 XCTest methods, including the package resources and
117 golden cases, and built and linked the `Purrtion` SwiftUI executable with real macro expansion.
The initial sandbox attempt failed because the compiler cache was not writable. The earlier
53-test substitute harness is superseded by this run.

**The native GUI and staged `.app` have not been launched or visually inspected.** File panels,
menus, native persistence/recovery, window behaviour, and staged app resources remain unverified.
`./script/build_and_run.sh` was not run.

### Follow-up arithmetic and evidence audit

The audit independently recomputed the README household, CALCULATIONS.md Luna allocation,
SCIENCE.md food examples and section 13 A–E. Regression tests now pin Luna's unrounded arithmetic,
check 225 adult weight/ideal-weight/lifestyle/goal combinations in each engine, and cover reductions
above and below the floor for all three goals. Tests found no remaining mismatch in these checks.
See SCIENCE.md §16.3 for corrections and the limits of the evidence review.

### Claude review of the follow-up commit (2026-10-09)

The review recomputed, from the formulas as written in the documents and independently of
both engines, every §12.2 test vector, §13 A–E, §10.4, the §4.2 lactation table, the §2.2
comparison table, D1–D7 and the §16.3 example, the CALCULATIONS.md Luna allocation and the
README household (including Oskar's least-squares rate and Mochi's age-dependent band). All
agree at the displayed precision. The FEDIAF July 2024 PDF was read directly: the 4-step and
fresh-food equations, Table VII-9 (52–75 / 100), Table VII-10 (kitten multiples, gestation,
lactation) and Table III-4b (protein 83.3 / 62.5 adult; growth 70 / reproduction 75, with no
early/late-growth split for cats) match the engine. One engine defect was found and fixed (D8:
the default weigh-in cadence of 30 days lay outside the 28-day trend window). `npm run check`
passed after the change (358 of 358), and `swift test`, run outside the sandbox, passed 55 of 55
methods including the rewritten golden expectations.

### Browser smoke test: passed in Chromium

`tests/browser_smoke.py` passed on 2026-10-09 against the final build in its default mode: a real
local HTTP origin, real `localStorage` with a reload, and the meta Content-Security-Policy
present. The follow-up run used the existing Playwright 1.57 environment with the explicitly selected
Chromium headless shell build 1248 on macOS (the environment expected absent build 1200 by default).
The test and localhost server required sandbox permission. Browser plugin not available; regular
Playwright was used. Viewports: 1440 × 1080 desktop and 390 × 844 mobile.

It covers:
- the calculation and estimator;
- the weight log, including the weigh-in date limit and same-day replacement;
- "Use estimate", plus the disabled state while the form is invalid;
- editing and decimal limits;
- import, food analysis, unit conversion (to 4 decimals) and activities;
- quick add, and the guided setup on both the ok path and the referral path (no kcal shown);
- the German interface, mobile width and dark mode;
- all method formulas rendering without a LaTeX fallback in both English and German.

The follow-up audit visually inspected the German desktop and English mobile method-page
screenshots. The earlier v2 audit also inspected light/dark screenshots and compared the SVG cat
icons against the brand sprite; those earlier checks were not repeated in the follow-up.

The run did not test downloads or OS print dialogs.

## Not verified

- Safari and Firefox. Only Chromium was run.
- The GitHub Actions workflows (`ci.yml`, `pages.yml`) and the deployed GitHub Pages site,
  including behaviour under the repository path prefix.
- The SwiftUI app as described above; no signed, notarised or universal Mac binary exists.
- Accessibility: no screen-reader or full audit, on either platform.
- The offline and sync features do not exist (see [ROADMAP.md](ROADMAP.md)).

## No veterinary review

No veterinarian has reviewed the estimator, its coefficients, the refer-to-veterinarian rules,
the nutrient thresholds or the example household. The tests check that the code implements the
specification and that the specification's arithmetic is right; they do not show that the
specification is clinically appropriate. The evidence, its weaknesses and the unverified points
are listed in [SCIENCE.md](SCIENCE.md) sections 15 and 16. Food values in the example
household are illustrative.
