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

v1 design + UI mockup approved. Implementation plan is milestone-based: roadmap at `docs/plans/roadmap.md`, **M1 (bean add/list/detail) detailed at `docs/plans/milestone-1-foundation.md`**, **M0 (deployment pipeline) designed at `docs/deployment.md`** — plan written just-in-time. M2–M5 written just-in-time. `flutter create` moved from M1 Task 1 into M0. **M0 DONE** — `v0.0.1` hello-world installs on iPhone via free-Apple-ID AltStore. **M1 code COMPLETE** (2026-07-18): drift 3-table DB + repository/providers + theme·3-tab shell + bean add(manual)→list→detail(read-only); 15 tests green, `flutter analyze` 0; per-task + whole-branch reviewed. **M1 DONE** — `v0.1.0` installed on iPhone via AltStore; on-device add→list→detail + persistence-across-restart confirmed by user (2026-07-18). **M2 DONE** — `v0.2.0`: bean edit/delete + tasting full CRUD (강도 4축 + 종합 별점 + 코멘트) + detail average★; 7 SDD tasks + opus whole-branch review; 34 tests green. **M2.1 DONE** — `v0.2.1`: keyboard dismiss (tap-outside + scroll) + swipe-to-delete (tasting = Undo SnackBar / bean = confirm dialog, shared `delete_ux.dart`); 3 SDD tasks + opus review; 39 tests green. Both installed on iPhone via AltStore, **on-device DoD confirmed by user (2026-07-19)**. Docs: `docs/plans/milestone-2-{design,plan}.md` (M2) · `docs/plans/milestone-2.1-ux-{design,plan}.md` + mockup `docs/mockups/m2-ux-improvements.html` (M2.1). Reusable gotchas (drift FK, Riverpod 3.x, autoDispose-pop test deadlock, Dismissible+reactive-list `confirmDismiss→false`, Flutter 3.44.6 focus test, md2html indented-fence) in agentmemory. **M3 DONE** — `v0.3.0`: 촬영/갤러리 → ML Kit 온디바이스 OCR → 자동 필드 + 배정 칩 리뷰 폼; 6 SDD tasks + opus review. **M3.1 DONE** — `v0.3.1`: 칩 배정 UX 재설계(취약한 포커스-먼저 → 칩-먼저 모달 시트, 6개 대상). **M3.2 DONE** — `v0.3.2`: `지역:/Region:` 라벨 기반 지역 자동채움. **M3.3 DONE** — `v0.3.3`, **온디바이스 자동 인식 확인됨 (사용자, 2026-07-20)**: **좌표 기반 OCR 파싱**. ML Kit은 2열 카드(라벨 열 | 값 열, 콜론 없음)를 "라벨 전체 → 값 전체" 순서로 직렬화하므로 텍스트 순서만 쓰는 파서로는 라벨↔값을 못 묶는다 → `recognize`를 `List<OcrLine>`(boundingBox 좌표)로 확장하고 공간 매칭(같은 행·오른쪽 → 아래) + 타이포 제목/이브로우 추정으로 해결. **실제형 카드 4/8 → 8/8 자동채움**(지역·컵노트·제품명·로스터리가 신규), 콜론 카드 8/8 유지(콜론/키워드/칩 폴백 유지 = 비회귀). 4 SDD tasks + opus 전체-브랜치 리뷰(태스크 리뷰 4개를 뚫고 "below-폴백이 인접 라벨을 값으로 오채움" 버그 발견 → 수정·차등검증); 90 tests green, analyze 0. 앱 아이콘도 기본 Flutter → 적응형 원두 아이콘으로 교체(iOS 라이트/다크 + Android). 문서: `docs/plans/milestone-3-{design,plan}.md` · `milestone-3.1-ux-{design,plan}.md` · `milestone-3.2-region-plan.md` · `milestone-3.3-geometry-ocr-{design,plan}.md` + 목업 `docs/mockups/m3-photo-ocr.html`·`m3.1-chip-assign.html`. **에뮬레이터 통합테스트 워크플로 확보**: `flutter test integration_test/ocr_probe_test.dart -d emulator-5554` 로 publish→AltStore 사이클 없이 실제 ML Kit OCR을 로컬 검증(테스트 카드 `assets/test/ocr_card_{ko,orig}.png`); 실기기 좌표는 호스트 픽스처로 옮겨 에뮬 없이 CI 재현 가능. v0.3.3 이후 폼 UI 수정(미릴리스): 지역에 `OCR 자동` helper가 붙으면 `Row` 기본 center 정렬 탓에 helper 없는 가공 드롭다운이 10px 아래로 밀려 밑줄이 어긋나던 것 → `CrossAxisAlignment.start`. Next: **M4** (취향 대시보드). Latest decisions live in agentmemory under the `BeanProfile` tag.
