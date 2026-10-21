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
| Backspace | — | 마지막 고스트 지우기 |
| 1 ~ 4 | 위 고스트 아이콘 탭 | 그 번호의 나를 다음 루프로 다시 찍기 |
| Shift + R | — | 스테이지 처음부터 |
| Esc | 오른쪽 위 ≡ | 스테이지 선택으로 |
| F9 | — | 릴스 모드(HUD 숨김, 방을 릴스 화면에 맞춤) |

## 규칙 한눈에

- 고스트는 녹화된 **위치**를 그대로 따라간다. 녹화 때 지나간 길이 지금 막혀 있으면(닫힌 문) 패러독스로 붕괴한다.
- 출구에 닿을 수 있는 건 지금의 나뿐. 스테이지마다 고스트 상한(1~4명)이 있다.
- 별점: ★1 클리어 · ★2 상한보다 적은 고스트 · ★3 개발자 기록과 같거나 더 적게.

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
