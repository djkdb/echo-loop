extends "res://tests/test_base.gd"
## 2-1 엘리베이터: 1루프 판 위에 서 있기 → 2루프 올라가는 발판에 타고 꼭대기 선반의 출구로.


func test_level() -> String:
	return "res://levels/level_2_1.tscn"


func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	var lift: MovingPlatform = level.get_node("Lift")
	await restart()
	await record_loop(func(t: int) -> void: steer_to(120.0), 100)
	var st: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		var p: Vector2 = player.global_position
		if st[0] <= 1:   # 오르기 시작한 발판으로 뛰어오른다
			steer_to(330.0)
			tap_step(st, 0, p.x >= 200.0)
			if st[0] == 1 and st[1] == 0 and player.is_on_floor() and p.x > 290.0 and p.y < 430.0:
				st[0] = 2
		elif st[0] == 2:   # 꼭대기까지 타고 간다
			go(0)
			if lift.global_position.y <= 150.0:   # 선반 옆면에 붙어 있다가 꼭대기에서 올라선다
				st[0] = 3
		else:
			go(-1), -1, 600)
	check("2-1 solved with 1 ghost", lm.cleared, "%s step=%d" % [player.global_position, st[0]])
	save_solution()
