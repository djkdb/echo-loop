extends "res://tests/test_base.gd"
## 1-3 디딤돌: 1루프 낮은 단 끝에 서 있기 → 2루프 단 위의 과거의 나를 밟고 왼쪽 높은 턱으로.


func test_level() -> String:
	return "res://levels/level_1_3.tscn"


func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	await restart()
	var st1: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		steer_to(240.0)
		tap_step(st1, 0, true), 90)
	var st: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		if t < 30:
			steer_to(120.0)
			return
		if st[0] < 2:   # 도움닫기 점프로 단 모서리를 넘어 과거의 나 머리 위로
			go(1 if player.global_position.x < 236.0 else 0)
			tap_step(st, 0, player.global_position.x >= 140.0)
			if st[0] == 1 and st[1] == 0 and player.is_on_floor() and player.global_position.y < 200.0:
				go(0)
				st[0] = 2
		else:
			go(-1)
			tap_step(st, 2, true), -1, 480)
	check("1-3 solved with 1 ghost", lm.cleared, str(player.global_position))
	save_solution()
