extends "res://tests/test_base.gd"
## 레버로 패러독스가 실제로 일어나는 방(A3)

func test_level() -> String:
	return "res://levels/level_test_paradox.tscn"

func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	var d1: Door = level.get_node("InvertedDoor")
	var d2: Door = level.get_node("PlateDoor")
	var lever: Lever = level.get_node("Lever")
	check("paradox room loaded: D1 open (inverted), D2 closed", level.name == "LevelTestParadox" and d1.is_open and not d2.is_open)

	# 정답: 1루프 문지기, 2루프 출구
	await restart()
	driver.probe = func() -> Array: return [player.global_position, d1.is_open, d2.is_open, lm.ghost_count()]
	var l1: Array = await run_loop(func(t: int) -> void: steer_to(270.0), 120)
	var g1: Ghost = lm.ghosts()[0]
	var l2: Array = await run_loop(func(t: int) -> void:
		if t > 30: steer_to(430.0)
		if player.global_position.x >= 220.0 and player.global_position.x < 235.0: Input.action_press("jump")
		else: Input.action_release("jump"), -1, 600)
	check("solution: keeper on plate, then pass D1, jump the keeper, pass D2 -> CLEAR", lm.cleared, "player=%s" % player.global_position)

	# 패러독스: 2루프에 레버부터 당기면 D1이 닫혀 문지기가 붕괴 → D2 안 열림 → 클리어 불가
	await restart()
	await run_loop(func(t: int) -> void: steer_to(270.0), 120)
	g1 = lm.ghosts()[0]
	var hit: int = -1
	for i in g1.frames().size():
		if (g1.frames()[i]["pos"] as Vector2).x + 20.0 > 160.0 - 0.08 + 0.5:
			hit = i
			break
	collapses.clear()
	var heard: Array = []
	Sfx.played.connect(func(n: String) -> void: heard.append(n))
	var marks: Array = []
	var lp: Array = await run_loop(func(t: int) -> void:
		if t < 40: steer_to(80.0)
		if t == 10: Input.action_press("interact")
		if t == 12: Input.action_release("interact")
		if t >= 40: steer_to(430.0)
		if t == 300: marks.append(hud.get_node("Timeline").rows()[0]["collapsed_at"]), 400)
	check("paradox: pulling the lever closes D1 and the keeper collapses on touching it", collapses.size() == 1 and collapses[0][1] == hit, "collapses=%s expected %d" % [collapses, hit])
	check("paradox: D2 stays closed, no CLEAR", not lm.cleared)
	check("timeline marks the collapse tick on ghost 1's row", marks.size() == 1 and marks[0] == hit + 1, str(marks))
	await frame()
	await frame()
	check("sounds: lever pull and paradox collapse are heard", heard.has("lever") and heard.has("collapse"), str(heard))
