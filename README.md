# ECHO LOOP

**10초 전의 나와 손잡고 방을 탈출하는 퍼즐.**

10초 동안의 내 움직임이 녹화되고, 루프가 끝날 때마다 방이 처음으로 돌아가며 방금의 나는 "과거의 나(고스트)"로 남아
그대로 다시 움직인다. 과거의 나를 밟고 올라서고, 압력판을 맡기고, 레이저 앞에 세워 방패로 쓰면서
지금의 나 한 명을 출구로 보내면 클리어. 세로 9:16 한 화면짜리 방 15개(3챕터).

> **플레이:** _(itch.io 링크 자리)_

기획서: [docs/design.pdf](docs/design.pdf)

## 조작

| 키보드 | 모바일 | 동작 |
| --- | --- | --- |
| ← → / A D | 왼쪽 아래 ◀ ▶ | 이동 |
| Space | 오른쪽 아래 ▲ | 점프 |
| E | 오른쪽 아래 E | 레버·시한 버튼, CLEAR 뒤 다음 스테이지 |
| R | 위 시간 바 길게 누르기 | 루프 끝내기(지금의 나를 고스트로 남김), CLEAR 뒤 다시 |
| Backspace | 오른쪽 위 ↶ | 마지막 고스트 지우기 |
| 1 ~ 4 | 위 고스트 아이콘 탭 | 그 번호의 나를 다음 루프로 다시 찍기 |
| Shift + R | 오른쪽 위 ⟲ | 스테이지 처음부터 |
| Esc | 오른쪽 위 ≡ | 스테이지 선택으로 |
| F9 | — | 릴스 모드(HUD 숨김, 방을 릴스 화면에 맞춤) |
| F10 | — | (디버그 빌드) 가장 최근 고스트 강제 붕괴 — 촬영용 |

## 규칙 한눈에

- 고스트는 녹화된 **위치**를 그대로 따라간다. 녹화 때 지나간 길이 지금 막혀 있으면(닫힌 문) 패러독스로 붕괴한다.
- 출구에 닿을 수 있는 건 지금의 나뿐. 스테이지마다 고스트 상한(1~4명)이 있다.
- 별점: ★1 클리어 · ★2 상한보다 적은 고스트 · ★3 개발자 기록과 같거나 더 적게.

## 플레이 테스트 하는 법

1. 친구에게 플레이 링크를 보낸다(폰이면 브라우저에서 바로, 처음 터치하면 "전체 화면" 버튼이 잠깐 뜬다).
2. 다 했으면(또는 막혀서 그만두면) 타이틀 화면 왼쪽 아래 **"테스트 결과 복사"** → 카톡에 붙여 보내 달라고 한다.
   요약(스테이지별 클리어 시간·루프·되돌리기·처음부터·고스트·별)과 그 아래 `---` 뒤 JSON이 같이 복사된다.
   기록은 그 기기의 브라우저(user://playtest.json)에만 있고 어디로도 전송되지 않는다.
3. 받은 내용을 파일로 저장해 모아 본다:
   ```
   python3 tools/playtest_report.py 민수.txt 지은.txt 하준.txt
   ```
   스테이지별 시작·클리어 인원, 포기율, 클리어 시간 중앙값, 루프 중앙값이 표로 나온다.
   중앙값 5분 안이면 "적정", 10분 넘으면 "⚠ 10분 초과", 절반 넘게 못 깼으면 "포기 많음".

## 릴스 렌더

```
GODOT=/경로/Godot_v4.7.2-stable tools/render_reels.sh 2-2     # 또는 level_2_2, all
```

스테이지마다 `build/reels/`에 1080x1920 mp4 3개를 만든다(ffmpeg 필요, 없으면 720x1280 avi까지만 + 설치 안내).

- `<stage>_answer.mp4` 정답편: 개발자 정답 리플레이를 릴스 모드로, 상단 "과거의 나 ×N으로 탈출", 마지막 프레임이 첫 프레임으로 이어짐
- `<stage>_answer_2x.mp4` 정답편 2배속
- `<stage>_problem.mp4` 문제편: 방 2초 → 고스트 없이 첫 루프에서 실패 → "정답은 다음 릴스" 1.5초, 상단 "고스트 N명으로 깰 수 있을까?"

상단 문구는 `tools/reels_copy.json`에서 스테이지별로 바꾼다(`{n}` = 개발자 기록, `{으로}` = 숫자에 맞는 조사).
리눅스 서버처럼 화면이 없으면 xvfb-run을 자동으로 쓴다. 붕괴 장면을 직접 찍을 때는 게임에서 F10(디버그 빌드).

## 개발

- Godot 4.7.2, GDScript, Compatibility 렌더러, 뷰포트 720×1280. 규칙과 구조는 [CLAUDE.md](CLAUDE.md),
  레벨 설계 근거는 [docs/levels.md](docs/levels.md), 미뤄 둔 일은 [docs/BACKLOG.md](docs/BACKLOG.md).
- 자동 테스트: `godot --headless --fixed-fps 60 --path . -s tests/run_all.gd` (실패하면 종료 코드 1)
- 정답 리플레이 다시 만들기: `godot --headless --fixed-fps 60 --path . -s tests/run_all.gd -- --dir=bots`
- 정답 리플레이 보기(릴스 정답편 렌더):
  `godot --path . --write-movie out.avi --fixed-fps 60 res://game/replay.tscn -- --stage=level_2_2 --loops=1 --reels --solution`
- 웹 빌드: `godot --headless --path . --export-release "Web" build/web/index.html` (4.7.2 export templates의 web_nothreads 필요)

## 크레딧

- 글꼴: Noto Sans KR(서브셋), Space Grotesk — SIL Open Font License(`assets/fonts/*-OFL.txt`)
- 효과음: 코드로 합성(`autoload/sfx.gd`)
