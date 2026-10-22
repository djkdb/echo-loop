외부 스킬과 규칙이 다르면 이 파일이 우선한다.

# Echo Loop — CLAUDE.md

10초 동안의 내 행동이 녹화되고, 다음 루프마다 "과거의 나(고스트)"가 그대로 반복한다.
과거의 나들과 협력해 한 화면짜리 방을 탈출하는 2D 퍼즐 플랫포머.
플레이 영상을 인스타 릴스로 올리는 게 목표라서 **세로 9:16 화면**이 기본이다.

기획서(규칙·레벨·로드맵 전체): https://claude.ai/artifact/MTVZWmoUHeMvm1mCaLtFMB

---

## 기술 스택 (바꾸지 말 것)

- Godot 4.7 안정판, **GDScript만** 사용 (C# 금지: 웹 빌드 제약)
- 렌더러: **Compatibility** (웹·모바일 브라우저 대응)
- 뷰포트 720×1280, Stretch Mode `canvas_items`, Aspect `keep`
- Physics Ticks Per Second: 60

## 아키텍처 규칙 (가장 중요)

1. **게임 로직은 전부 `_physics_process`에서.** `_process`는 연출(파티클, UI 애니메이션)에만 쓴다.
2. **시간은 초가 아니라 물리 틱으로 센다.** 루프 길이 = `int(loop_seconds * Engine.physics_ticks_per_second)`.
3. **게임플레이에 랜덤 금지.** 같은 녹화는 항상 같은 결과를 내야 한다(결정론).
4. **녹화는 입력이 아니라 위치.** Player가 물리 프레임마다 `{pos, flip, interact, jump}`를 `recording`에 append.
   (`jump`는 루프 타임라인 표시용이고 재생에는 쓰지 않는다.) 고스트는 T번째 틱에 `recording[T-1]`로 간다.
5. **고스트 = `AnimatableBody2D` (sync_to_physics = true).** 녹화된 위치를 그대로 따라가고, 이동 전에 `test_move`로 막혔는지 검사한다. 막히면 패러독스 → 고스트 붕괴(`collapsed` 시그널).
   녹화 위치까지 **0.5px 넘게** 못 갈 때만 막힘으로 본다(`Ghost.BLOCK_TOLERANCE`, 표면 margin 안쪽 녹화 위치로 인한 가짜 붕괴 방지).
6. **리셋 규약:** 루프가 끝나면 초기 상태로 돌아가야 하는 모든 노드(Player, Ghost, 문, 레버, 발판, 상자)는
   - `resettable` 그룹에 들어가고
   - `reset()` 메서드를 구현한다.
   - LoopManager는 `get_tree().call_group("resettable", "reset")` 하나로 전부 리셋한다.
7. **신호(스위치) 연결 규약:**
   - 보내는 쪽(압력판, 레버, 시한 버튼): `signal toggled(on: bool)`, 프로퍼티 `is_on: bool`
   - 받는 쪽(문, 색 문, 이동 발판, 레이저): `@export var sources: Array[NodePath]`, 연결된 소스 중 **하나라도** on이면 활성
   - 받는 쪽은 `inverted`(신호가 오면 반대로)를 갖는다. sources가 비면 이동 발판·레이저는 항상 활성.
   - 공용 처리는 `objects/signal_sources.gd`(`SignalSources.resolve/any_on`).
8. **압력판은 `Area2D`의 겹친 바디 수로 판정**해서 플레이어와 고스트를 똑같이 처리한다.
   누르는 몸은 Player·살아 있는 고스트·상자(`PressurePlate.is_weight`).
9. **Player와 고스트는 같은 경로면 같은 결과를 내야 한다.** 그래서
   - 닿음 판정(판·레버·출구·레이저)은 Area2D 겹침 목록으로 한다(Player·고스트의 감지 지연이 같음).
   - 몸 위치로 직접 계산하는 규칙(상자 밀기, 이동 발판 끼임)은 Player는 `global_position`, 고스트는 `replay_position`을 쓴다.
   - Area2D 겹침 목록은 리셋 직후 낡아 있으므로 리셋된 물리 프레임 + 2까지 판정에 쓰지 않는다.
10. **상호작용(E):** Player와 고스트(녹화된 interact 틱에)가 `interactables` 그룹 중 자기와 겹친 Area2D의 `interact()`를 부른다.
11. **레이저:** Player가 닿으면 루프 실패. 고스트는 빔을 몸으로 막는 방패라 붕괴하지 않고 빔이 고스트에서 끝난다.
12. **루프 리셋은 틱 끝(LoopManager 차례)에만.** 중간에 실패·클리어를 알리는 쪽은 `fail_loop()`/`clear_stage()`로 표시만 한다.
13. **움직이는 고스트 위에서는 점프할 수 없다.** 고스트 녹화에서 이번 틱 위치가 앞뒤 틱보다 높으면(점프·낙하·발판에 실림)
    그 고스트는 점프 발판이 아니다(`Ghost.supports_jump`, 코요테도 채우지 않음). Player는 플랫폼 속도를 물려받지 않는다
    (`platform_on_leave = DO_NOTHING`). 둘 다 없으면 고스트 점프에 올라타 뛰는 부스트(실측 352~693px)로
    고스트 1명이 탑 2단보다 높이 닿아 높이 퍼즐이 성립하지 않는다.
14. **짓눌린 Player = 루프 실패.** 이동 뒤 몸을 가로 8·세로 17px 줄인 사각형이 지형·고스트와 겹치면(내려앉는 고스트에 깔림,
    고스트가 벽 쪽으로 밀어붙임) `fail_loop()`. 올라탄 고스트의 1틱 파고듦(최대 15px)·상자·스폰 통과 중인 고스트는 제외.

## 처리 순서 (process_physics_priority, 작을수록 먼저)

| 순서 | 노드 | 이유 |
| --- | --- | --- |
| -20 | Ghost | 이번 틱 위치(`replay_position`)를 먼저 정한다. 붕괴(충돌 끄기)가 즉시 적용돼 같은 틱에 Player가 못 밟는다 |
| -10 | Player | 이동·녹화. LoopManager보다 먼저라 루프 끝 녹화 길이 = loop_ticks |
| 0 | Box | 몸들이 이번 틱 위치를 정한 뒤 밀리고, 판보다 먼저 움직인다 |
| 10 | PressurePlate, Lever, TimedButton | 보내는 쪽. 받는 쪽보다 먼저 이번 틱 신호를 정한다 |
| 20 | Door, ColorDoor, MovingPlatform | 받는 쪽 |
| 25 | Laser | 문·발판이 움직인 뒤 빔 길이·닿음 판정 |
| 30 | Exit | LoopManager보다 먼저라 시간 초과와 겹쳐도 클리어가 우선 |
| 100 | LoopManager | 틱 카운트·종료·실패·되돌리기·덮어쓰기·리셋 |

sync_to_physics 바디(고스트·발판·상자)의 이동은 모든 `_physics_process`가 끝난 뒤 물리 스텝에서 반영된다.
위에 선 Player는 그 플랫폼 속도를 다음 틱에 받는다(엔진 구조상 1틱 지연, 결정론에는 영향 없음).

## 충돌 레이어

| 레이어 | 이름 | 설명 |
| --- | --- | --- |
| 1 | world | 벽, 바닥, 문, 발판, 상자(윗면 one-way) |
| 2 | player | 지금의 나 |
| 3 | ghost | 과거의 나 |
| 4 | sensor | 압력판, 레버, 시한 버튼, 레이저, 출구, 문 센서 (Area2D) |
| 5 | player_barrier | 파랑 색 문(지금의 나만 막음) |
| 6 | ghost_barrier | 주황 색 문(고스트만 막음) |

- Player mask: world + ghost + player_barrier = 21 (고스트를 밟을 수 있음)
- Ghost mask: **world + ghost_barrier** = 33 (패러독스 검사가 지형 변화에만 반응하도록. 주황 문은 고스트에게 지형)
- 압력판·문 센서 mask: world + player + ghost = 7 (상자 감지. 종류로 걸러 바닥·벽은 세지 않는다)
- 나머지 센서 mask: player + ghost = 6, 출구는 player = 2

## 폴더 구조

```
res://
├─ game/        main.tscn/.gd, loop_manager.gd, replay.tscn/.gd(리플레이 씬), room_camera.gd(방을 화면 영역에 맞추는 카메라)
│               palette.gd(색), fx.gd·reels_mode.gd(Main 안 연출 노드), puff·glitch_sprite·flash_ring·clear_paths(연출 조각)
├─ actors/      player.tscn/.gd, ghost.tscn/.gd, character_visual.gd(몸 그림), ghost_trail.gd(잔상), body_shape.tres
├─ objects/     pressure_plate, door, color_door, lever, timed_button, moving_platform, laser, box, exit
│               (씬+스크립트 같은 폴더) + signal_sources.gd(공용)
├─ levels/      level.gd, level_<챕터>_<번호>.tscn(15개), level_test*.tscn, stages.gd(스테이지 목록·별점 규칙),
│               room_style.gd·signal_wires.gd(레벨이 런타임에 붙이는 그림)
├─ ui/          title.tscn/.gd(타이틀), stage_select.tscn/.gd(+ stage_card.gd), hud.tscn/.gd,
│               ghost_slots.gd·timeline.gd·star_icons.gd·touch_controls.gd·hints.gd·fullscreen_button.gd(HUD·화면 안 조각)
├─ autoload/    replay_io.gd(ReplayIO), sfx.gd(Sfx), progress.gd(Progress: 클리어 기록·플래그 user://progress.json),
│               playtest.gd(Playtest: 플레이 테스트 기록 user://playtest.json)
├─ assets/      fonts/ (Noto Sans KR 서브셋 = 기본, Space Grotesk 700 + 한글 폴백 = hud_font.tres, 모두 OFL)
│               fx/ (glow_texture·additive = 가산 글로우, rewind·glitch 셰이더)
├─ solutions/   <stage>.json (개발자 정답 리플레이 = 별 3개 기준, 내보내기에서 제외)
├─ tools/       subset_font.py(한글 폰트 서브셋), playtest_report.py(플레이 테스트 모아 보기),
│               render_reels.sh + reels_problem.tscn/.gd + reels_copy.json(릴스 렌더) — 내보내기에서 제외
├─ docs/        design.pdf(기획서), levels.md(레벨 설계 근거), BACKLOG.md
└─ tests/       run_all.gd, test_base.gd, cases/test_*.gd (자동 테스트), solution_case.gd(정답 검증 공용),
                bots/<stage>.gd (정답을 실제로 풀어 solutions/를 만드는 봇) — 모두 내보내기에서 제외
```

씬과 그 스크립트는 같은 폴더에 같은 이름으로 둔다.
단, `levels/level.gd`는 모든 레벨 공용 스크립트(같은 이름 규칙의 예외)다. 루프 길이·고스트 상한도 여기 export로 레벨마다 정한다.
스크립트 옆에 생기는 `.uid` 파일은 지우지 말고 같이 커밋한다.

## 비주얼 "NEON LOOP" (연출 규칙)

- 색은 `game/palette.gd`(`Palette`)에서만 정한다. 바탕 #0A0C14, 방 #10131F(24px 격자 흰색 3%), 벽 선 #3B4773,
  나 #F4F5FA, 고스트 #4FA3FF/#FF9A3D/#4ADE80/#B47CFF(채움 28% + 2px 외곽선 + 번호 배지), 신호 #FFD23F,
  문 #FF4D6D, 출구 #5EF2C2, 보조 글자 #8B93AD.
- **연출은 `_process`에서만.** 로직은 시그널(`jumped`, `landed`, `toggled`, `collapsed`, `loop_ended`…)이나 상태만 남기고,
  그림·애니메이션·소리는 `_process`(또는 연출 노드)가 그 상태를 읽어 만든다. 연출의 난수는 게임플레이에 영향이 없어야 한다.
- 글로우·셰이더는 Compatibility 렌더러용: 방사형 그라데이션 + ADD 블렌드 스프라이트, `canvas_item` 셰이더.
- 씬의 Polygon2D 그림은 에디터 미리보기용으로 남기고, 실행 중엔 스크립트 `_draw`가 그린다(문·발판·상자·방).
- 릴스 모드(F9, `ReelsMode`): HUD 숨김, 방 내부를 화면 x 24~612·y 300~1030에 꽉 차게(줌 상한 없음), 릴스 텍스트 자리 y 240~300에 한 줄.
- 리플레이: CLEAR 때 `user://replays/<stage>.json` 저장, `game/replay.tscn`으로 재생. Movie Maker 렌더:
  `godot --path . --write-movie out.avi --fixed-fps 60 res://game/replay.tscn -- --stage=level_1_2 --loops=1 --reels`
  (`--solution`을 붙이면 user:// 대신 개발자 정답 `solutions/<stage>.json`을 재생 = 릴스 "정답편")
- 효과음: `Sfx.play(name)`(SFX 버스, 코드 합성). 새 소리는 `autoload/sfx.gd`의 streams에 추가.

## 화면 흐름·저장·모바일·웹 빌드

- 흐름: `ui/title.tscn`(시작 씬, Enter·Space·E·탭) → `ui/stage_select.tscn`(방향키 + Enter/E, 클릭·탭, Esc 타이틀)
  → `game/main.tscn`(`Progress.pending_stage`로 스테이지를 연다. Esc 선택 화면, CLEAR 뒤 E 다음 스테이지).
  main.tscn을 직접 열면(테스트·에디터) 자기 `level_scene`을 쓰고 메뉴 이동은 하지 않는다.
- 기록: `Progress`가 스테이지마다 CLEAR한 최소 고스트 수만 `user://progress.json`에 저장한다(웹에서는 브라우저 저장소).
  별점 = ★1 클리어 / ★2 상한보다 적은 고스트 / ★3 개발자 기록 이하(`Stages.stars_for`). 앞 스테이지를 깨면 다음이 열린다.
  자동 테스트는 `user://test_progress.json`을 쓴다(실제 기록을 건드리지 않음).
- 모바일 터치: `TouchControls`(HUD 안)가 터치 화면에서만 보인다. 데스크톱 확인은 실행 인자 `--touch`.
  버튼은 입력 액션을 그대로 누르므로 게임 로직은 키보드와 같은 길이다. 시간 바 0.5초 길게 = `end_loop`,
  오른쪽 위 ⟲ `restart_stage`·↶ `undo_ghost`·≡ `ui_cancel`. 터치 영역은 지름 44px 이상, 방(y 300~1030)을 가리지 않는다(test_82).
  웹에서는 첫 터치 뒤 전체 화면 제안, 브라우저 스크롤·핀치·더블탭 줌 막기(export 프리셋 head_include), 첫 입력 뒤에 소리 시작.
- 첫 플레이 안내(`Hints`, HUD 안 y 240~300): 1-1~1-3만, 그 스테이지를 깨면 다시 안 띄움. 입력 없는 시간 초과 2번 연속이면
  "언제든 루프를 끝낼 수 있다"를 한 번(Progress 플래그). 릴스 모드·리플레이 렌더에는 나오지 않는다.
- 플레이 테스트 기록(`Playtest`): 스테이지별 시도 루프 수·되돌리기·처음부터·처음 클리어까지 실제 시간·고스트·별을
  `user://playtest.json`에 저장(전송 없음). 타이틀 "테스트 결과 복사" = 요약 + JSON을 클립보드로. `tools/playtest_report.py`로 모아 본다.
- 릴스 렌더: `tools/render_reels.sh <stage|all>` → `build/reels/<stage>_{answer,answer_2x,problem}.mp4`(1080x1920).
  정답편 = 리플레이 `--solution --reels --trim --seamless --text=…`, 문제편 = `tools/reels_problem.tscn`. 문구는 `tools/reels_copy.json`.
- 웹 빌드: `godot --headless --path . --export-release "Web" build/web/index.html`
  (export_presets.cfg "Web": 스레드 끔, 제외 `tests/* solutions/* tools/* docs/* build/*`. 4.7.2 web_nothreads 템플릿 필요.
  `build/`는 git에 넣지 않는다. itch.io에는 build/web 폴더를 zip으로 올리고 "This file will be played in the browser").

## 레벨 배치 (화면 좌표 기준, 뷰포트 720×1280)

| 화면 y | 영역 |
| --- | --- |
| 0~240 | HUD (시간 바, LOOP n, 나 ×n, 고스트 슬롯) |
| 240~300 | 릴스 텍스트 자리 (릴스 모드 문구, 보통 화면에선 비움) |
| 300~1030 | 방 (`RoomCamera`가 방 내부를 여기 가운데에 맞춘다) |
| 1030~1280 | 인스타 캡션·루프 타임라인·모바일 터치 버튼 |

- 방은 월드 좌표 (0,0)~(W,H)를 내부로, 바깥에 두께 40 벽 `Floor`·`Ceiling`·`LeftWall`·`RightWall`(Room 아래 StaticBody2D)을 둔다.
  `Level.room_rect()`가 이 이름으로 내부를 찾고, 카메라가 `camera_zoom`(1.5~2.0)으로 키운다. 넘치면 들어갈 만큼 줄인다.
- **스케일:** 몸·이동·점프·중력 수치는 그대로(몸 40×64, 6px/틱, 점프 176px)이고 방을 작게 짜서 줌으로 키운다.
  챕터 1 = 줌 2.0, 내부 320×360(폭 8명). 챕터 2·3 = 줌 1.5, 내부 최대 480×486(보통 440×480). 바닥 = y H.
- **닿는 높이(바닥 기준 발 높이):** 혼자 176, 서 있는 고스트 1명 밟고 240(고스트 착지 틱에 뛰면 최대 255), 2단 304, 3단 368.
  높이로 고스트 수를 강제할 때는 이 값에서 15px 이상 여유를 둔다.
- **판과 그 판이 여는 문 사이는 70px 이상** 띄운다. 판에서 내려선 몸이 바로 문간에 들어서면 끼임 방지로 문이 안 닫혀
  혼자서도 지나간다(1-5 초안에서 실제로 났던 구멍).
- 높이 퍼즐이 아닌 방은 칸막이를 천장까지 올려 점프로 넘는 길을 막는다.
- 스테이지를 추가·수정하면 `levels/stages.gd` 목록(코드·제목·새 요소·상한·개발자 기록)을 같이 맞춘다(test_80이 어긋남을 잡는다).
- 레벨마다 `solutions/<stage>.json`(정답 리플레이)과 `tests/bots/<stage>.gd`(그 정답을 실제로 푸는 봇)가 있다.
  레벨을 고치면 `godot --headless --fixed-fps 60 --path . -s tests/run_all.gd -- --dir=bots --only=<stage>`로 다시 만든다.
  `tests/cases/test_70_solutions_*.gd`가 정답 재현·CLEAR·고스트 하나라도 빼면 실패를 검증한다. 설계 근거는 `docs/levels.md`.
- 테스트 방: `level_test`(유닛 테스트용 큰 물리 샌드박스, 줌 축소로 표시), `level_test_paradox`(레버로 패러독스),
  `level_test_objects`(오브젝트 6종 시연). Main 노드의 `level_scene`을 바꿔서 연다.

## 입력 액션 (project.godot에 등록된 이름 그대로 사용)

`move_left` `move_right` `jump` `interact` `end_loop` `undo_ghost` `restart_stage`
`select_ghost_1` ~ `select_ghost_4` `reels_mode` `debug_collapse`

입력 맵에 없는 액션이 필요하면 직접 추가하지 말고 나에게 이름과 키를 알려줄 것.

- `undo_ghost`(Backspace): 마지막 고스트 삭제, 루프 번호 -1, 지금 루프를 처음부터.
- `select_ghost_n`(1~4): 그 번호 고스트를 빼고(benched) 루프를 처음부터. 이번 녹화로 덮어쓴다. 같은 번호를 다시 누르면 취소.
- `debug_collapse`(F10): 디버그 빌드에서만, 가장 최근 고스트를 강제 붕괴(릴스 촬영용).

R과 Shift+R이 겹치므로 `end_loop`는 반드시 exact match로 검사한다
(`Input.is_action_just_pressed("end_loop", true)`, 이벤트면 `event.is_action_pressed("end_loop", false, true)`).

## 코딩 컨벤션

- 모든 변수·함수에 정적 타입 (`var tick: int = 0`, `func reset() -> void:`)
- 파일·함수·변수 snake_case, `class_name`은 PascalCase
- 시그널 이름은 과거형 (`collapsed`, `toggled`, `loop_ended`)
- 긴 `get_node("../../..")` 경로 금지 → `@export var` 또는 `@onready var`
- 주석은 한국어 OK, "왜"를 쓴다

## 작업 방식 (Claude Code 규칙)

- **지금 마일스톤 범위 밖 기능은 만들지 않는다.** 필요해 보이면 제안만.
- 한 번에 한 단계씩. 단계가 끝나면 멈추고 **내가 에디터에서 테스트할 방법**을 알려준다:
  무엇을 실행하고, 어떤 동작이 보여야 정상인지, 어떤 증상이면 버그인지.
- `.tscn`은 텍스트로 만들어도 되지만, **충돌 모양 크기·타일맵 배치·노드 위치 미세조정은 내가 에디터에서 한다.**
  그런 부분은 `TODO(에디터):` 로 남기고 끝에 목록으로 알려줄 것.
- `project.godot` 설정을 바꿔야 하면 바꾸기 전에 무엇을 왜 바꾸는지 먼저 말할 것.
- 커밋은 작게, 접두사 사용: `feat:` `fix:` `refactor:` `chore:`
- Godot 실행 파일이 PATH에 있으면 `godot --headless --path . --quit-after 120` 으로 스크립트 에러가 없는지 확인한다.
- **커밋 전 `tests/run_all.gd` 통과 필수.** `godot --headless --path . -s tests/run_all.gd`
  (`--fixed-fps 60`을 붙이면 실시간을 기다리지 않아 30초 안팎, 하나만: `-- --only=test_12`). 실패하면 종료 코드 1.
  새 기능·버그 수정에는 `tests/cases/`에 케이스를 추가한다(`tests/test_base.gd` 상속, `run_case()` 구현).

---

## 현재 마일스톤: 플레이 테스트(phase-d, v0.2.0)

완료
- [x] MVP(phase-c, v0.1.0): 오브젝트 8종, 스테이지 15개 + 정답 리플레이, 선택 화면·별점·저장, 타이틀, 터치, 웹 빌드
- [x] 첫 플레이 안내(1-1~1-3, 입력 없는 시간 초과), 모바일 마무리(되돌리기·처음부터, 웹 전체 화면·줌 막기·오디오)
- [x] 짓눌린 Player = 루프 실패
- [x] 플레이 테스트 기록·결과 복사·모아 보기(tools/playtest_report.py)
- [x] 릴스 도구: F10 강제 붕괴, tools/render_reels.sh(정답편·2배속·문제편)

다음(플레이 테스트 결과를 보고 결정, 레벨 배치·퍼즐 수치는 그때 바꾼다)
- [ ] 친구 플레이 테스트 → playtest_report 표 → 5분 넘는 스테이지 힌트·배치 수정, docs/levels.md 갱신
- [ ] itch.io 업로드(사람이 한다), 릴스 시리즈 업로드
- [ ] BACKLOG의 열린 항목(★2 구간, 2-1 발판 대기, 클리어 리플레이 게임 안 2배속 등)

미뤄 둔 결정·알려진 한계는 docs/BACKLOG.md.
