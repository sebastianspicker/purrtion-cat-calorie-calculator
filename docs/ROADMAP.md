# Roadmap

These are future items, not claims about implemented functionality. Done and therefore not
listed: weight tracking and trend suggestions, English/German localisation of the interface and
the engine messages, the opt-in energy estimator, food-label analysis and nutrient checks.

1. **Native verification and release.** Build, link and run the SwiftUI app on a Mac; exercise
   file panels, menu commands, keyboard navigation, multi-window behaviour and accessibility.
   Then application sandbox review, signing and notarisation, and a universal binary.
2. **Adjustment history.** Record each applied target change with its date and reason. The engine
   needs it for two rules that are now advice only: at most one change per 2 weeks, and a second
   plateau leads to a veterinary check (ENGINE.md §6, "Not implemented").
3. **Localised validation errors and CSV headers.** Import and validation messages and the CSV
   column headers are English only.
4. **Installable offline web app (PWA).** A service worker and manifest. Nothing of this exists
   today; the site needs the network on first load.
5. **Synchronisation.** Explicit, consent-based sync between devices, with conflict handling,
   identity and deletion. No backend exists, and none is needed for the current planner.
6. **Veterinary review of SCIENCE.md.** Have a veterinarian check the open items in SCIENCE.md
   section 15 and the model decisions in section 16 before the estimator is presented as
   reviewed.
7. **More languages.** Messages and UI strings are keyed tables with one table per language, and
   number formatting follows the locale, so a further language means adding tables and tests.

Also deferred: meal logging of actual intake (kept separate from the plan), native printing, and
native window-conflict detection. Food scanning or catalogue integrations and automatic target
suggestions beyond the current estimator need provenance, validation and careful failure
behaviour first. A calorie-based tool must not imply complete dietary adequacy.
