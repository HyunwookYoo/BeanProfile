# BeanProfile — Project Instructions

Personal, offline coffee-bean **profile & tasting journal** app for **iOS + Android**.
Solo developer, personal use only — no store release, no accounts, no backend.

## Memory management (MANDATORY)

- Use **agentmemory ONLY** for this project's memory. Do **not** use the file-based memory store.
- **Every `memory_save` MUST**: prefix the body with `[BeanProfile]` and include the concept tag `BeanProfile` (alongside other concepts). This is what isolates BeanProfile memories from other projects.
- **Every `memory_recall` MUST** include `BeanProfile` in the query to keep results scoped.
- Rationale: `memory_save` is effectively global; the tag + prefix provide the isolation.

## Confirmed design decisions (brainstorming, 2026-07-14)

- **Tech stack:** Flutter (single codebase, native-class performance via AOT).
- **Scope:** personal-use, fully offline, **local-only** storage, no accounts.
- **Photo → data:** on-device OCR (`google_mlkit_text_recognition`) + manual field correction (semi-automatic: OCR drafts text, app auto-guesses clear patterns like country / roast-date, user assigns the rest).
- **Data model:** one **Bean** → many **Tasting** sessions.
- **Evaluation:** 4 intensity axes (acidity, sweetness, body, bitterness; 1–5) + overall satisfaction star (1–5) + free comment.
- **Analytics:** "taste profile" from the user's **own logged data only** (no external catalog).

## Documentation

Project docs live in **`docs/`**. The approved v1 design is at **`docs/design.md`**. Put future docs (implementation plan, notes, etc.) in `docs/`.

Render any doc to themed HTML (the app's cupping-lab theme, light/dark) with **`python scripts/md2html.py <path.md>`** (or `--all` for every `.md` under `docs/`); it writes a sibling `.html`. Publish that `.html` as an Artifact to view it in a browser.

Testing convention (3 layers, shared `test/helpers.dart`, Windows sqlite3 setup, GitHub Actions CI at `.github/workflows/test.yml`) lives in **`docs/testing.md`**; every milestone follows it.

Deployment convention (`v*` tag push → Android APK via GitHub Release + iOS via TestFlight) lives in **`docs/deployment.md`**; it also holds the one-time Android/Apple signing setup runbook.

## Deployment constraints (approved 2026-07-15)

- **Dev machine is Windows, no Mac.** Local iOS builds are impossible — the CI macOS runner *is* the Mac. If the pipeline breaks, iOS does not exist. Android CI is mere convenience by comparison.
- **Apple Developer Program ($99/yr) is a hard gate** for iOS: free Apple IDs expire profiles in 7 days and have no App Store Connect API, so tag-push automation cannot work without it.
- **GitHub repo must stay public** — macOS runners are free for public repos; private would cap iOS at ~10 builds/month (10× minute multiplier).
- **Bundle ID `com.hyunwook.beanprofile` is permanent.** Changing it later orphans app data on both platforms.
- **The Android keystore guards the user's data.** Signature mismatch forces uninstall → wipes the local-only DB. Back it up in ≥2 places.
- **TestFlight builds expire in 90 days** — a permanent ~quarterly tag-push tax after development ends. Certs need annual renewal.

## Status

v1 design + UI mockup approved. Implementation plan is milestone-based: roadmap at `docs/plans/roadmap.md`, **M1 (bean add/list/detail) detailed at `docs/plans/milestone-1-foundation.md`**, **M0 (deployment pipeline) designed at `docs/deployment.md`** — plan written just-in-time. M2–M5 written just-in-time. `flutter create` moved from M1 Task 1 into M0. **M0 DONE** — `v0.0.1` hello-world installs on iPhone via free-Apple-ID AltStore. **M1 code COMPLETE** (2026-07-18): drift 3-table DB + repository/providers + theme·3-tab shell + bean add(manual)→list→detail(read-only); 15 tests green, `flutter analyze` 0; per-task + whole-branch reviewed. Pending: on-device DoD run (real `driftDatabase` boot / e2e loop untested locally — no local mobile target). Next: **M2** (edit/delete + tasting records) — plan just-in-time; M2-prep fixes recorded in agentmemory. Latest decisions live in agentmemory under the `BeanProfile` tag.
