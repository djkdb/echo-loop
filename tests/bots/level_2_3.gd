extends "res://tests/test_base.gd"
## 2-3 방패: 1루프 아래 통로로 내려가 레이저 앞에 서기 → 2루프 레버(문 열림 + 레이저 켜짐)를 당기고
## 과거의 나가 빔을 막는 동안 통로를 지나 출구로.


func test_level() -> String:
	return "res://levels/level_2_3.tscn"


func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	await restart()
	await record_loop(func(t: int) -> void:
		if player.global_position.y < 400.0:
			steer_to(130.0)
		else:
			steer_to(20.0), 140)
	var st: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		var p: Vector2 = player.global_position
		if st[0] <= 1:
			steer_to(220.0)
			tap_step(st, 0, absf(p.x - 220.0) < 4.0, "interact")
			if st[0] == 1 and st[1] == 0:
				st[0] = 2
		elif st[0] == 2:
			go(0)
			if t >= 50:
				st[0] = 3
		elif p.y < 400.0:
			steer_to(130.0)
		else:
			go(1), -1, 600)
	check("2-3 solved with 1 ghost", lm.cleared, "%s step=%d failed=%d" % [player.global_position, st[0], failed.size()])
	save_solution()
