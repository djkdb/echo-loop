extends "res://tests/test_base.gd"
## 3-4 역순: 출구 앞 문은 A, B 순서지만 녹화는 B가 먼저다. 1루프 왼쪽 구멍의 판 B(문 X도 연다) → 2루프 문 X를 지나 구멍의 판 A
## → 3루프 나는 문 X를 지나 구멍을 건너 문 A·B로.


func test_level() -> String:
	return "res://levels/level_3_4.tscn"


func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	await restart()
	await record_loop(func(t: int) -> void: steer_to(65.0), 60)
	await record_loop(func(t: int) -> void:
		if t >= 20: steer_to(215.0), 90)
	var st: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		if t < 40:
			return
		if st[0] <= 1:
			hop_step(st, 0, 170.0, 290.0)
		else:
			go(1), -1, 600)
	check("3-4 solved with 2 ghosts", lm.cleared, "%s step=%d" % [player.global_position, st[0]])
	save_solution()
