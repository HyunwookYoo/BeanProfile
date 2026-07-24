# Blend OCR Test Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build one self-contained HTML file that shows both the B realistic two-column blend card and the C high-density stress card for on-device camera OCR testing.

**Architecture:** A single semantic coffee-card DOM contains the shared ground-truth values. CSS switches its layout between B and C and its palette between light and dark-low-contrast, so all four test states keep identical data. Small vanilla-JavaScript handlers control card mode, contrast, URL state, and card-only fullscreen without adding dependencies or changing Flutter code.

**Tech Stack:** HTML5, CSS, vanilla JavaScript, Microsoft Edge headless rendering for verification

## Global Constraints

- Create only `docs/mockups/ocr-blend-test-cards.html`; do not modify Flutter, OCR parser, database, or test fixture files.
- Keep the card at a `3:4` aspect ratio.
- Use no external fonts, images, JavaScript, CDN, or network resource.
- Provide `B 실제형` and `C 스트레스형`.
- Provide `밝은 배경` and `어두운 저대비` for both layouts.
- Provide a card-only fullscreen action usable by mouse and touch.
- Use exactly the approved ground-truth data from `docs/superpowers/specs/2026-07-25-ocr-blend-test-cards-design.md`.

---

## File Structure

- Create: `docs/mockups/ocr-blend-test-cards.html`
  - Owns the control panel, shared test-card markup, all B/C and contrast styling, fullscreen behavior, usage guidance, and ground-truth reference.
- Read only: `docs/superpowers/specs/2026-07-25-ocr-blend-test-cards-design.md`
  - Source of approved layout, data, and non-goals.
- Read only: `assets/test/ocr_blend_en.png`, `assets/test/ocr_dark_blend_en.png`
  - Existing contrast baseline; neither file changes.

### Task 1: Build and verify the standalone blend test-card HTML

**Files:**
- Create: `docs/mockups/ocr-blend-test-cards.html`
- Reference: `docs/superpowers/specs/2026-07-25-ocr-blend-test-cards-design.md`

**Interfaces:**
- Consumes: URL query parameters `card=b|c` and `contrast=light|dark`
- Produces: `setCardMode(mode)`, `setContrast(mode)`, `toggleCardFullscreen()`, and `applyState()` browser functions
- Produces: one `#coffee-card` element whose `data-card` and `data-contrast` attributes fully determine the visible capture target

- [ ] **Step 1: Confirm the implementation target is absent and the repository scope is clean**

Run:

```powershell
Test-Path docs/mockups/ocr-blend-test-cards.html
git -c safe.directory=C:/BeanProfile status --short
```

Expected:

- `Test-Path` prints `False`.
- Only the implementation-plan files and pre-existing user-owned untracked files appear; no Flutter file is modified.

- [ ] **Step 2: Create the shared semantic card structure**

Create `docs/mockups/ocr-blend-test-cards.html` as a complete document beginning with:

```html
<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>BeanProfile — 블렌드 OCR 테스트 카드</title>
</head>
<body>
  <main class="tester">
    <section class="controls" aria-label="테스트 카드 설정">
      <div class="segmented" aria-label="카드 레이아웃">
        <button type="button" data-card-button="b">B 실제형</button>
        <button type="button" data-card-button="c">C 스트레스형</button>
      </div>
      <div class="segmented" aria-label="카드 대비">
        <button type="button" data-contrast-button="light">밝은 배경</button>
        <button type="button" data-contrast-button="dark">어두운 저대비</button>
      </div>
      <button type="button" id="fullscreen-button">카드만 전체화면</button>
    </section>

    <section class="capture-stage">
      <article id="coffee-card" data-card="b" data-contrast="light">
        <header class="card-header">
          <p class="roaster">BEANPROFILE LAB</p>
          <p class="type">BLEND</p>
          <h1>DAYBREAK HOUSE BLEND</h1>
        </header>

        <section class="components" aria-label="블렌드 구성">
          <article class="component component-one">
            <p class="component-number">COMPONENT 01</p>
            <h2>BRAZIL <strong>60%</strong></h2>
            <dl>
              <div><dt>지역</dt><dd>CERRADO</dd></div>
              <div><dt>가공</dt><dd>NATURAL</dd></div>
            </dl>
          </article>
          <article class="component component-two">
            <p class="component-number">COMPONENT 02</p>
            <h2>ETHIOPIA <strong>40%</strong></h2>
            <dl>
              <div><dt>지역</dt><dd>GUJI</dd></div>
              <div><dt>가공</dt><dd>WASHED</dd></div>
            </dl>
          </article>
        </section>

        <footer class="card-footer">
          <dl class="roast-data">
            <div><dt>로스팅</dt><dd>MEDIUM</dd></div>
            <div><dt>로스팅일</dt><dd>2026.07.24</dd></div>
          </dl>
          <div class="notes">
            <p>컵노트</p>
            <strong>COCOA, BERRY, JASMINE</strong>
          </div>
        </footer>
      </article>
    </section>
  </main>
</body>
</html>
```

Add a ground-truth reference below the capture stage. It must be outside `#coffee-card`, so it never enters a camera frame in card-only fullscreen.

- [ ] **Step 3: Style the common shell and B realistic layout**

Use local system fonts only:

```css
:root {
  color-scheme: light dark;
  --page: #171513;
  --panel: #24211e;
  --accent: #b67b2e;
}

#coffee-card {
  aspect-ratio: 3 / 4;
  width: min(78vw, 66vh, 720px);
  overflow: hidden;
  background: #f5f2e8;
  color: #19140f;
}

#coffee-card[data-card="b"] .components {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
}
```

The B state must:

- emphasize `DAYBREAK HOUSE BLEND`;
- show `BRAZIL 60%` and `ETHIOPIA 40%` as equal-weight columns;
- keep `REGION/PROCESS` data aligned within each component;
- place roast data and cup notes in a clearly separated footer;
- remain readable without decorative imagery.

- [ ] **Step 4: Add the C high-density stress layout**

Switch only CSS based on `data-card="c"`:

```css
#coffee-card[data-card="c"] {
  display: grid;
  grid-template-columns: 0.34fr 1fr;
  grid-template-areas:
    "rail header"
    "rail components"
    "rail footer";
}

#coffee-card[data-card="c"] .components {
  display: grid;
  grid-template-columns: 1fr;
}

#coffee-card[data-card="c"] .component dl > div {
  display: grid;
  grid-template-columns: 0.42fr 1fr;
}
```

The C state must:

- use smaller type and tighter row spacing than B;
- repeat labels in a dense table-like structure;
- include thin rules and non-essential microcopy in a side rail;
- preserve horizontal text and undistorted glyphs so the test targets layout density rather than camera perspective;
- display the same approved values as B.

- [ ] **Step 5: Add normal and dark-low-contrast palettes**

Use attribute-driven palette tokens:

```css
#coffee-card[data-contrast="light"] {
  --card-bg: #f5f2e8;
  --card-ink: #19140f;
  --card-muted: #756858;
  --card-rule: #d8cfbf;
}

#coffee-card[data-contrast="dark"] {
  --card-bg: #26262a;
  --card-ink: #3a3a3e;
  --card-muted: #35353a;
  --card-rule: #303035;
}

#coffee-card {
  background: var(--card-bg);
  color: var(--card-ink);
}
```

The dark state must remain faintly readable to the eye and intentionally resemble the luminance range of `assets/test/ocr_dark_blend_en.png`.

- [ ] **Step 6: Add deterministic controls, URL state, and fullscreen**

Implement the approved public functions:

```js
const card = document.querySelector('#coffee-card');

function applyState() {
  const params = new URLSearchParams(location.search);
  const cardMode = params.get('card') === 'c' ? 'c' : 'b';
  const contrast = params.get('contrast') === 'dark' ? 'dark' : 'light';
  card.dataset.card = cardMode;
  card.dataset.contrast = contrast;
  document.querySelectorAll('[data-card-button]').forEach((button) => {
    button.setAttribute('aria-pressed', String(button.dataset.cardButton === cardMode));
  });
  document.querySelectorAll('[data-contrast-button]').forEach((button) => {
    button.setAttribute('aria-pressed', String(button.dataset.contrastButton === contrast));
  });
}

function setCardMode(mode) {
  const params = new URLSearchParams(location.search);
  params.set('card', mode === 'c' ? 'c' : 'b');
  history.replaceState(null, '', `?${params}`);
  applyState();
}

function setContrast(mode) {
  const params = new URLSearchParams(location.search);
  params.set('contrast', mode === 'dark' ? 'dark' : 'light');
  history.replaceState(null, '', `?${params}`);
  applyState();
}

async function toggleCardFullscreen() {
  if (document.fullscreenElement) {
    await document.exitFullscreen();
  } else {
    await card.requestFullscreen();
  }
}
```

Wire every button with `addEventListener`, call `applyState()` once, and add a `fullscreenchange` listener that updates the fullscreen button label.

- [ ] **Step 7: Run deterministic structural checks**

Run:

```powershell
$mockup = Get-Content -Raw docs/mockups/ocr-blend-test-cards.html
$required = @(
  'id="coffee-card"',
  'data-card="b"',
  'data-contrast="light"',
  'DAYBREAK HOUSE BLEND',
  'BRAZIL',
  '60%',
  'ETHIOPIA',
  '40%',
  'CERRADO',
  'NATURAL',
  'GUJI',
  'WASHED',
  'MEDIUM',
  '2026.07.24',
  'COCOA, BERRY, JASMINE',
  'function setCardMode',
  'function setContrast',
  'function toggleCardFullscreen'
)
foreach ($needle in $required) {
  if (-not $mockup.Contains($needle)) { throw "Missing required marker: $needle" }
}
if ($mockup -match '(src|href)=\"https?://') {
  throw 'External resource found'
}
'Structural checks passed'
```

Expected: `Structural checks passed`.

- [ ] **Step 8: Render every test state with headless Edge**

Create screenshots outside the repository:

```powershell
$edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$base = 'file:///C:/BeanProfile/docs/mockups/ocr-blend-test-cards.html'
& $edge --headless=new --disable-gpu --hide-scrollbars --window-size=1440,1100 --screenshot=C:\tmp\beanprofile-b-light.png "$base?card=b&contrast=light"
& $edge --headless=new --disable-gpu --hide-scrollbars --window-size=1440,1100 --screenshot=C:\tmp\beanprofile-b-dark.png "$base?card=b&contrast=dark"
& $edge --headless=new --disable-gpu --hide-scrollbars --window-size=1440,1100 --screenshot=C:\tmp\beanprofile-c-light.png "$base?card=c&contrast=light"
& $edge --headless=new --disable-gpu --hide-scrollbars --window-size=1440,1100 --screenshot=C:\tmp\beanprofile-c-dark.png "$base?card=c&contrast=dark"
& $edge --headless=new --disable-gpu --hide-scrollbars --window-size=390,844 --screenshot=C:\tmp\beanprofile-mobile.png "$base?card=b&contrast=light"
```

Expected: five non-empty PNG files under `C:\tmp`.

Inspect every screenshot and verify:

- no text or card edge is clipped;
- B is visibly two-column and C is visibly denser;
- all four layout/contrast combinations show identical ground-truth values;
- mobile controls wrap and the `3:4` card fits the viewport;
- dark text is intentionally low contrast but not visually absent.

- [ ] **Step 9: Verify repository scope and commit**

Run:

```powershell
git -c safe.directory=C:/BeanProfile diff --check
git -c safe.directory=C:/BeanProfile status --short
```

Expected: only `docs/mockups/ocr-blend-test-cards.html` is new for this implementation task, plus pre-existing user-owned untracked files.

Commit:

```powershell
git -c safe.directory=C:/BeanProfile add -- docs/mockups/ocr-blend-test-cards.html
git -c safe.directory=C:/BeanProfile commit -m "docs(ocr): add blend test cards"
```
