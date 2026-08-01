"""docs/store-listing.md의 각 칸이 App Store Connect 글자 수 제한에 맞는지 검사한다.

초과분은 붙여넣는 순간 거부되므로, 문구를 고칠 때마다 여기서 먼저 확인한다.
한글은 1자로 센다(Apple도 문자 단위로 센다).

사용: python scripts/check_store_listing.py
"""

import pathlib
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

DOC = pathlib.Path(__file__).resolve().parent.parent / "docs" / "store-listing.md"

# 제목에 쓰인 말머리 -> 상한
LIMITS = {
    "이름": 30,
    "부제": 30,
    "프로모션 텍스트": 170,
    "설명": 4000,
    "키워드": 100,
}


def first_block_after(text, heading_prefix):
    """`## <말머리>` 다음에 오는 첫 번째 펜스 블록의 내용을 돌려준다."""
    m = re.search(r"^## " + re.escape(heading_prefix) + r"[^\n]*$", text, re.M)
    if not m:
        return None
    rest = text[m.end():]
    b = re.search(r"```[^\n]*\n(.*?)\n```", rest, re.S)
    return b.group(1) if b else None


def main():
    if not DOC.exists():
        print(f"::error::{DOC} 가 없습니다")
        return 1
    text = DOC.read_text(encoding="utf-8")

    failed = False
    for name, limit in LIMITS.items():
        body = first_block_after(text, name)
        if body is None:
            print(f"  [BAD] {name}: 값 블록을 찾지 못했습니다")
            failed = True
            continue
        n = len(body)
        ok = n <= limit
        bar = f"{n}/{limit}"
        print(f"  [{'OK ' if ok else 'BAD'}] {name:<12} {bar:>10}")
        if not ok:
            print(f"::error::{name}이(가) {n - limit}자 초과했습니다")
            failed = True

    # 키워드는 쉼표 구분에 공백이 없어야 한다(공백도 글자 수에 들어간다).
    kw = first_block_after(text, "키워드")
    if kw and ", " in kw:
        print("::error::키워드에 쉼표 뒤 공백이 있습니다 — 공백도 100자에 포함됩니다")
        failed = True

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
