extends "res://tests/test_base.gd"
## 모바일 터치(C4): 데스크톱에선 숨김, ← → 점프 E가 입력 액션을 누름, 고스트 아이콘 탭 = 다시 찍기 선택,
## 시간 바 길게 누르기(0.5초) = 루프 종료, ≡ = Esc.


## pos는 화면(뷰포트 720x1280) 좌표. 이벤트는 창 좌표로 넣어야 하므로 스트레치 변환을 거친다(헤드리스 창은 64x64).
func _touch(pos: Vector2, pressed: bool, index: int = 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.position = get_tree().root.get_final_transform() * pos
	ev.pressed = pressed
	ev.index = index
	Input.parse_input_event(ev)


func run_case() -> void:
	var touch: TouchControls = hud.get_node("TouchControls")
	check("touch controls hidden without a touchscreen (desktop/headless)", not touch.visible)
	TouchControls.force_enabled = true
	await frame()
	await frame()
	check("touch controls shown on a touchscreen", touch.visible)
	await restart()
	var pos0: float = player.global_position.x
	var pressed: Array = []
	_touch((touch.buttons["right"] as TouchScreenButton).position, true)
	await tick(20)
	pressed.append(Input.is_action_pressed("move_right"))
	_touch((touch.buttons["right"] as TouchScreenButton).position, false)
	await tick(2)
	pressed.append(Input.is_action_pressed("move_right"))
	check("right button holds move_right while touched and moves the player", pressed == [true, false] and player.global_position.x > pos0 + 60.0, "%s dx=%.1f" % [pressed, player.global_position.x - pos0])
	_touch((touch.buttons["jump"] as TouchScreenButton).position, true, 1)
	await tick(2)
	var jumped: bool = Input.is_action_pressed("jump")
	_touch((touch.buttons["jump"] as TouchScreenButton).position, false, 1)
	check("jump button presses jump", jumped)
	# 시간 바 길게 누르기 → 루프 종료(고스트 1명)
	var n_end: int = ended.size()
	_touch(TouchControls.TIMER_BAR.get_center(), true, 2)
	await tick(10)
	var early: bool = ended.size() > n_end
	for i in 40:
		await frame()
	_touch(TouchControls.TIMER_BAR.get_center(), false, 2)
	await tick(3)
	check("long press on the timer bar ends the loop (not a short tap)", not early and ended.size() == n_end + 1 and lm.ghost_count() == 1, "early=%s ended=%d" % [early, ended.size() - n_end])
	# 고스트 아이콘 탭 → 1번 다시 찍기
	_touch((touch.buttons["ghost_1"] as TouchScreenButton).position, true, 3)
	await tick(3)
	_touch((touch.buttons["ghost_1"] as TouchScreenButton).position, false, 3)
	await tick(2)
	check("tapping ghost icon 1 selects ghost 1 to re-record", lm.overwrite_target == 1)
	_touch((touch.buttons["menu"] as TouchScreenButton).position, true, 4)
	await tick(2)
	var menu_down: bool = Input.is_action_pressed("ui_cancel")
	_touch((touch.buttons["menu"] as TouchScreenButton).position, false, 4)
	check("menu button presses ui_cancel (back to stage select)", menu_down)
	TouchControls.force_enabled = false
