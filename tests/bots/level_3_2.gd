extends "res://tests/test_base.gd"
## 3-2 6초: 1루프 판 → 2루프 판 문을 지나 턱 앞 → 3루프 그 머리 위 → 4루프 나는 문을 지나 2단 탑으로 턱 위 출구. 6초 안에.


func test_level() -> String:
	return "res://levels/level_3_2.tscn"


func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	await restart()
	await record_loop(func(t: int) -> void: steer_to(50.0), 40)
	await record_loop(func(t: int) -> void:
		if t >= 10: steer_to(278.0), 60)
	var s3: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		if t < 40:
			return
		steer_to(278.0)
		tap_step(s3, 0, player.global_position.x >= 215.0), 130)
	var st: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		if t < 120:   # 3번이 2번 머리 위에 내려앉을 때까지
			return
		var p: Vector2 = player.global_position
		if st[0] <= 1:
			steer_to(278.0)
			tap_step(st, 0, p.x >= 215.0)
			if st[0] == 1 and st[1] == 0 and player.is_on_floor() and p.y < 330.0:
				st[0] = 2
		else:
			go(1)
			tap_step(st, 2, true), -1, 400)
	check("3-2 solved with 3 ghosts in 6 s", lm.cleared, "%s step=%d" % [player.global_position, st[0]])
	save_solution()
