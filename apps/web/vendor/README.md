# Vendored third-party files

These files are copied verbatim from the published npm tarballs (`npm pack`). They are not npm
dependencies and are served same-origin; the website makes no network requests at runtime.

| Name | Version | Licence | Files | Used for |
| --- | --- | --- | --- | --- |
| [Temml](https://temml.org/) (`temml` on npm) | 0.13.5 | MIT, see `temml/LICENSE` | `temml/temml.min.js` (from `dist/temml.min.js`) | Renders app-built LaTeX formulas to MathML (`apps/web/src/math.ts`) |
| M PLUS Rounded 1c (`@fontsource/m-plus-rounded-1c` on npm) | 5.3.0 | SIL Open Font License 1.1, see `../fonts/OFL.txt` | `../fonts/m-plus-rounded-1c-latin-500-normal.woff2`, `../fonts/m-plus-rounded-1c-latin-800-normal.woff2` | Headings, numerals and the brand (latin subset, weights 500 and 800) |

## Checksums (SHA-256)

Recorded so a later change to a vendored file is visible in review. Check with `shasum -a 256 <file>`.

| File | SHA-256 |
| --- | --- |
| `temml/temml.min.js` | `1ab19148afe0dbc836b7a74f344071b3f3a70a7a8259ae4049e76894fcdf8d95` |
| `temml/LICENSE` | `12b4e5592a12baaf50637881f2cb9d66667b26b8d51a73cd8f0d6bcefe176ab6` |
| `../fonts/m-plus-rounded-1c-latin-500-normal.woff2` | `9a7980fa96341230341fd240f68d14a327c8b856d260eeff2e426db78b7eab87` |
| `../fonts/m-plus-rounded-1c-latin-800-normal.woff2` | `69a2ee93cdfa8fcccec3beed92a9a8c15e4ef6ea7442aa921d83e9180c552423` |
| `../fonts/OFL.txt` | `64a7bd79d7e69545e66d003153e7e4999910cbb15249a19ae2a49c472637c7e0` |

Verified on 2026-10-09: `temml/temml.min.js` and `temml/LICENSE` are byte-identical to
`dist/temml.min.js` and `LICENSE` in the official `temml@0.13.5` tarball (registry integrity
`sha512-aPkDDgunanpLNL0ql32HbolqLep+w8DRcVXRql7rWrMt/PhczdLgL4UBYYVU3BYjCNjkGq4EqwIicu/zWr1iOg==`).
The font files were not re-verified against their tarball.

To update: run `npm pack <name>@<version>` in a temporary directory, extract it, copy the files listed
above, update this table and the checksums. `script/build.mjs` copies `vendor/` to `dist/web/vendor/` and `fonts/` to
`dist/web/assets/fonts/`.
