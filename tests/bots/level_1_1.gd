extends "res://tests/test_base.gd"
## 1-1 첫 걸음: 1루프 턱 밑에서 실패 → 2루프 과거의 나를 밟고 턱 위 출구로.


func test_level() -> String:
	return "res://levels/level_1_1.tscn"


func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	await restart()
	await record_loop(func(t: int) -> void: steer_to(176.0), 60)
	var st: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		go(1)
		tap_step(st, 0, player.global_position.x >= 100.0)
		tap_step(st, 1, player.is_on_floor() and player.global_position.y < 300.0), -1, 400)
	check("1-1 solved with 1 ghost", lm.cleared, str(player.global_position))
	save_solution()
