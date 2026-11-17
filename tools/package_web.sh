#!/usr/bin/env bash
# 웹 빌드 + itch.io 업로드용 zip(개발 도구). 테스트를 먼저 돌리고, 통과하면 build/web으로 내보내 zip으로 묶는다.
#   GODOT=/경로/Godot_v4.7.2-stable tools/package_web.sh          (테스트 건너뛰기: --skip-tests)
# 결과: build/echo-loop-web-<버전>.zip  → itch.io "HTML" 프로젝트에 올리고 "This file will be played in the browser",
#       Viewport 720x1280(또는 360x640), "Mobile friendly"·"Fullscreen button" 체크.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
VERSION=$(grep -o 'GAME_VERSION: String = "[^"]*"' autoload/playtest.gd | cut -d'"' -f2)

if [ "${1:-}" != "--skip-tests" ]; then
  echo "테스트 실행…"
  "$GODOT" --headless --editor --path . --quit >/dev/null 2>&1 || true
  "$GODOT" --headless --fixed-fps 60 --path . -s tests/run_all.gd > build/test_log.txt 2>&1 \
    || { echo "테스트 실패: build/test_log.txt 확인"; grep -E "FAIL" build/test_log.txt | head; exit 1; }
  grep -E "TOTAL FAILS" build/test_log.txt
fi

rm -rf build/web && mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html >/dev/null 2>&1
[ -s build/web/index.pck ] || { echo "내보내기 실패: export templates(4.7.2 web_nothreads)가 설치됐는지 확인"; exit 1; }
if grep -qa "res://tests/" build/web/index.pck; then echo "경고: tests/가 pck에 들어갔다(제외 필터 확인)"; exit 1; fi

ZIP="build/echo-loop-web-$VERSION.zip"
rm -f "$ZIP"
(cd build/web && python3 -c "
import zipfile, os, sys
z = zipfile.ZipFile(sys.argv[1], 'w', zipfile.ZIP_DEFLATED)
for f in sorted(os.listdir('.')):
    z.write(f)
z.close()" "../$(basename "$ZIP")")
echo "완료: $ZIP ($(du -h "$ZIP" | cut -f1)) — index.html이 zip 맨 위에 있다"
