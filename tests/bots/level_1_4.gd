extends "res://tests/test_base.gd"
## 1-4 두 개의 문: 1루프 압력판 → 2루프 판 문을 지나 위층 레버를 직접 당기고 레버 문으로.


func test_level() -> String:
	return "res://levels/level_1_4.tscn"


func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	await restart()
	await record_loop(func(t: int) -> void: steer_to(90.0), 100)
	var st: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		if t < 20:
			return
		var p: Vector2 = player.global_position
		if st[0] <= 1:   # 문지기를 넘어 판 문을 지나 디딤단 위로
			go(1)
			tap_step(st, 0, p.x >= 34.0)
			if st[0] == 1 and st[1] == 0 and p.x >= 252.0:
				st[0] = 2
		if st[0] == 2 or st[0] == 3:
			go(1)
			tap_step(st, 2, true)
			if st[0] == 3 and st[1] == 0 and player.is_on_floor() and p.y < 260.0:
				go(0)
				st[0] = 4
		elif st[0] == 4 or st[0] == 5:   # 디딤단에서 위층으로
			go(-1)
			tap_step(st, 4, true)
			if st[0] == 5 and st[1] == 0 and player.is_on_floor() and p.y < 140.0:
				st[0] = 6
		elif st[0] == 6 or st[0] == 7:   # 레버
			steer_to(180.0)
			tap_step(st, 6, absf(p.x - 180.0) < 4.0, "interact")
			if st[0] == 7 and st[1] == 0:
				st[0] = 8
		elif st[0] >= 8:
			steer_to(40.0), -1, 600)
	check("1-4 solved with 1 ghost", lm.cleared, "%s step=%d" % [player.global_position, st[0]])
	save_solution()
