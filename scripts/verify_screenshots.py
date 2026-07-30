"""App Store 스크린샷 규격 검증.

CI에서만 만들어지는 산출물이라(맥이 없어 로컬 촬영 불가) 검증만이라도
독립 스크립트로 빼서 로컬에서 시험할 수 있게 한다.

사용: python scripts/verify_screenshots.py [디렉터리]
"""

import glob
import os
import struct
import sys

# Windows 콘솔 기본 인코딩(cp1252)에서는 한글 print가 UnicodeEncodeError로 죽어
# 검증이 통과해도 exit 1이 된다. CI(UTF-8)에선 안 드러나므로 여기서 못박는다.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# 6.9인치 슬롯이 받는 크기. 1320x2868이 기본, 1290x2796은 6.7인치 대체본.
ALLOWED = {(1320, 2868), (1290, 2796)}
MIN_COUNT = 3  # App Store가 요구하는 최소 장수


def png_size(path):
    """PNG 헤더에서 (width, height)를 읽는다. 시그니처 8B + IHDR 길이/타입 8B 다음."""
    with open(path, "rb") as fh:
        head = fh.read(24)
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"PNG가 아님: {path}")
    return struct.unpack(">II", head[16:24])


def main(directory):
    files = sorted(glob.glob(os.path.join(directory, "*.png")))
    if not files:
        print(f"::error::{directory}/ 에 PNG가 없습니다 — 촬영 자체가 실패했습니다")
        return 1

    bad = []
    for path in files:
        try:
            w, h = png_size(path)
        except ValueError as e:
            print(f"  [BAD] {os.path.basename(path)}  {e}")
            bad.append(path)
            continue
        ok = (w, h) in ALLOWED
        print(f"  [{'OK ' if ok else 'BAD'}] {os.path.basename(path)}  {w}x{h}")
        if not ok:
            bad.append(path)

    print(f"총 {len(files)}장, 규격 위반 {len(bad)}장")

    failed = False
    if len(files) < MIN_COUNT:
        print(f"::error::App Store는 최소 {MIN_COUNT}장을 요구합니다 (현재 {len(files)}장)")
        failed = True
    if bad:
        allowed = " 또는 ".join(f"{w}x{h}" for w, h in sorted(ALLOWED))
        print(f"::error::App Store가 거부하는 해상도입니다. 허용: {allowed}")
        failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "screenshots"))
