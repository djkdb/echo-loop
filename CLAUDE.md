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
├─ game/        main.tscn, loop_manager.gd
├─ actors/      player.tscn/.gd, ghost.tscn/.gd
├─ objects/     pressure_plate, door, color_door, lever, timed_button, moving_platform, laser, box, exit
│               (씬+스크립트 같은 폴더) + signal_sources.gd(공용)
├─ levels/      level.gd, level_1_2.tscn, level_test*.tscn …
├─ ui/          hud.tscn/.gd, ghost_slots.gd, timeline.gd(hud.tscn 안 노드 스크립트)
├─ autoload/    replay_io.gd
├─ assets/      fonts/ (Noto Sans KR, OFL — 프로젝트 기본 폰트)
└─ tests/       run_all.gd, test_base.gd, cases/test_*.gd (자동 테스트, 내보내기에서 제외)
```

씬과 그 스크립트는 같은 폴더에 같은 이름으로 둔다.
단, `levels/level.gd`는 모든 레벨 공용 스크립트(같은 이름 규칙의 예외)다. 루프 길이·고스트 상한도 여기 export로 레벨마다 정한다.
스크립트 옆에 생기는 `.uid` 파일은 지우지 말고 같이 커밋한다.

## 레벨 배치

- 각 레벨 위쪽 **y 240~440은 릴스 텍스트 자리**로 비워 둔다(지형·오브젝트를 두지 않는다). 그 위 y 0~240은 HUD 자리.
- 화면 아래 y 1192~1272에는 루프 타임라인이 겹쳐 그려진다(바닥 위에).
- 테스트 방: `level_test`(계단 방), `level_test_paradox`(레버로 패러독스), `level_test_objects`(오브젝트 6종 시연).
  Main 노드의 `level_scene`을 바꿔서 연다.

## 입력 액션 (project.godot에 등록된 이름 그대로 사용)

`move_left` `move_right` `jump` `interact` `end_loop` `undo_ghost` `restart_stage`
`select_ghost_1` ~ `select_ghost_4` `reels_mode`

입력 맵에 없는 액션이 필요하면 직접 추가하지 말고 나에게 이름과 키를 알려줄 것.

- `undo_ghost`(Backspace): 마지막 고스트 삭제, 루프 번호 -1, 지금 루프를 처음부터.
- `select_ghost_n`(1~4): 그 번호 고스트를 빼고(benched) 루프를 처음부터. 이번 녹화로 덮어쓴다. 같은 번호를 다시 누르면 취소.

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

## 현재 마일스톤: 전체 MVP (기획서 docs/design.pdf)

완료
- [x] 1주차 프로토타입: Player·LoopManager·Ghost·압력판+문·1-2 "문지기"·HUD
- [x] 오브젝트: 레버, 시한 버튼, 이동 발판, 레이저, 색 문, 상자, 반전 문(inverted)
- [x] 고스트 편의: 되돌리기(Backspace), 개별 재녹화(1~4), 고스트 슬롯, 루프 타임라인
- [x] 테스트 방: 패러독스(레버), 오브젝트 시연

남은 MVP (기획서 기준, 한 번에 한 단계씩)
- [ ] 스테이지 12~15개(3챕터, 세로 9:16), 스테이지 선택 화면
- [ ] 별점(★1 클리어, ★2 상한보다 적은 고스트, ★3 개발자 기록) + 브라우저 저장
- [ ] 연출: 루프 리셋 되감기, 패러독스 글리치, 마지막 3초 똑딱 소리, 클리어 리플레이(2배속 겹치기)
- [ ] 리플레이 저장(autoload/replay_io.gd), 릴스 모드(F9)
- [ ] 모바일 터치 조작, 웹 빌드(itch.io), 폰트 서브셋

미뤄 둔 결정·알려진 한계는 docs/BACKLOG.md.
