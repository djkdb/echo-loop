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
4. **녹화는 입력이 아니라 위치.** Player가 물리 프레임마다 `{pos, flip, interact}`를 `recording`에 append.
5. **고스트 = `AnimatableBody2D` (sync_to_physics = true).** 녹화된 위치를 그대로 따라가고, 이동 전에 `test_move`로 막혔는지 검사한다. 막히면 패러독스 → 고스트 붕괴(`collapsed` 시그널).
6. **리셋 규약:** 루프가 끝나면 초기 상태로 돌아가야 하는 모든 노드(Player, Ghost, 문, 레버, 발판, 상자)는
   - `resettable` 그룹에 들어가고
   - `reset()` 메서드를 구현한다.
   - LoopManager는 `get_tree().call_group("resettable", "reset")` 하나로 전부 리셋한다.
7. **신호(스위치) 연결 규약:**
   - 보내는 쪽(압력판, 레버, 시한 버튼): `signal toggled(on: bool)`, 프로퍼티 `is_on: bool`
   - 받는 쪽(문, 이동 발판): `@export var sources: Array[NodePath]`, 연결된 소스 중 **하나라도** on이면 활성
8. **압력판은 `Area2D`의 겹친 바디 수로 판정**해서 플레이어와 고스트를 똑같이 처리한다.

## 충돌 레이어

| 레이어 | 이름 | 설명 |
| --- | --- | --- |
| 1 | world | 벽, 바닥, 문, 발판 |
| 2 | player | 지금의 나 |
| 3 | ghost | 과거의 나 |
| 4 | sensor | 압력판, 레이저, 출구 (Area2D) |

- Player mask: world + ghost (고스트를 밟을 수 있음)
- Ghost mask: **world만** (패러독스 검사가 지형 변화에만 반응하도록)

## 폴더 구조

```
res://
├─ game/        main.tscn, loop_manager.gd
├─ actors/      player.tscn/.gd, ghost.tscn/.gd
├─ objects/     pressure_plate, door, lever, moving_platform … (씬+스크립트 같은 폴더)
├─ levels/      level_1_1.tscn, level_1_2.tscn …
├─ ui/          hud.tscn/.gd
└─ autoload/    replay_io.gd
```

씬과 그 스크립트는 같은 폴더에 같은 이름으로 둔다.
스크립트 옆에 생기는 `.uid` 파일은 지우지 말고 같이 커밋한다.

## 입력 액션 (project.godot에 등록된 이름 그대로 사용)

`move_left` `move_right` `jump` `interact` `end_loop` `undo_ghost` `restart_stage`
`select_ghost_1` ~ `select_ghost_4` `reels_mode`

입력 맵에 없는 액션이 필요하면 직접 추가하지 말고 나에게 이름과 키를 알려줄 것.

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

---

## 현재 마일스톤: 1주차 프로토타입

목표: 회색 박스 방 하나에서 "과거의 나와 협력"이 재밌는지 검증.

- [ ] Player 이동·점프 (코요테 타임 0.1초, 점프 버퍼 0.1초)
- [ ] LoopManager: 틱 카운트, 루프 종료(시간 초과 / `end_loop`), 전체 리셋
- [ ] 녹화 → Ghost 재생, 고스트 상한(`max_ghosts`)
- [ ] 압력판 + 문
- [ ] 회색 박스 테스트 방 1개 (1-2 "문지기": 고스트가 압력판을 밟는 동안 지나가기)
- [ ] HUD 최소: 남은 시간 바, "LOOP n · 나 ×n" 표시

1주차에 하지 않는 것: 레버, 발판, 레이저, 재녹화, 타임라인, 연출, 모바일 터치, 리플레이 저장.
