extends "res://tests/test_base.gd"
## 3-3 짐꾼: 1루프 상자를 턱 밑까지 밀고 그 위에 서기 → 2루프 상자 위의 과거의 나를 밟고 턱 위 출구로.


func test_level() -> String:
	return "res://levels/level_3_3.tscn"


func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	var box: Box = level.get_node("Box")
	var s1: Array = [0, 0, ""]
	await restart()
	await record_loop(func(t: int) -> void:
		if s1[0] == 0:   # 상자를 턱 옆면까지 민다
			go(1)
			if box.box_position.x >= 295.0:
				go(0)
				s1[0] = 1
		elif s1[0] <= 2:   # 제자리 점프로 상자 위에
			tap_step(s1, 1, true)
			if s1[0] == 2:
				steer_to(296.0), 130)
	var st: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		if t < 110:
			return
		var p: Vector2 = player.global_position
		if st[0] <= 1:
			steer_to(296.0)
			tap_step(st, 0, p.x >= 200.0)
			if st[0] == 1 and st[1] == 0 and player.is_on_floor() and p.y < 350.0:
				st[0] = 2
		else:
			go(1)
			tap_step(st, 2, true), -1, 600)
	check("3-3 solved with 1 ghost (box carried by the past self)", lm.cleared, "%s step=%d" % [player.global_position, st[0]])
	save_solution()
