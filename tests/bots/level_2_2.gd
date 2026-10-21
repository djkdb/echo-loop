extends "res://tests/test_base.gd"
## 2-2 탑 쌓기: 1루프 턱 앞에 서기 → 2루프 그 머리 위에 서기 → 3루프 두 명을 밟고 턱 위 출구로.


func test_level() -> String:
	return "res://levels/level_2_2.tscn"


func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	await restart()
	await record_loop(func(t: int) -> void: steer_to(278.0), 60)
	var s2: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		if t < 20:
			return
		go(1 if player.global_position.x < 272.0 else 0)
		tap_step(s2, 0, player.global_position.x >= 200.0), 110)
	var st: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		if t < 100:   # 2번이 1번 머리 위에 내려앉을 때까지 기다린다
			return
		var p: Vector2 = player.global_position
		if st[0] <= 1:
			go(1 if p.x < 272.0 else 0)
			tap_step(st, 0, p.x >= 180.0)
			if st[0] == 1 and st[1] == 0 and player.is_on_floor() and p.y < 330.0:
				st[0] = 2
		else:
			go(1)
			tap_step(st, 2, true), -1, 480)
	check("2-2 solved with 2 ghosts", lm.cleared, "%s step=%d" % [player.global_position, st[0]])
	save_solution()
