#!/usr/bin/env python3
"""Exercise the built website with Playwright.

Default: a real HTTP origin and real browser localStorage.
--isolated: load identical built HTML/JS/CSS via set_content + routed assets,
with a deterministic Storage test double. This fallback does NOT verify an
actual deployment, browser storage persistence, downloads, HTTP headers or the
meta Content-Security-Policy (it is removed, because set_content documents have
no origin that 'self' could match). It exists for managed environments where
top-level navigation is blocked.

The test imports its own fixture plan, so it does not depend on the bundled sample.
"""
from __future__ import annotations
import argparse
import json
import mimetypes
import os
from pathlib import Path
import re
import subprocess
import time
from urllib.parse import unquote, urlparse
from urllib.request import urlopen
from playwright.sync_api import sync_playwright, expect

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "dist/web"
STORAGE_KEY = "purrtion.plan.v2"


def profile() -> dict:
    return {"birthDate": None, "approxAgeYears": None, "sex": "unknown", "neutered": "unknown", "neuteredDate": None,
            "lifestyle": None, "bcs": None, "mcs": None, "idealWeightKg": None, "expectedAdultWeightKg": None,
            "reproduction": {"status": "none", "litterSize": None, "lactationWeek": None, "preBreedingWeightKg": None},
            "medical": [], "endOfLife": False, "verifiedIntakeKcal": None}


def fixture_plan() -> dict:
    """Three cats with known allocation results: 26 + 24 + 39 = 89 g of balance food."""
    def food(fid, name, kind, energy, unit, source):
        return {"id": fid, "name": name, "type": kind, "energyPerUnit": energy, "energyUnit": unit, "energySource": source,
                "completeness": "unknown", "lifeStageClaim": "unknown", "analysis": None, "note": "Test fixture."}

    def cat(cid, name, weight, goal, target, grams, icon=None):
        meals = [{"id": mid, "label": label, "foodId": fid, "grams": grams}
                 for mid, label, fid in [("breakfast", "Breakfast", "wet-a"), ("afternoon", "Afternoon", "wet-b"), ("evening", "Evening", "wet-c")]]
        return {"id": cid, "name": name, "icon": icon, "weightKg": weight, "goal": goal, "targetKcal": target, "targetSource": "provisional",
                "extraKcal": 0, "balanceFoodId": "dry", "meals": meals, "profile": profile(), "weightLog": []}
    return {"schemaVersion": 2, "name": "Smoke-test plan",
            "foods": [food("wet-a", "Wet food A", "wet", 87, "kcal/100g", "estimate"), food("wet-b", "Wet food B", "wet", 110, "kcal/100g", "estimate"),
                      food("wet-c", "Wet food C", "wet", 103, "kcal/100g", "estimate"), food("dry", "Dry food", "dry", 1600, "kJ/100g", "label")],
            "cats": [cat("cat-1", "Cat 1", 6, "loss", 220, 40, "moon"), cat("cat-2", "Cat 2", 5.5, "maintain", 270, 60),
                     cat("cat-3", "Cat 3", 4.2, "gain", 270, 40)],
            "activities": [{"id": "hunt", "label": "Morning hunt", "sharePercent": 30}, {"id": "puzzle", "label": "Afternoon puzzle", "sharePercent": 30},
                           {"id": "play", "label": "Evening play", "sharePercent": 40}]}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--isolated", action="store_true")
    parser.add_argument("--browser", help="Optional Chromium executable path")
    parser.add_argument("--screenshots", type=Path)
    args = parser.parse_args()
    if not (BUILD / "index.html").is_file():
        raise SystemExit("Run npm run build first.")
    server = None
    base = "http://127.0.0.1:5199/"
    fixture = json.dumps(fixture_plan()).encode()
    try:
        if not args.isolated:
            server = subprocess.Popen(["node", "script/serve.mjs"], cwd=ROOT,
                env={**os.environ, "PORT": "5199"}, stdout=subprocess.DEVNULL)
            for _ in range(60):
                try:
                    with urlopen(base, timeout=1) as response:
                        if response.status == 200:
                            break
                except OSError:
                    time.sleep(0.1)
            else:
                raise RuntimeError("Preview server did not start.")
        if args.screenshots:
            args.screenshots.mkdir(parents=True, exist_ok=True)
        with sync_playwright() as playwright:
            kwargs = {"headless": True}
            if args.browser:
                kwargs["executable_path"] = args.browser
            browser = playwright.chromium.launch(**kwargs)
            page = browser.new_page(viewport={"width": 1440, "height": 1080}, color_scheme="light", locale="en-GB")
            errors: list[str] = []
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.on("console", lambda message: errors.append(message.text) if message.type == "error" else None)
            page.on("dialog", lambda dialog: dialog.accept())

            def shoot(name: str) -> None:
                if args.screenshots:
                    page.screenshot(path=str(args.screenshots / f"{name}.png"), full_page=True)

            def import_plan(payload: bytes) -> None:
                with page.expect_file_chooser() as chooser:
                    page.get_by_role("button", name="Import", exact=True).click()
                chooser.value.set_files({"name": "plan.json", "mimeType": "application/json", "buffer": payload})

            def saved() -> dict:
                return json.loads(page.evaluate(f"localStorage.getItem('{STORAGE_KEY}')"))

            if args.isolated:
                def serve(route):
                    relative = unquote(urlparse(route.request.url).path).lstrip("/")
                    path = (BUILD / relative).resolve()
                    if not path.is_relative_to(BUILD) or not path.is_file():
                        route.fulfill(status=404, body="Not found")
                        return
                    mime = {".js": "text/javascript", ".json": "application/json", ".woff2": "font/woff2", ".svg": "image/svg+xml"}.get(path.suffix)
                    route.fulfill(body=path.read_bytes(), content_type=mime or mimetypes.guess_type(path)[0] or "text/plain",
                                  headers={"Access-Control-Allow-Origin": "*"})
                page.route("http://purrtion.test/**", serve)
                page.evaluate("""() => {
                    const values = new Map();
                    Object.defineProperty(window, 'localStorage', {value: {
                        getItem: key => values.get(key) ?? null,
                        setItem: (key, value) => values.set(key, String(value)),
                        removeItem: key => values.delete(key), clear: () => values.clear()
                    }});
                    // about:blank is not a secure origin in every test browser.
                    // Production requires localhost or HTTPS and uses the real API.
                    if (!crypto.randomUUID) crypto.randomUUID = () =>
                        'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, char => {
                            const value = crypto.getRandomValues(new Uint8Array(1))[0] & 15;
                            return (char === 'x' ? value : ((value & 3) | 8)).toString(16);
                        });
                }""")
                html = (BUILD / "index.html").read_text().replace("<head>", '<head><base href="http://purrtion.test/">')
                html = re.sub(r'<meta http-equiv="Content-Security-Policy"[^>]*>', "", html)
                page.set_content(html, wait_until="networkidle")
            else:
                page.goto(base, wait_until="networkidle")
                csp = page.locator('meta[http-equiv="Content-Security-Policy"]').get_attribute("content") or ""
                assert "default-src 'self'" in csp and "frame-ancestors" not in csp, csp

            # The bundled sample loads, whatever it contains.
            expect(page.get_by_test_id("total-dry")).to_have_text(re.compile(r"^\d+ g$"))
            expect(page.locator("html")).to_have_attribute("lang", "en")

            # Work on the test's own plan.
            import_plan(fixture)
            expect(page.get_by_test_id("total-dry")).to_have_text("89 g")
            for cat, grams in [("cat-1", 26), ("cat-2", 24), ("cat-3", 39)]:
                expect(page.get_by_test_id(f"dry-{cat}")).to_have_text(f"{grams} g")
            shoot("desktop-light-household")
            # Only a cat with an icon shows the badge on its card.
            expect(page.locator(".bowl").nth(0).locator(".icon-badge")).to_have_count(1)
            expect(page.locator(".bowl").nth(1).locator(".icon-badge")).to_have_count(0)

            # Edit actual intake; extras are deducted; weight never changes the target.
            page.get_by_role("button", name="Cat 1", exact=True).click()
            expect(page.locator(".estimate-view")).to_be_visible()
            expect(page.locator(".estimate-view")).to_contain_text("More information needed")
            # The icon picker is a radio group; the saved icon is preselected and a new choice is kept on save.
            expect(page.get_by_role("radio", name="Moon", exact=True)).to_be_checked()
            expect(page.get_by_role("button", name="Re-estimate from BCS", exact=True)).to_be_hidden()
            page.locator('label.icon-choice:has([name="cat-icon"][value="star"])').click()
            expect(page.get_by_role("radio", name="Star", exact=True)).to_be_checked()
            page.locator('[name="breakfast-grams"]').fill("30")
            expect(page.get_by_test_id("cat-preview-dry")).to_have_text("28 g")
            page.locator('[name="cat-extras"]').fill("20")
            expect(page.get_by_test_id("cat-preview-dry")).to_have_text("23 g")
            # Invalid input (a kcal field with grouping) clears the preview and disables applying anything until it is valid again.
            page.locator('[name="cat-extras"]').fill("1,200")
            expect(page.locator(".result-panel .notice")).to_contain_text("decimal places")
            expect(page.locator(".estimate-view .estimate-head")).to_be_empty()
            expect(page.locator(".result-panel .use-estimate button")).to_be_disabled()
            expect(page.get_by_test_id("cat-preview-dry")).to_have_count(0)
            page.locator('[name="cat-extras"]').fill("20")
            expect(page.get_by_test_id("cat-preview-dry")).to_have_text("23 g")
            page.locator('[name="cat-weight"]').fill("5,9")
            expect(page.locator('[name="cat-target"]')).to_have_value("220")
            page.get_by_role("button", name="Save cat plan", exact=True).click()
            plan = saved()
            assert plan["cats"][0]["weightKg"] == 5.9
            assert plan["cats"][0]["icon"] == "star", plan["cats"][0]
            expect(page.locator(".cat-heading .icon-badge")).to_have_count(1)
            expect(page.locator(".nav-cat .icon-badge")).to_have_count(1)
            assert plan["cats"][0]["meals"][0]["grams"] == 30
            assert plan["cats"][0]["extraKcal"] == 20
            if not args.isolated:
                page.reload(wait_until="networkidle")
                expect(page.get_by_test_id("dry-cat-1")).to_have_text("23 g")
                page.get_by_role("button", name="Cat 1", exact=True).click()

            # Estimator: complete the profile, read the ruler and the formula, then use the estimate explicitly.
            page.locator('label.choice:has([name="age-mode"][value="approx"])').click()
            page.locator('[name="cat-age-years"]').fill("5")
            page.locator('[name="cat-neutered"]').select_option("yes")
            page.locator('label.pill:has([name="cat-bcs"][value="7"])').click()
            expect(page.locator(".estimate-view")).to_contain_text("Estimate available")
            expect(page.get_by_test_id("estimate-start")).to_be_visible()
            expect(page.locator(".energy-ruler")).to_have_attribute("aria-label", re.compile("Your target 220"))
            page.get_by_text("Why this number", exact=True).click()
            assert page.locator("details.why math").count() >= 3, "Formulas were not rendered as MathML"
            start = int(re.sub(r"\D", "", page.get_by_test_id("estimate-start").inner_text()))
            # Add a weigh-in with a body condition score: it becomes the profile score and the current weight.
            # The weigh-in date cannot be in the future: the input has a max and the form rejects it as well.
            expect(page.locator('[name="log-date"]')).to_have_attribute("max", re.compile(r"^\d{4}-\d{2}-\d{2}$"))
            page.locator('[name="log-date"]').fill("2999-01-01")
            page.locator('[name="log-weight"]').fill("5,8")
            page.get_by_role("button", name="Add weigh-in", exact=True).click()
            expect(page.locator("#weight-log .form-error")).to_contain_text("future")
            page.locator('[name="log-date"]').fill("2026-01-15")
            page.locator('[name="log-bcs"]').select_option("7")
            page.get_by_role("button", name="Add weigh-in", exact=True).click()
            expect(page.locator("#weight-log table")).to_contain_text("5.8 kg")
            expect(page.locator('[name="cat-weight"]')).to_have_value("5.8")
            expect(page.get_by_test_id("next-weigh-in")).to_be_visible()
            start = int(re.sub(r"\D", "", page.get_by_test_id("estimate-start").inner_text()))
            page.get_by_role("button", name=f"Use {start} kcal/day as target", exact=True).click()
            expect(page.locator('[name="cat-target"]')).to_have_value(str(start))
            expect(page.locator('[name="cat-target-source"]')).to_have_value("provisional")
            shoot("desktop-light-cat")
            page.get_by_role("button", name="Save cat plan", exact=True).click()
            plan = saved()
            cat0 = plan["cats"][0]
            assert cat0["icon"] == "star", cat0
            assert cat0["targetKcal"] == start and cat0["targetSource"] == "provisional", cat0
            assert cat0["weightKg"] == 5.8 and cat0["profile"]["bcs"] == 7 and len(cat0["weightLog"]) == 1, cat0

            # An invalid import must retain both saved data and unsaved fields.
            page.locator('[name="cat-name"]').fill("Unsaved name")
            with page.expect_file_chooser() as chooser:
                page.get_by_role("button", name="Import", exact=True).click()
            chooser.value.set_files({"name": "invalid.json", "mimeType": "application/json", "buffer": b'{"schemaVersion":99}'})
            expect(page.locator("#import-error")).to_contain_text("schemaVersion")
            expect(page.locator('[name="cat-name"]')).to_have_value("Unsaved name")
            assert saved() == plan

            # A valid import resets the current plan.
            import_plan(fixture)
            expect(page.get_by_test_id("total-dry")).to_have_text("89 g")

            # Reaching an estimated adult weight must not unlock adult restriction for a kitten.
            kitten_plan = fixture_plan()
            kitten_plan["cats"] = [kitten_plan["cats"][0]]
            kitten = kitten_plan["cats"][0]
            kitten.update(weightKg=4, goal="loss")
            kitten["profile"].update(approxAgeYears=0.67, expectedAdultWeightKg=4, bcs=8, neutered="yes")
            import_plan(json.dumps(kitten_plan).encode())
            page.get_by_role("button", name="Cat 1", exact=True).click()
            expect(page.locator(".estimate-view")).to_contain_text("does not establish maturity")
            expect(page.locator(".estimate-view")).to_contain_text("complete growth diet")
            expect(page.get_by_test_id("estimate-start")).to_have_count(0)
            expect(page.locator(".use-estimate button")).to_be_disabled()
            expect(page.locator('[name="cat-target"]')).to_have_value("220")
            shoot("kitten-growth-referral")
            import_plan(fixture)

            # Unit changes must not change the calorie density; food analysis computes ME.
            page.get_by_role("button", name="Food library", exact=True).click()
            dry = page.locator("form.food-editor").filter(has=page.locator('[name="dry-energy"]'))
            dry.locator('[name="dry-unit"]').select_option("kcal/100g")
            # The converted value is rounded to the field's two decimals.
            assert abs(float(dry.locator('[name="dry-energy"]').input_value()) - 1600 / 4.184) <= 0.00005
            for field, value in [("protein", "34"), ("fat", "14"), ("fibre", "3"), ("ash", "7")]:
                dry.locator(f'[name="dry-{field}"]').fill(value)
            # SCIENCE.md §10.4 worked example: 8 / 34 / 14 / 3 / 7 gives ME 379.5 kcal/100 g (moisture assumed for dry food).
            expect(page.get_by_test_id("food-me-dry")).to_have_text("379.5 kcal/100 g")
            expect(dry).to_contain_text("Moisture is not declared")
            shoot("desktop-light-foods")
            dry.get_by_role("button", name="Save food", exact=True).click()
            assert saved()["foods"][3]["analysis"]["protein"] == 34
            dry = page.locator("form.food-editor").filter(has=page.locator('[name="dry-energy"]'))
            dry.get_by_role("button", name="Delete food", exact=True).click()
            expect(dry).to_contain_text("This food is used")
            page.get_by_role("button", name="Daily plan", exact=True).click()
            expect(page.get_by_test_id("total-dry")).to_have_text("89 g")

            # Invalid percentages cannot corrupt the saved plan.
            page.get_by_text("Adjust activity split", exact=True).click()
            page.locator('[name="hunt-share"]').fill("40")
            page.get_by_role("button", name="Save activity split", exact=True).click()
            expect(page.locator(".activity-editor .form-error")).to_contain_text("100")
            page.locator('[name="hunt-share"]').fill("30")
            page.get_by_role("button", name="Save activity split", exact=True).click()
            expect(page.get_by_test_id("total-dry")).to_have_text("89 g")

            # Quick add and remove a cat; no fabricated default target.
            page.get_by_role("button", name="Quick add", exact=True).click()
            page.locator('[name="new-cat-name"]').fill("New cat")
            page.locator('[name="new-cat-weight"]').fill("5")
            page.locator('[name="new-cat-target"]').fill("250")
            page.get_by_role("button", name="Create cat", exact=True).click()
            expect(page.get_by_role("heading", name="New cat", exact=True)).to_be_visible()
            expect(page.get_by_test_id("cat-preview-dry")).to_have_text("65 g")
            page.get_by_role("button", name="Remove cat", exact=True).click()
            expect(page.get_by_test_id("total-dry")).to_have_text("89 g")

            # Guided setup, end to end.
            wizard = page.locator("dialog.wizard")

            def next_step() -> None:
                wizard.get_by_role("button", name="Next", exact=True).click()

            page.get_by_role("button", name="+ Add a cat", exact=True).click()
            expect(wizard).to_be_visible()
            expect(wizard.locator(".wizard-progress")).to_contain_text("Step 1 of")
            expect(wizard.locator(".bubble")).to_contain_text("Professor Purr")
            shoot("desktop-light-wizard")
            wizard.locator('[name="wiz-name"]').fill("Wizard cat")
            wizard.locator('label.choice:has([name="wiz-sex"][value="female"])').click()
            next_step()
            wizard.locator('label.icon-choice:has([name="wiz-icon"][value="fish"])').click()
            next_step()
            wizard.locator('label.choice:has([name="wiz-age-mode"][value="approx"])').click()
            wizard.locator('[name="wiz-years"]').fill("4")
            next_step()
            wizard.locator('[name="wiz-weight"]').fill("4,2")
            next_step()
            wizard.locator('label.choice:has([name="wiz-neutered"][value="yes"])').click()
            next_step()
            wizard.locator('label.choice:has([name="wiz-lifestyle"][value="typical"])').click()
            next_step()
            wizard.locator('label.pill:has([name="wiz-bcs"][value="5"])').click()
            next_step()
            expect(wizard.locator("h2")).to_have_text("Health check")
            next_step()
            expect(wizard).to_contain_text("ideal range")
            next_step()
            wizard.locator('[name="wiz-balance"]').select_option("dry")
            next_step()
            expect(wizard.locator(".summary-cat .icon-badge")).to_have_count(1)
            expect(wizard.get_by_test_id("estimate-start")).to_be_visible()
            expect(wizard.locator(".energy-ruler")).to_be_visible()
            expect(wizard.get_by_test_id("wizard-portion")).to_have_text(re.compile(r"^\d+ g$"))
            expected = round(75 * 4.2 ** 0.67)
            expect(wizard.locator(".wizard-summary")).to_contain_text(f"Use {expected} kcal/day as the starting target")
            shoot("desktop-light-wizard-summary")
            wizard.get_by_role("button", name="Create cat", exact=True).click()
            expect(page.get_by_role("heading", name="Wizard cat", exact=True)).to_be_visible()
            expect(page.locator('[name="cat-target"]')).to_have_value(str(expected))
            expect(page.locator("#app-notices")).to_contain_text("adjust everything")
            created = saved()["cats"][-1]
            assert created["icon"] == "fish", created
            assert created["profile"]["bcs"] == 5 and created["targetSource"] == "provisional", created
            page.get_by_role("button", name="Remove cat", exact=True).click()

            # Guided setup, referral path: no numbers, no guide, manual target only.
            page.get_by_role("button", name="+ Add a cat", exact=True).click()
            wizard.locator('[name="wiz-name"]').fill("Referral cat")
            next_step()
            next_step()  # icon: skipped
            wizard.locator('label.choice:has([name="wiz-age-mode"][value="approx"])').click()
            wizard.locator('[name="wiz-years"]').fill("3")
            next_step()
            wizard.locator('[name="wiz-weight"]').fill("4")
            next_step()
            next_step()  # neutered: not sure
            next_step()  # lifestyle: not sure
            wizard.locator('label.pill:has([name="wiz-bcs"][value="5"])').click()
            next_step()
            wizard.locator('[name="wiz-medical-not-eating"]').check()
            next_step()
            next_step()  # goal
            next_step()  # foods
            expect(wizard.locator(".referral-panel")).to_be_visible()
            expect(wizard.locator(".guide")).to_be_hidden()
            expect(wizard.get_by_test_id("estimate-start")).to_have_count(0)
            expect(wizard.locator('[name="wiz-outcome"][value="estimate"]')).to_have_count(0)
            shoot("desktop-light-wizard-refer")
            wizard.get_by_role("button", name="Create cat", exact=True).click()
            expect(wizard.locator(".form-error")).not_to_be_empty()
            wizard.locator('[name="wiz-own-kcal"]').fill("200")
            wizard.locator('[name="wiz-own-source"]').select_option("veterinarian")
            wizard.get_by_role("button", name="Create cat", exact=True).click()
            expect(page.get_by_role("heading", name="Referral cat", exact=True)).to_be_visible()
            expect(page.locator(".result-panel .referral-panel")).to_be_visible()
            # A referral shows grams only in the portions panel.
            expect(page.locator(".result-panel .portions")).not_to_contain_text("kcal")
            assert saved()["cats"][-1]["targetSource"] == "veterinarian"
            page.get_by_role("button", name="Remove cat", exact=True).click()
            expect(page.get_by_test_id("total-dry")).to_have_text("89 g")

            # Language switch.
            page.get_by_role("button", name="Deutsch", exact=True).click()
            expect(page.locator("html")).to_have_attribute("lang", "de")
            expect(page.get_by_role("button", name="Tagesplan", exact=True)).to_be_visible()
            expect(page.get_by_role("heading", level=1)).to_have_text("Der Futterplan für heute")
            page.get_by_role("button", name="Cat 1", exact=True).click()
            expect(page.locator(".estimate-view")).to_contain_text("Weitere Angaben nötig")
            shoot("desktop-light-cat-de")
            page.get_by_role("button", name="Futterliste", exact=True).click()
            expect(page.locator("form.food-editor").first).to_contain_text("Rohprotein")
            page.get_by_role("button", name="So wird gerechnet", exact=True).click()
            assert page.locator(".method-card math").count() >= 10, "Method formulas were not rendered"
            expect(page.get_by_role("link", name=re.compile("FEDIAF 2025"))).to_have_attribute("href", re.compile("FEDIAF-Nutritional-Guidelines_2025"))
            expect(page.get_by_role("link", name=re.compile("Godfrey"))).to_have_attribute("href", re.compile("0264321"))

            assert page.locator(".math-fallback").count() == 0, "A German formula failed to render"
            shoot("desktop-light-method-de")
            page.get_by_role("button", name="English", exact=True).click()
            expect(page.locator("html")).to_have_attribute("lang", "en")
            assert page.locator(".math-fallback").count() == 0, "An English formula failed to render"
            page.get_by_role("button", name="Daily plan", exact=True).click()

            # Layout checks at 390 px.
            page.set_viewport_size({"width": 390, "height": 844})
            assert page.evaluate("document.documentElement.scrollWidth <= window.innerWidth"), "Page overflows mobile viewport"
            expect(page.get_by_test_id("total-dry")).to_be_visible()
            shoot("mobile-light-household")
            page.get_by_role("button", name="Cat 3", exact=True).click()
            assert page.evaluate("document.documentElement.scrollWidth <= window.innerWidth"), "Cat page overflows mobile viewport"
            expect(page.locator(".mini-warnings")).to_be_visible()
            shoot("mobile-light-cat")
            page.locator('[name="cat-target"]').fill("50")
            expect(page.get_by_test_id("cat-preview-dry")).to_have_text("0 g")
            expect(page.locator(".result-panel")).to_contain_text("over the target")
            page.get_by_role("button", name="Discard edits", exact=True).click()
            page.get_by_role("button", name="How it works", exact=True).click()
            assert page.evaluate("document.documentElement.scrollWidth <= window.innerWidth"), "Method page overflows mobile viewport"
            shoot("mobile-light-method")
            page.get_by_role("button", name="+ Add a cat", exact=True).click()
            shoot("mobile-light-wizard")
            page.keyboard.press("Escape")
            expect(wizard).to_have_count(0)

            # Dark mode.
            page.emulate_media(color_scheme="dark")
            page.get_by_role("button", name="Daily plan", exact=True).click()
            expect(page.get_by_test_id("total-dry")).to_have_text("89 g")
            shoot("mobile-dark-household")
            page.get_by_role("button", name="Cat 1", exact=True).click()
            shoot("mobile-dark-cat")
            page.set_viewport_size({"width": 1440, "height": 1080})
            shoot("desktop-dark-cat")
            page.get_by_role("button", name="Daily plan", exact=True).click()
            shoot("desktop-dark-household")
            page.get_by_role("button", name="+ Add a cat", exact=True).click()
            shoot("desktop-dark-wizard")
            page.keyboard.press("Escape")
            assert not errors, errors
            browser.close()
            print("PASS: calculation, estimator, weight log, use-estimate, editing, imports, food analysis, units, activities, "
                  "quick add, guided setup (ok and referral), German, mobile, dark mode.")
            print("Mode:", "isolated built assets + Storage test double" if args.isolated else "real HTTP origin + real browser storage/reload")
    finally:
        if server:
            server.terminate()
            server.wait(timeout=5)


if __name__ == "__main__":
    main()
