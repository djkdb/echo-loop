extends "res://tests/test_base.gd"
## 2-5 파랑과 주황: 1루프 디딤단 → 위층 → 파랑 문 → 칸에 떨어져 칸 판 위(주황 지름길로 들어가면 재생 때 붕괴)
## → 2루프 판 위(파랑 문이 닫히지만 1번은 그대로 지나간다) → 3루프 나는 두 문을 지나 출구.


func test_level() -> String:
	return "res://levels/level_2_5.tscn"


func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	await restart()
	var s1: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		var p: Vector2 = player.global_position
		if s1[0] <= 1:   # 디딤단 위로
			steer_to(200.0)
			tap_step(s1, 0, true)
			if s1[0] == 1 and s1[1] == 0 and player.is_on_floor() and p.y < 300.0:
				go(0)
				s1[0] = 2
		elif s1[0] <= 3:   # 구멍으로 위층에 올라 왼쪽으로
			go(0)   # 발이 바닥판보다 높아진 뒤에 왼쪽으로(머리가 판 밑에 부딪히지 않게)
			tap_step(s1, 2, true)
			if s1[0] == 3 and p.y < 125.0:
				s1[0] = 4
		else:
			go(-1), 200)
	var s2: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		var p: Vector2 = player.global_position
		if p.x < 230.0:
			go(1)
			tap_step(s2, 0, true)
		else:
			steer_to(270.0), 90)
	var st: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		go(1)
		tap_step(st, 0, true), -1, 600)
	check("2-5 solved with 2 ghosts", lm.cleared, "%s step=%d" % [player.global_position, st[0]])
	save_solution()
