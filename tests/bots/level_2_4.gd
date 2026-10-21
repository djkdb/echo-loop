extends "res://tests/test_base.gd"
## 2-4 교대 근무: 1루프 위층 판 A → 2루프 문 A를 지나 아래층 판 B → 3루프 문 B를 지나 판 C → 4루프 나는 세 문을 지나 출구.


func test_level() -> String:
	return "res://levels/level_2_4.tscn"


## 위층 판 A의 문지기를 넘어 문 A를 지나 오른쪽 구멍으로 떨어진다. 떨어진 뒤엔 then(t)을 부른다.
func _down_then(st: Array, t: int, then: Callable) -> void:
	if player.global_position.y < 300.0:
		go(1)
		tap_step(st, 0, player.global_position.x >= 30.0)
	else:
		then.call(t)


func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	await restart()
	await record_loop(func(t: int) -> void: steer_to(110.0), 60)
	var s2: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		_down_then(s2, t, func(_t: int) -> void: steer_to(440.0)), 140)
	var s3: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		_down_then(s3, t, func(_t: int) -> void: steer_to(220.0)), 200)
	var st: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		_down_then(st, t, func(_t: int) -> void:
			go(-1)
			tap_step(st, 1, player.global_position.x <= 275.0)), -1, 600)
	check("2-4 solved with 3 ghosts", lm.cleared, "%s step=%d" % [player.global_position, st[0]])
	save_solution()
