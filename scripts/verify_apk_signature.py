"""릴리스 APK가 debug 키가 아닌 앱 서명 키로 서명됐는지 확인한다.

android/app/build.gradle.kts는 android/key.properties가 없으면 release를 debug 키로
서명한다(로컬 `flutter run --release`를 위해). CI에서 키 복원이 조용히 어긋나도 빌드는
성공하므로, 결과물의 서명을 직접 확인한다. 이 앱은 GitHub Release의 APK를 폰에 직접
설치하므로 서명 키가 곧 앱의 신원이다 — 다른 키로 서명된 APK는 기존 앱 위에 설치되지
않고, 그걸 풀려고 앱을 지우면 기록이 사라진다(docs/deployment.md §6-A).

minSdk 24 이상의 APK에는 v2 서명만 있어 keytool -printcert -jarfile로는 읽지 못한다.
그래서 apksigner로 검증하고 인증서를 읽는다.

debug 키가 아니라는 것만으로는 부족하다. 시크릿에 백업과 다른 키가 들어가면 그 키로 서명된
APK가 폰의 신원이 되고, 백업은 쓸모가 없어진다. 그래서 --expect-sha256으로 백업 파일에서 계산한
인증서 지문을 받아 대조한다(CI는 저장소 변수 ANDROID_CERT_SHA256을 넘긴다 — docs/deployment.md §3-2).
지문은 콜론·대소문자를 무시하고 비교하므로 keytool이 찍는 "42:7A:…" 그대로 넣어도 된다.

사용: python scripts/verify_apk_signature.py [--expect-sha256 지문] <app-release.apk>
apksigner는 APKSIGNER 환경 변수 → PATH → ANDROID_HOME·ANDROID_SDK_ROOT·
%LOCALAPPDATA%/Android/Sdk 아래 가장 높은 build-tools 순으로 찾는다.
종료 코드: 0 앱 서명 키로 서명됨(지문을 받았으면 일치까지) · 1 서명 없음·검증 실패·debug 키·지문 불일치·도구 없음 · 2 사용법
"""

import argparse
import os
import pathlib
import re
import shutil
import subprocess
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# apksigner는 DN을 "C=US, O=Android, CN=Android Debug" 순서로 찍는다 — 앞머리가 아니라 포함 여부로 본다.
DEBUG_CN = "CN=Android Debug"
SIGNER_LINE = re.compile(r"Signer #(\d+) certificate (DN|SHA-256 digest): (.+)")


def _version_key(path):
    return tuple(int(part) if part.isdigit() else 0 for part in re.split(r"[.\-]", path.name))


def find_apksigner():
    explicit = os.environ.get("APKSIGNER")
    if explicit:
        return explicit
    for name in ("apksigner", "apksigner.bat"):
        on_path = shutil.which(name)
        if on_path:
            return on_path
    roots = [os.environ.get("ANDROID_HOME"), os.environ.get("ANDROID_SDK_ROOT")]
    local = os.environ.get("LOCALAPPDATA")
    if local:
        roots.append(str(pathlib.Path(local) / "Android" / "Sdk"))
    for root in filter(None, roots):
        build_tools = pathlib.Path(root) / "build-tools"
        if not build_tools.is_dir():
            continue
        for version in sorted(build_tools.iterdir(), key=_version_key, reverse=True):
            for name in ("apksigner", "apksigner.bat"):
                candidate = version / name
                if candidate.is_file():
                    return str(candidate)
    return None


def _normalize_sha256(value):
    """keytool("SHA256: 42:7A:…")·apksigner("427a…") 어느 표기든 소문자 16진수 64자로. 아니면 None."""
    stripped = re.sub(r"(?i)^\s*sha-?256\s*:", "", value)
    cleaned = re.sub(r"[\s:]", "", stripped).lower()
    return cleaned if re.fullmatch(r"[0-9a-f]{64}", cleaned) else None


def main(argv):
    parser = argparse.ArgumentParser(description="릴리스 APK가 앱 서명 키로 서명됐는지 확인한다")
    parser.add_argument("apk")
    parser.add_argument("--expect-sha256", help="백업한 앱 서명 인증서의 SHA-256 지문")
    args = parser.parse_args(argv[1:])
    expected = None
    if args.expect_sha256 is not None:
        expected = _normalize_sha256(args.expect_sha256)
        if expected is None:
            print(f"::error::기대 지문이 SHA-256(16진수 64자)이 아닙니다: {args.expect_sha256!r}")
            return 2
    apk = pathlib.Path(args.apk)
    if not apk.is_file():
        print(f"::error::{apk} 가 없습니다")
        return 1
    apksigner = find_apksigner()
    if apksigner is None:
        print("::error::apksigner를 찾지 못했습니다 — APKSIGNER·PATH·ANDROID_HOME을 확인하세요")
        return 1

    try:
        result = subprocess.run(
            [apksigner, "verify", "--print-certs", str(apk)],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except OSError as error:
        print(f"::error::apksigner를 실행하지 못했습니다({apksigner}): {error}")
        return 1
    if result.returncode != 0:
        # JDK의 'restricted method' 경고 줄은 원인이 아니라서 건너뛰고 첫 오류 줄을 보여 준다.
        detail = next(
            (
                line.strip()
                for line in (result.stderr + result.stdout).splitlines()
                if line.strip() and not line.startswith("WARNING")
            ),
            "",
        )
        print(f"::error::APK 서명 검증 실패 — 서명이 없거나 깨졌습니다: {apk}")
        if detail:
            print(f"  {detail}")
        return 1

    signers = {}
    for line in result.stdout.splitlines():
        match = SIGNER_LINE.match(line.strip())
        if match:
            signers.setdefault(match.group(1), {})[match.group(2)] = match.group(3).strip()
    if not signers or any("DN" not in signer for signer in signers.values()):
        print(f"::error::서명 인증서를 읽지 못했습니다: {apk}")
        return 1
    if any(DEBUG_CN in signer["DN"] for signer in signers.values()):
        print("::error::debug 키로 서명된 APK입니다 — android/key.properties가 빌드에 쓰이지 않았습니다")
        return 1

    if expected is not None:
        actual = {_normalize_sha256(signer.get("SHA-256 digest", "")) for signer in signers.values()}
        if actual != {expected}:
            print(
                "::error::서명 키 지문이 백업한 키와 다릅니다 — 시크릿 ANDROID_KEYSTORE_BASE64와 "
                "변수 ANDROID_CERT_SHA256이 같은 키 파일에서 나왔는지 확인하세요"
            )
            print(f"  기대 {expected}")
            for fingerprint in sorted(actual, key=str):
                print(f"  실제 {fingerprint}")
            return 1

    print("앱 서명 키 확인:" if expected is None else "앱 서명 키 확인(지문 일치):")
    for number in sorted(signers):
        signer = signers[number]
        print(f"  {signer['DN']}")
        if "SHA-256 digest" in signer:
            print(f"  SHA-256 {signer['SHA-256 digest']}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
