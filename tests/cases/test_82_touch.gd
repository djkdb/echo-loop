extends "res://tests/test_base.gd"
## 모바일 터치(C4): 데스크톱에선 숨김, ← → 점프 E가 입력 액션을 누름, 고스트 아이콘 탭 = 다시 찍기 선택,
## 시간 바 길게 누르기(0.5초) = 루프 종료, ≡ = Esc, ↶ 되돌리기, ⟲ 처음부터(D2). 버튼은 44px 이상이고 방을 가리지 않는다.
## 웹: 첫 터치 뒤 전체 화면 제안, 첫 입력 전에는 소리를 내지 않는다.


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
	# ↶ 되돌리기: 고스트 1명 → 0명
	_touch((touch.buttons["undo"] as TouchScreenButton).position, true, 5)
	await tick(3)
	_touch((touch.buttons["undo"] as TouchScreenButton).position, false, 5)
	await tick(2)
	check("undo button removes the last ghost", lm.ghost_count() == 0)
	await run_loop(Callable(), 30)
	var before: int = lm.loop_index
	_touch((touch.buttons["restart"] as TouchScreenButton).position, true, 6)
	await tick(3)
	_touch((touch.buttons["restart"] as TouchScreenButton).position, false, 6)
	await tick(2)
	check("restart button restarts the stage from loop 1", before == 2 and lm.loop_index == 1 and lm.ghost_count() == 0, "before=%d now=%d" % [before, lm.loop_index])
	# 모든 터치 영역: 지름 44px 이상, 방(y 300~1030)과 겹치지 않음
	var room := Rect2(0, 300, 720, 730)
	var bad: Array = []
	for key: String in touch.buttons:
		var b: TouchScreenButton = touch.buttons[key]
		var r: Rect2 = b.shape.get_rect()
		r.position += b.position
		if r.intersects(room) or minf(r.size.x, r.size.y) < 44.0:
			bad.append("%s %s" % [key, r])
	check("every touch area is at least 44px and stays off the room (y 300~1030)", bad.is_empty() and touch.buttons.size() >= 12, str(bad))
	# 웹: 첫 터치 뒤 전체 화면 버튼(6초), 데스크톱에선 안 보임
	var fs: FullscreenButton = touch.get_node("Fullscreen")
	await frame()
	var hidden_desktop: bool = not fs.visible
	FullscreenButton.force_web = true
	fs._touched = false
	_touch(Vector2(360, 700), true, 7)
	_touch(Vector2(360, 700), false, 7)
	await frame()
	await frame()
	var shown: bool = fs.visible
	fs._left = 0.0
	await frame()
	await frame()
	check("web: fullscreen offer appears after the first touch and goes away", hidden_desktop and shown and not fs.visible and not Rect2(fs.position, fs.size).intersects(room))
	FullscreenButton.force_web = false
	# 웹: 첫 입력 전 소리 안 냄
	var heard: Array = []
	var cb: Callable = func(n: String) -> void: heard.append(n)
	Sfx.played.connect(cb)
	Sfx.unlocked = false
	Sfx.play("jump")
	_touch(Vector2(360, 700), true, 8)
	_touch(Vector2(360, 700), false, 8)
	await frame()
	Sfx.play("land")
	Sfx.played.disconnect(cb)
	check("web audio waits for the first touch", heard == ["land"] and Sfx.unlocked, str(heard))
	TouchControls.force_enabled = false
