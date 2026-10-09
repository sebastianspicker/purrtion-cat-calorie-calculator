# Security and privacy

Purrtion is a local-first portion planner. It needs no application backend, analytics, login,
API key, telemetry, remote food lookup or embedded web content. The site makes no network
requests at runtime other than loading its own static files. External reference links are
ordinary links that open only when selected.

## Where data lives

- **Browser:** `localStorage` key `purrtion.plan.v2` (the plan), `purrtion.plan.v1` (an older
  plan, read for migration and never deleted by the app), `purrtion.plan.v2.recovery` (a copy of
  unreadable data, written only on an explicit recovery action) and `purrtion.locale` (language).
  Data belongs to the site's origin.
- **Mac:** `~/Library/Application Support/Purrtion/plan.json`, plus backups
  (`plan-v1-backup.json`, timestamped copies) in the same folder.
- Neither is encrypted by the application. Anyone with access to the device or browser profile
  can read it. Exports contain cat names, weights, ages, health notes, weight logs and plans:
  keep private information out of public bug reports and shared examples.
- There is no sync. Import and export are manual.

## GitHub Pages and access logs

If you publish the site on GitHub Pages, GitHub serves it and, like any web host, processes
request data such as IP addresses and user agents. Purrtion itself sends nothing there beyond
the page requests and never sends your plan anywhere. Your plan stays in your browser.

Project sites under `username.github.io` share one browser origin with every other site of the
same account (and with the account's user site). Browsers separate `localStorage` by origin, not
by path, so any other project site of that account can read and write this site's saved plan.
For real data, serve Purrtion from a custom domain, or from a dedicated account or organisation
that publishes nothing else, and export a backup regularly.

## Current safeguards

- Versioned JSON is validated before use: size limit (1 MiB), list lengths, text lengths, finite
  numeric ranges, references and ID uniqueness. Unknown schema versions are rejected. Invalid
  imports do not replace the saved plan or unsaved fields.
- Rendering uses DOM text nodes and native SwiftUI text, not user-supplied HTML. LaTeX for
  formulas is built only from fixed templates and formatted numbers, never from user text.
- CSV cells beginning with a spreadsheet formula marker are prefixed before quoting.
- **Content Security Policy.** The page carries a CSP meta tag (self-only scripts, styles,
  fonts, images and connections; no objects, no form submissions). The local server sends an
  equivalent HTTP header with `frame-ancestors 'none'`, `nosniff` and `no-referrer`. A meta tag
  cannot set `frame-ancestors`, and GitHub Pages does not allow custom response headers, so a
  deployed Pages site has the meta tag only. A host that supports headers should add them.
- **Vendored code.** The only third-party code that runs in the page is Temml (MathML
  rendering), copied verbatim from the published npm package, served from the same origin and
  pinned by version in `apps/web/vendor/README.md`. The font files are likewise local.
  Review the table there when updating. The npm development dependency is TypeScript only.
- The local preview server binds to loopback, serves GET and HEAD only, and confines reads to
  `dist/web` (no path escape through `..` or symlinks). Do not expose it as a production service.

Unreadable existing data is not silently overwritten. Storage failures are shown. Export a
backup before resetting, replacing, clearing site data, changing the domain or closing an
in-memory-only session. Two tabs or windows have no merge: the web store warns about conflicting
edits, and saving overwrites the other tab's change.

The development Mac app is ad-hoc signed; it is not sandboxed, notarised or Developer ID signed,
and no release security review has been done. The build script is for trusted local source.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for this repository (Security tab, "Report a
vulnerability"), or contact the maintainer privately. Do not post sensitive exports, credentials
or device information in a public issue. Dependencies and CI actions should be reviewed and
updated as part of normal maintenance; pinned versions are not a security audit.
