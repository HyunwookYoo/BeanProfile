"""AAB가 debug 키가 아닌 업로드 키로 서명됐는지 확인한다.

android/app/build.gradle.kts는 android/key.properties가 없으면 release를 debug 키로
서명한다(로컬 `flutter run --release`를 위해). CI에서 키 복원이 조용히 어긋나도 빌드는
성공하므로, 결과물의 인증서를 직접 읽어 확인한다. Play는 처음 올린 AAB에 서명한 키를
업로드 키로 등록하므로 debug 서명 AAB는 업로드 전에 막아야 한다.

사용: python scripts/verify_aab_signature.py <app-release.aab>
keytool은 KEYTOOL 환경 변수 → PATH → JAVA_HOME/bin 순으로 찾는다.
"""

import os
import pathlib
import shutil
import subprocess
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

DEBUG_SUBJECT = "CN=Android Debug"


def find_keytool():
    explicit = os.environ.get("KEYTOOL")
    if explicit:
        return explicit
    on_path = shutil.which("keytool")
    if on_path:
        return on_path
    java_home = os.environ.get("JAVA_HOME")
    if java_home:
        for name in ("keytool", "keytool.exe"):
            candidate = pathlib.Path(java_home) / "bin" / name
            if candidate.is_file():
                return str(candidate)
    return None


def main(argv):
    if len(argv) != 2:
        print("사용: python scripts/verify_aab_signature.py <app-release.aab>")
        return 2
    aab = pathlib.Path(argv[1])
    if not aab.is_file():
        print(f"::error::{aab} 가 없습니다")
        return 1
    keytool = find_keytool()
    if keytool is None:
        print("::error::keytool을 찾지 못했습니다 — KEYTOOL·PATH·JAVA_HOME을 확인하세요")
        return 1

    # keytool은 로케일에 따라 '소유자:'/'Owner:'로 찍지만 DN은 ASCII라 CN= 이후만 본다.
    result = subprocess.run(
        [keytool, "-printcert", "-jarfile", str(aab)],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    output = result.stdout + result.stderr
    subjects = sorted(
        {line[line.index("CN="):].strip() for line in output.splitlines() if "CN=" in line}
    )

    if not subjects:
        print(f"::error::서명 인증서가 없습니다 — 서명되지 않은 AAB입니다: {aab}")
        return 1
    if any(subject.startswith(DEBUG_SUBJECT) for subject in subjects):
        print("::error::debug 키로 서명된 AAB입니다 — android/key.properties가 빌드에 쓰이지 않았습니다")
        return 1
    print("업로드 키 서명 확인:")
    for subject in subjects:
        print(f"  {subject}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
