extends "res://tests/test_base.gd"
## 1-5 막지 마라: 1루프 판 지기(반전 문을 먼저 지나감) → 2루프 늦게 레버 → 3루프 나는 반전 문이 닫히기 전에 통과.


func test_level() -> String:
	return "res://levels/level_1_5.tscn"


func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	await restart()
	await record_loop(func(t: int) -> void: steer_to(280.0), 120)
	var st2: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		steer_to(70.0)
		tap_step(st2, 0, t >= 60, "interact"), 90)
	var st: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		if t < 12:
			return
		if st[0] <= 1:
			go(1)
			tap_step(st, 0, true)
			if st[0] == 1 and st[1] == 0 and player.global_position.y > 220.0:
				st[0] = 2
		else:
			steer_to(40.0), -1, 600)
	check("1-5 solved with 2 ghosts", lm.cleared, "%s step=%d" % [player.global_position, st[0]])
	save_solution()
