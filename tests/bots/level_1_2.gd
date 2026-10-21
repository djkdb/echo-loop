extends "res://tests/test_base.gd"
## 1-2 문지기: 1루프 압력판 위에 서 있기 → 2루프 문지기를 넘어 열린 문으로.


func test_level() -> String:
	return "res://levels/level_1_2.tscn"


func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	await restart()
	await record_loop(func(t: int) -> void: steer_to(90.0), 120)
	var st: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		if t < 20:
			return
		go(1)
		tap_step(st, 0, player.global_position.x >= 34.0), -1, 600)
	check("1-2 solved with 1 ghost", lm.cleared, str(player.global_position))
	save_solution()
