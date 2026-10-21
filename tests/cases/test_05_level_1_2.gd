extends "res://tests/test_base.gd"
## 압력판·문·출구, 레벨 1-2 "문지기"(4단계).


func test_level() -> String:
	return "res://levels/level_1_2.tscn"


func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	var door: Door = level.get_node("Door")
	var plate: PressurePlate = level.get_node("PressurePlate")
	driver.probe = func() -> Array: return [player.global_position, door.is_open, plate.is_on, lm.cleared]
	check("level settings: 600 ticks, max 1 ghost", lm.loop_ticks == 600 and lm.max_ghosts == 1)
	check("initial: door closed, plate off", not door.is_open and not plate.is_on)
	var keeper: Callable = func(t: int) -> void: steer_to(280.0)

	# 혼자서는 판에서 문까지 가기 전에 문이 닫힌다
	await restart()
	var solo: Array = await run_loop(func(t: int) -> void:
		if t < 60: steer_to(280.0)
		else: Input.action_press("move_right"), 300)
	check("alone: standing on plate opens door", solo.any(func(e: Array) -> bool: return e[2][1] and e[2][2]))
	check("alone: cannot reach the exit", not lm.cleared and (solo[-1][2][0] as Vector2).x < 460.0)

	# 1) 고스트가 판 위 → 문 열림 → 점프로 문지기를 넘어 출구 → CLEAR, 타이머 정지
	await restart()
	await run_loop(keeper, 120)
	await run_loop(func(t: int) -> void:
		if t > 40: Input.action_press("move_right")
		if t == 55: Input.action_press("jump")
		if t == 57: Input.action_release("jump"), -1, 600)
	check("ghost on plate -> door open -> player reaches exit -> CLEAR", lm.cleared)
	var t0: int = lm.tick
	await tick(30)
	check("CLEAR stops the loop timer", lm.tick == t0)
	await tap_key(KEY_R)
	await tick(3)
	check("R in CLEAR restarts the stage (and does not re-CLEAR)", not lm.cleared and lm.loop_index == 1 and lm.ghost_count() == 0)

	# 2) 고스트가 판에서 내려가면 문이 닫힘 / 3) 문 안에 몸이 있으면 안 닫힘
	await restart()
	await run_loop(func(t: int) -> void:
		if t < 120: steer_to(280.0)
		else: steer_to(100.0), 200)
	var g: Ghost = lm.ghosts()[0]
	var leave: int = first_frame(g.frames().slice(60), func(p: Vector2) -> bool: return p.x + 20.0 <= 240.0) + 60
	var l2: Array = await run_loop(Callable(), 220)
	var close_t: int = -1
	for e: Array in l2:
		if e[1] > leave and not e[2][1]:
			close_t = e[1]
			break
	check("ghost leaves plate -> door closes a few ticks later", close_t > 0 and close_t - leave <= 4, "left %d closed %d" % [leave, close_t])
	await restart()
	await run_loop(func(t: int) -> void:
		if t < 120: steer_to(280.0)
		else: steer_to(100.0), 200)
	var st: Array = [0]
	var l3: Array = await run_loop(func(t: int) -> void:
		if st[0] == 0:
			Input.action_press("move_right")
			if t == 55: Input.action_press("jump")
			if t == 57: Input.action_release("jump")
			if player.global_position.x >= 475.0: release_all(); st[0] = 1
		elif st[0] == 1 and t == 220: st[0] = 2
		elif st[0] == 2:
			steer_to(380.0), 300)
	var in_door: Array = l3.filter(func(e: Array) -> bool: return e[1] > 140 and e[1] <= 220 and (e[2][0] as Vector2).x > 440.0)
	check("body inside the door keeps it open after the plate is released", in_door.size() > 40 and in_door.all(func(e: Array) -> bool: return e[2][1]))
	var out: Array = l3.filter(func(e: Array) -> bool: return e[1] > 230 and (e[2][0] as Vector2).x + 20.0 < 448.0)
	check("door closes once its area is empty", out.size() > 0 and out.all(func(e: Array) -> bool: return not e[2][1]))

	# 7) 리셋 직후 문 닫힘·판 off, 새 루프 첫 틱에 낡은 겹침으로 판이 눌리지 않음
	await restart()
	await run_loop(keeper, 120)
	await run_loop(Callable(), 200)
	await tick(4)
	var first: Array = driver.log.slice(driver.log.size() - 4)
	check("after reset: door closed, plate off on the first ticks of the new loop", first.all(func(e: Array) -> bool: return not e[2][1] and not e[2][2]))
