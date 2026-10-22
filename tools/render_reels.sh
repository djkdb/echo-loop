#!/usr/bin/env bash
# 릴스 영상 렌더(개발 도구). 스테이지마다 정답편·정답편 2배속·문제편을 Movie Maker로 찍고 ffmpeg로 1080x1920 mp4로 바꾼다.
#   tools/render_reels.sh level_2_2      (또는 2-2)
#   tools/render_reels.sh all
# 결과: build/reels/<stage>_answer.mp4, <stage>_answer_2x.mp4, <stage>_problem.mp4 (ffmpeg가 없으면 .avi까지만)
# 상단 문구는 tools/reels_copy.json. Godot 실행 파일은 환경 변수 GODOT(기본: PATH의 godot).
# 화면이 없는 서버에서는 xvfb-run이 있으면 자동으로 쓴다.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
OUT="build/reels"
mkdir -p "$OUT"

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
  echo "Godot 실행 파일을 찾지 못했다. GODOT=/경로/Godot_v4.7.2-stable 로 지정할 것." >&2
  exit 1
fi

RUN=()
if [ -z "${DISPLAY:-}" ] && [ "$(uname)" = "Linux" ] && command -v xvfb-run >/dev/null 2>&1; then
  RUN=(xvfb-run -a -s "-screen 0 1280x1400x24")
fi

HAVE_FFMPEG=1
command -v ffmpeg >/dev/null 2>&1 || HAVE_FFMPEG=0

# 스테이지 목록
if [ "${1:-}" = "" ]; then
  echo "사용법: tools/render_reels.sh <stage|all>   예) level_2_2, 2-2, all" >&2
  exit 1
elif [ "$1" = "all" ]; then
  STAGES=$(ls solutions/*.json | xargs -n1 basename | sed 's/\.json$//' | sort)
else
  s="$1"
  [[ "$s" =~ ^[0-9]-[0-9]$ ]] && s="level_${s/-/_}"
  STAGES="$s"
fi

# reels_copy.json에서 문구 만들기: copy <stage> <answer|problem|next>
copy() {
  python3 - "$1" "$2" <<'PY'
import json, sys
stage, kind = sys.argv[1], sys.argv[2]
copy = json.load(open("tools/reels_copy.json", encoding="utf-8"))
text = dict(copy["default"], **copy.get(stage, {}))[kind]
n = len(json.load(open(f"solutions/{stage}.json", encoding="utf-8"))["runs"]) - 1
# 숫자 끝소리에 맞는 조사: 1 일·7 칠·8 팔은 "로", 3 삼·6 육·0 영은 "으로", 나머지 받침 없음은 "로"
euro = "으로" if str(n)[-1] in "360" else "로"
print(text.replace("{n}", str(n)).replace("{으로}", euro))
PY
}

render() {  # render <out.avi> <scene> <args...>
  local out="$1" scene="$2"; shift 2
  echo "  렌더: $out"
  "${RUN[@]}" "$GODOT" --path . --rendering-driver opengl3 --resolution 720x1280 \
    --write-movie "$out" --fixed-fps 60 "$scene" -- "$@" >/dev/null 2>&1 || true
  [ -s "$out" ] || { echo "  실패: $out 이 비었다(Godot 출력은 위 명령을 직접 돌려 확인)" >&2; return 1; }
}

to_mp4() {  # to_mp4 <in.avi> <out.mp4>
  ffmpeg -y -loglevel error -i "$1" -vf "scale=1080:1920:flags=lanczos,format=yuv420p" \
    -c:v libx264 -preset medium -crf 18 -r 60 -c:a aac -b:a 160k -movflags +faststart "$2"
}

for st in $STAGES; do
  [ -f "solutions/$st.json" ] || { echo "정답 리플레이가 없다: solutions/$st.json" >&2; continue; }
  echo "== $st"
  A="$(copy "$st" answer)"; P="$(copy "$st" problem)"; N="$(copy "$st" next)"
  render "$OUT/${st}_answer.avi" res://game/replay.tscn \
    --stage="$st" --solution --reels --loops=1 --trim --seamless --text="$A"
  render "$OUT/${st}_problem.avi" res://tools/reels_problem.tscn \
    --stage="$st" --text="$P" --next-text="$N"
  if [ "$HAVE_FFMPEG" = 1 ]; then
    to_mp4 "$OUT/${st}_answer.avi" "$OUT/${st}_answer.mp4"
    ffmpeg -y -loglevel error -i "$OUT/${st}_answer.mp4" -filter_complex "[0:v]setpts=0.5*PTS[v];[0:a]atempo=2.0[a]" \
      -map "[v]" -map "[a]" -c:v libx264 -preset medium -crf 18 -r 60 -c:a aac -b:a 160k -movflags +faststart \
      "$OUT/${st}_answer_2x.mp4"
    to_mp4 "$OUT/${st}_problem.avi" "$OUT/${st}_problem.mp4"
    rm -f "$OUT/${st}_answer.avi" "$OUT/${st}_problem.avi"
    echo "  완료: $OUT/${st}_{answer,answer_2x,problem}.mp4"
  fi
done

if [ "$HAVE_FFMPEG" = 0 ]; then
  cat <<'MSG'

ffmpeg가 없어 .avi(720x1280)까지만 만들었다. mp4(1080x1920)·2배속은 ffmpeg를 설치한 뒤 다시 돌리면 된다.
  macOS:   brew install ffmpeg
  Windows: winget install Gyan.FFmpeg   (또는 https://ffmpeg.org/download.html)
  Ubuntu:  sudo apt install ffmpeg
MSG
fi
