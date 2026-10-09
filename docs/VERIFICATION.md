# Verification

What was actually run for the v2 work (engine, schema v2, estimator, UI, brand), and what was
not. These are results of executed commands, not CI results inferred from workflow files. The
workflows in `.github/workflows` have not yet run on GitHub.

## Executed

| Check | Result |
| --- | --- |
| `npm run check` | Passed: generated-file drift check, shared-file drift check, strict TypeScript type-check, build, Node tests: 355 of 355 pass |
| Swift core (`PurrtionCore`) | 53 XCTest methods passed, including all 117 shared golden cases. Run with a substitute harness, see below |
| Independent math audit | Every golden case was recomputed independently: 0 mismatches between code and specification. Defects in the model itself were found and fixed ([SCIENCE.md](SCIENCE.md) section 16) |
| jsdom drive of the built web modules | Ran with 0 runtime errors. This is a script-level exercise, not a browser |
| Correctness review | The estimator was re-implemented independently and compared on 6,000 random cats: 0 mismatches. The TS and Swift engines were compared function by function. Ten UI and parity defects were found and fixed |
| Security review | No critical or high findings. Nine low or informational items were fixed. `apps/web/vendor/temml/temml.min.js` is byte-identical to the official npm `temml@0.13.5` file |
| Browser smoke test (`tests/browser_smoke.py`) | Passed in Chromium on a real HTTP origin, see below |

The golden cases are the same 117 for both engines (`shared/golden-cases.json`).

### Swift core: substitute harness

SwiftPM could not run in the development sandbox, so `swift test` was **not** the command used.
The Swift core and its tests were compiled directly with `swiftc` and executed with
`xcrun xctest`. This runs the same source and the same 53 tests, but not the package manifest,
resource bundling through SwiftPM or `swift test` itself. Running `swift test` on a normal
machine is the next step.

### SwiftUI app: type-checked only

The SwiftUI sources were checked in two ways: a plain type-check, which is limited because the
SDK's macro plugins (for example `@Observable`) are unavailable in the sandbox, and a type-check
with a small macro shim, which reported 0 errors.

**The app was not built, linked, launched or visually inspected.** Nothing is known about
resource loading in a staged `.app`, file panels, menus, local persistence and recovery, window
behaviour, or the look of the native UI. `./script/build_and_run.sh` was not run.

### Browser smoke test: passed in Chromium

`tests/browser_smoke.py` passed on 2026-10-09 against the final build in its default mode: a real
local HTTP origin, real `localStorage` with a reload, and the meta Content-Security-Policy
present. The browser was Playwright 1.57 with Chromium headless shell build 1248 on macOS.

It covers:
- the calculation and estimator;
- the weight log, including the weigh-in date limit and same-day replacement;
- "Use estimate", plus the disabled state while the form is invalid;
- editing and decimal limits;
- import, food analysis, unit conversion (to 4 decimals) and activities;
- quick add, and the guided setup on both the ok path and the referral path (no kcal shown);
- the German interface, mobile width and dark mode.

Screenshots from that run were reviewed by eye at desktop and mobile widths, light and dark,
English and German. The SVG cat icons were checked separately: rendered next to the brand
sprite, the two images were byte-identical.

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
