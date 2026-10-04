"""release 스모크 — 진입점만 바꾼 release APK를 에뮬레이터에서 돌려 판정한다.

flutter drive는 release 모드를 거부하고 profile 빌드는 R8을 돌리지 않는다. 그래서 배포 빌드와
같은 Gradle·R8 설정에 진입점만 integration_test/release_smoke.dart로 바꾼 APK를 설치해 실행하고,
앱이 logcat에 남기는 BEANPROFILE_SMOKE 줄을 읽어 판정한다(docs/deployment.md §6-H).

실기기에는 설치하지 않는다. 스모크 APK는 배포 앱과 applicationId가 같아서, Play로 설치한 폰에서는
서명이 충돌하고 그걸 풀려고 앱을 지우면 시음 기록이 사라진다(docs/deployment.md §6-A).

먼저 빌드한다:
  flutter build apk --release --target-platform android-x64 \
    -t integration_test/release_smoke.dart --dart-define=ENABLE_OCR_DIAGNOSTICS=false
사용: python scripts/release_smoke.py [--apk 경로] [--serial emulator-5554] [--timeout 초]
종료 코드: 0 전부 통과 · 1 실패·크래시·시간 초과·설치 실패 · 2 사용법·환경 오류
"""

import argparse
import os
import pathlib
import shutil
import subprocess
import sys
import time

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

PACKAGE = "com.hyunwook.beanprofile"
ACTIVITY = f"{PACKAGE}/.MainActivity"
MARKER = "BEANPROFILE_SMOKE"
DEFAULT_APK = "build/app/outputs/flutter-apk/app-release.apk"
# integration_test/release_smoke.dart의 checks 맵과 같은 목록이다. 판정이 "무엇이 돌았는지"까지 봐야
# 검사가 빠지거나 logcat에서 밀려나도 조용히 통과하지 않으므로, 검사를 더하거나 빼거나 이름을 바꿀 때는
# 이 목록과 진입점의 맵을 함께 고친다.
CHECKS = (
    "ocr_card_ko",
    "ocr_card_orig",
    "ocr_blend_en",
    "ocr_dark_blend_en",
    "ocr_bad_quality_en",
    "sqlite",
)


def find_adb():
    explicit = os.environ.get("ADB")
    if explicit:
        return explicit
    on_path = shutil.which("adb")
    if on_path:
        return on_path
    roots = [os.environ.get("ANDROID_HOME"), os.environ.get("ANDROID_SDK_ROOT")]
    local = os.environ.get("LOCALAPPDATA")
    if local:
        roots.append(str(pathlib.Path(local) / "Android" / "Sdk"))
    for root in filter(None, roots):
        for name in ("adb", "adb.exe"):
            candidate = pathlib.Path(root) / "platform-tools" / name
            if candidate.is_file():
                return str(candidate)
    return None


def run_adb(adb, serial, *args, timeout=120):
    command = [adb] + (["-s", serial] if serial else []) + list(args)
    return subprocess.run(
        command,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )


def pick_emulator(adb, requested):
    """에뮬레이터 serial 하나를 고른다. 고르지 못하면 (None, 이유)."""
    # serial 모양으로 먼저 거른다 — 실기기에는 adb 명령을 하나도 보내지 않는다.
    if requested and not requested.startswith("emulator-"):
        return None, f"{requested}는 에뮬레이터가 아니다 — 실기기에는 설치하지 않는다"
    listed = run_adb(adb, None, "devices").stdout.splitlines()[1:]
    online = [line.split("\t")[0] for line in listed if line.strip().endswith("\tdevice")]
    emulators = [serial for serial in online if serial.startswith("emulator-")]
    if requested:
        if requested not in online:
            return None, f"{requested}가 연결돼 있지 않다 (연결됨: {', '.join(online) or '없음'})"
        serial = requested
    elif len(emulators) == 1:
        serial = emulators[0]
    else:
        return None, (
            "에뮬레이터를 하나만 띄우거나 --serial로 고른다 "
            f"(연결된 에뮬레이터: {', '.join(emulators) or '없음'})"
        )
    props = {
        run_adb(adb, serial, "shell", "getprop", key).stdout.strip()
        for key in ("ro.kernel.qemu", "ro.boot.qemu")
    }
    if "1" not in props:
        return None, f"{serial}가 에뮬레이터로 확인되지 않는다(ro.*.qemu) — 실기기에는 설치하지 않는다"
    return serial, None


def smoke_lines(adb, serial):
    log = run_adb(adb, serial, "logcat", "-d", "-v", "raw", "-s", "flutter:I").stdout
    return [line.strip() for line in log.splitlines() if line.strip().startswith(MARKER)]


def word(line, index):
    parts = line.split()
    return parts[index] if len(parts) > index else ""


def evaluate(lines):
    """BEANPROFILE_SMOKE 줄만으로 판정한다(adb도 I/O도 없다). (통과 여부, 사유 목록)을 돌려준다.

    증거가 모자라면 통과가 아니다. FATAL이 없고, CHECKS의 이름마다 `CHECK <이름> PASS`가 정확히
    한 줄이고, 목록에 없는 이름이나 PASS·FAIL이 아닌 판정이 없고, DONE이 정확히 한 줄이며 점수가
    CHECKS 개수의 n/n일 때만 통과한다.
    """
    reasons = []
    verdicts = {}  # 이름 -> 그 이름으로 나온 CHECK 판정 낱말들
    unexpected = []
    scores = []
    for line in lines:
        kind = word(line, 1)
        if kind == "FATAL":
            reasons.append(f"앱이 FATAL을 남겼다: {line.partition('FATAL')[2].strip()}")
        elif kind == "CHECK":
            name = word(line, 2)
            if name in CHECKS:
                verdicts.setdefault(name, []).append(word(line, 3))
            else:
                unexpected.append(name or "(이름 없음)")
        elif kind == "DONE":
            scores.append(word(line, 2))

    missing, repeated, failed, odd = [], [], [], []
    for name in CHECKS:
        found = verdicts.get(name, [])
        if not found:
            missing.append(name)
        if len(found) > 1:
            repeated.append(name)
        if "FAIL" in found:
            failed.append(name)
        odd += [f"{name}={verdict or '(없음)'}" for verdict in found if verdict not in ("PASS", "FAIL")]
    for label, names in (
        ("빠진 검사", missing),
        ("두 번 이상 나온 검사", repeated),
        ("실패한 검사", failed),
        ("PASS·FAIL이 아닌 판정", odd),
        ("목록에 없는 검사", unexpected),
    ):
        if names:
            reasons.append(f"{label}: {', '.join(names)}")

    expected = f"{len(CHECKS)}/{len(CHECKS)}"
    if len(scores) != 1:
        reasons.append(f"DONE 줄이 {len(scores)}개다 — 정확히 1개여야 한다")
    elif scores[0] != expected:
        reasons.append(f"DONE 점수가 다르다: {scores[0] or '(없음)'} (기대 {expected})")
    return not reasons, reasons


def main(argv):
    parser = argparse.ArgumentParser(description="release 스모크 APK를 에뮬레이터에서 돌려 판정한다")
    parser.add_argument("--apk", default=DEFAULT_APK)
    parser.add_argument("--serial")
    parser.add_argument("--timeout", type=int, default=240)
    args = parser.parse_args(argv[1:])

    adb = find_adb()
    if adb is None:
        print("::error::adb를 찾지 못했다 — ADB·PATH·ANDROID_HOME을 확인한다")
        return 2
    serial, reason = pick_emulator(adb, args.serial)
    if serial is None:
        print(f"::error::{reason}")
        return 2
    apk = pathlib.Path(args.apk)
    if not apk.is_file():
        print(f"::error::{apk}가 없다 — 먼저 스모크 진입점으로 빌드한다(-t integration_test/release_smoke.dart)")
        return 2

    install = run_adb(adb, serial, "install", "-r", str(apk), timeout=300)
    output = (install.stdout + install.stderr).strip()
    if install.returncode != 0 or "Success" not in output:
        print(f"::error::설치 실패 — {output}")
        if "INSTALL_FAILED_UPDATE_INCOMPATIBLE" in output:
            print(
                "에뮬레이터에 서명이 다른 같은 앱이 있다. 에뮬레이터라면 "
                f"`adb -s {serial} uninstall {PACKAGE}` 뒤 다시 실행한다."
            )
        return 1

    run_adb(adb, serial, "shell", "am", "force-stop", PACKAGE)
    run_adb(adb, serial, "logcat", "-c")
    # 지난 실행의 DONE 줄이 남아 있으면 거짓 통과가 된다 — 비워졌는지 확인하고 시작한다.
    if smoke_lines(adb, serial):
        print("::error::logcat을 비우지 못했다 — 지난 실행의 결과가 남아 있다")
        return 2
    run_adb(adb, serial, "shell", "am", "start", "-W", "-n", ACTIVITY)

    deadline = time.monotonic() + args.timeout
    try:
        while True:
            lines = smoke_lines(adb, serial)
            if any(word(line, 1) in ("DONE", "FATAL") for line in lines):
                break
            if not run_adb(adb, serial, "shell", "pidof", PACKAGE).stdout.strip():
                print("::error::결과 전에 앱 프로세스가 끝났다")
                for line in lines:
                    print(f"  {line}")
                crash = run_adb(adb, serial, "logcat", "-d", "-b", "crash").stdout.strip()
                print(crash[-3000:] or "(crash 버퍼 비어 있음)")
                return 1
            if time.monotonic() > deadline:
                print(f"::error::시간 초과 — {args.timeout}초 안에 {MARKER} DONE이 없다")
                for line in lines:
                    print(f"  {line}")
                return 1
            time.sleep(2)
    finally:
        run_adb(adb, serial, "shell", "am", "force-stop", PACKAGE)

    for line in lines:
        print(line)
    passed, reasons = evaluate(lines)
    if not passed:
        print("::error::release 스모크 실패")
        for reason in reasons:
            print(f"  - {reason}")
        return 1
    print(f"release 스모크 통과 — {len(CHECKS)}/{len(CHECKS)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
