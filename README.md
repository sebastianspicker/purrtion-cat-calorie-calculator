<p align="center">
  <img src="brand/purrtion-mark.svg" width="96" height="96" alt="Purrtion logo: a cat peeking out of a food bowl marked like a measuring beaker">
</p>

# Purrtion

Purrtion is a local-first planner that estimates how much energy a cat needs and turns your chosen calorie target into measured daily portions, as a website and a native Mac app.

## What Purrtion does

- **Energy estimate.** It suggests a starting point and a range for each cat from weight, age, neuter status, body condition score (BCS), lifestyle, goal and health notes. The method combines published equations with documented app assumptions ([ENGINE.md](docs/ENGINE.md), [SCIENCE.md](docs/SCIENCE.md)).
- **Feeding portions.** Each cat has fixed meals of any food, plus one balance food that supplies whatever is left of the daily target. The result is shown per cat and for the household, with whole-gram containers and a split across feeding activities such as a puzzle feeder.
- **Food-label analysis.** Enter the "analytical constituents" of a food (protein, fat, fibre, ash, moisture) and Purrtion computes its energy density, dry-matter values and energy shares. It warns when the declared energy and the analysis disagree.
- **Weight log.** Record weigh-ins, see the weekly trend, and get an adjustment suggestion when the trend is off track.
- **Nutrient checks.** Protein per 1,000 kcal and carbohydrate share are checked against the cat's life stage and health notes, where the foods have an analysis.
- **Guided setup.** Professor Purr, the in-app guide, walks you through adding a cat step by step.
- **English and German.** The interface and all messages are available in both languages.
- **Local-first.** There is no account, backend or analytics. Your plan stays in your browser or in a file on your Mac. Export and import JSON; export CSV; print.

### Safety principle

Purrtion never changes a cat's calorie target by itself. An estimate is a separately labelled suggestion. The target changes only when you choose "Use estimate as target" or "Apply suggestion" and confirm, and a target set by a veterinarian is never presented as something to overwrite.

Purrtion does not calculate for, and refers you to a veterinarian instead, when a cat is:

- younger than 8 weeks;
- at the end of life, hospitalised, not eating, or showing clinical signs (for example vomiting or straining to urinate);
- underweight (BCS 3 or lower) or has severe muscle loss;
- changing weight quickly, or a kitten that is not growing;
- eating a verified amount below the safe floor (60 % of ideal-weight resting energy requirement).

For chronic conditions (for example kidney disease or diabetes), pregnancy and lactation, Purrtion shows a reference value only and points to the veterinarian's plan.

## Try the example household

The app starts with an example household of five cats, so you can see every feature before entering your own cats. The foods are illustrative example values, not products. Results below are computed as of 2026-10-09; energy values are kcal per day.

| Cat | Icon | Situation | Estimate | Target | Balance food | Portion |
| --- | --- | --- | --- | --- | --- | --- |
| Luna | moon | 4.0 kg neutered indoor adult, BCS 5, maintain | 189.9 (161.4–218.3) | 190 owner | dry adult | 8 g, plus 2×85 g chicken pâté |
| Oskar | scale | 6.2 kg, BCS 8, sedentary, weight loss to 4.8 kg | 145.3 (136.2–163.5, floor 136.2) | 145 provisional | dry adult | 11 g, plus 2×70 g weight-control wet; trend −0.7 %/wk, on track |
| Mochi | dango | 4-month kitten, 2.0 kg, expected adult 4.0 kg | 266.3 (225.1–361.7) | 266 provisional | dry kitten | 59 g, plus 40 g fish |
| Tiger | stripes | 14-year-old with CKD, BCS 4 | reference only, 183.4 (155.9–229.3) | 210 set by veterinarian | fish in jelly | 280 g |
| Pixel | bolt | 3.5 kg active intact young adult, raw-fed | 231.5 (196.8–266.2) | 231 owner | raw mix | 160 g |

Use "Reset to the sample plan" on the Method page to return to this household at any time.

## Getting started

### Website

Requires Node.js 22 or later and npm. The only npm dependency is the pinned TypeScript compiler. There is no frontend framework and no backend.

```sh
npm ci
npm run dev        # build, watch and serve at http://127.0.0.1:5173
```

Reload the browser after edits; there is no hot-module replacement. Opening `index.html` directly with `file://` is not supported.

```sh
npm run check      # generated-file and shared-file drift, strict types, build, Node tests
npm run build      # the complete static site in dist/web/
npm run preview    # serve that build locally
```

### Publish on GitHub Pages

1. In the repository settings, open **Pages** and set the source to **GitHub Actions**.
2. Push to `main`. The workflow [`.github/workflows/pages.yml`](.github/workflows/pages.yml) runs `npm run check` and deploys `dist/web/`.
3. The site is served at `https://<user>.github.io/<repository>/`. All URLs in the site are relative, so it works under that path prefix. The build adds `.nojekyll`.

Browser data belongs to the site's origin. Changing the domain or repository name starts with an empty plan; export JSON first. Any other static host works too: deploy the whole `dist/web/` directory.

### Mac app

Requires macOS 14 or later and a Swift 6 toolchain with a macOS SDK (Xcode 16 or later). Node.js is not needed.

```sh
./script/build_and_run.sh                 # build, stage dist/Purrtion.app, launch
./script/build_and_run.sh --build-only    # build and stage only
swift test                                # the Swift core tests
```

The script stages a locally ad-hoc-signed app for your machine's architecture. It is not notarised, not universal and not an App Store or Developer ID release. The package also opens in Xcode through `Package.swift`.

The SwiftUI executable has been built and linked by SwiftPM; the native GUI and staged app bundle have not been run. See [docs/VERIFICATION.md](docs/VERIFICATION.md).

## Repository layout

```text
apps/
  web/src/               TypeScript UI: pages, guided setup, i18n, store
  web/vendor/            Vendored Temml (MIT), see vendor/README.md
  web/fonts/             M PLUS Rounded 1c (OFL), latin subset
  web/test/              Browser-store and UI tests, run in Node
  macos/Sources/         SwiftUI app, store, views
packages/
  core/src/              Pure TypeScript engine: model, validation, estimator, calculation
  core/src/generated/    Generated constants and messages (do not edit)
  core/test/             Node tests
  swift-core/            Foundation-only Swift engine and XCTest suite (Generated/ too)
shared/
  default-plan.json      The example household
  plan.schema.json       Schema v2 interchange schema
  golden-cases.json      117 cross-language reference cases
  energy-model.json      Every coefficient and threshold of the estimator
  messages.json          English and German texts for warnings and reasons
brand/                   Logo, app icon, cat icon sprite, brand notes
script/                  build, dev, serve, gen_shared.mjs, sync_shared.sh, build_and_run.sh, package_source.py
tests/                   Optional Playwright browser smoke test
docs/                    Engine, science, calculations, architecture, verification, roadmap
.github/workflows/       ci.yml and pages.yml
```

There are two separate implementations of the engine (TypeScript and Swift). They share their constants and messages through generated code (`script/gen_shared.mjs`) and are held to the same results by the golden cases. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). The visual design is fixed in [docs/DESIGN.md](docs/DESIGN.md); new UI follows it.

## Tests

```sh
npm ci
npm run check      # 359 Node tests (core engine, web store and UI), plus drift and type checks
swift test         # 56 Swift XCTest methods
```

Both engines run the same 117 golden cases in `shared/golden-cases.json`. After changing `shared/energy-model.json`, `shared/messages.json`, `shared/default-plan.json` or `shared/golden-cases.json`, run `npm run gen:shared` and `npm run sync:shared`; `npm run check` fails on drift.

Optional browser smoke test (Playwright with Chromium):

```sh
python3 -m venv .venv
. .venv/bin/activate
pip install -r tests/requirements.txt
python -m playwright install chromium
npm run build
python tests/browser_smoke.py
```

Options: `--screenshots <dir>` saves screenshots, `--browser <path>` uses an existing Chromium, and `--isolated` loads the built assets without a local HTTP origin (it does not test real storage persistence). CI runs the default mode. What has and has not been verified is listed in [docs/VERIFICATION.md](docs/VERIFICATION.md).

## Data and privacy

The website stores the plan in your browser (`localStorage`, key `purrtion.plan.v2`) and the language choice in `purrtion.locale`. The Mac app stores `~/Library/Application Support/Purrtion/plan.json`. Neither is encrypted by the app. Keep exported backups; clearing site data or using private browsing can remove the browser copy.

The website has no analytics, no cookies, no remote fonts or scripts and no API. GitHub Pages, like any host, logs requests. The website and the Mac app do not synchronise with each other: export JSON from one and import it in the other. See [SECURITY.md](SECURITY.md).

## Science and references

The estimator separates source-backed coefficients from app choices such as interval widths and growth blending. [docs/SCIENCE.md](docs/SCIENCE.md) gives the evidence, its limits and open questions; [docs/ENGINE.md](docs/ENGINE.md) is the normative specification; [docs/CALCULATIONS.md](docs/CALCULATIONS.md) covers portion allocation. The main sources are FEDIAF Nutritional Guidelines (2025), NRC Nutrient Requirements of Dogs and Cats (2006), the AAHA nutrition and weight management guidelines (2021) and life stage guidelines (2021), the AAHA 2014 weight management guidelines, WSAVA nutrition guidance, and International Cat Care (iCatCare) material.

## Medical disclaimer

Purrtion is a planning tool. It does not examine your cat, diagnose illness, prescribe a therapeutic diet or check micronutrients, and calories alone do not make a diet complete. Estimates are starting points; individual cats vary (SCIENCE.md section 2.3), so the weight trend decides the final amount. The medical content has not yet been reviewed by a veterinarian. Unexplained weight change, poor appetite, illness or an uncertain target need veterinary assessment.

## Licences

Purrtion is released under the MIT licence, see [LICENSE](LICENSE). Bundled third-party files:

- [Temml](https://temml.org/) 0.13.5, MIT licence (`apps/web/vendor/temml/LICENSE`).
- M PLUS Rounded 1c, SIL Open Font License 1.1 (`apps/web/fonts/OFL.txt`).

The logo, app icon and cat icons in `brand/` are original work for this project, covered by the MIT licence. No pet-food brand assets are included.
