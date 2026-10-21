extends "res://tests/test_base.gd"
## 3-5 에코: 1루프 통로 끝 레이저 앞(방패) → 2루프 레버(문 + 레이저)를 당기고 통로를 지나 턱 앞 → 3루프 같은 길로 그 머리 위
## → 4루프 나는 방패 뒤로 통로를 지나 2단 탑으로 턱 위 출구.


func test_level() -> String:
	return "res://levels/level_3_5.tscn"


## 레버를 당기고 구멍으로 내려가 통로를 지나 문 밖(탑 자리 앞)까지 간 뒤 then(t).
func _through(st: Array, t: int, then: Callable) -> void:
	var p: Vector2 = player.global_position
	if st[0] <= 1:
		steer_to(180.0)
		tap_step(st, 0, absf(p.x - 180.0) < 4.0, "interact")
		if st[0] == 1 and st[1] == 0:
			st[0] = 2
	elif st[0] == 2:
		if p.y < 300.0:
			steer_to(110.0)
		elif p.x < 352.0 or p.y < 440.0:
			go(1)
		else:
			st[0] = 3
	else:
		then.call(t)


func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	await restart()
	await record_loop(func(t: int) -> void:
		if player.global_position.y < 300.0:
			steer_to(110.0)
		else:
			steer_to(20.0), 110)
	var s2: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		_through(s2, t, func(_t: int) -> void: steer_to(400.0)), 160)
	var s3: Array = [0, 0, "", 0]
	await record_loop(func(t: int) -> void:
		_through(s3, t, func(_t: int) -> void:
			steer_to(400.0)
			if s3[3] == 0 and player.is_on_floor() and player.global_position.y > 440.0:
				Input.action_press("jump")
				s3[3] = t
			elif s3[3] > 0 and t >= s3[3] + 3:
				Input.action_release("jump")), 230)
	var st: Array = [0, 0, "", 0, 0]
	await record_loop(func(t: int) -> void:
		if t < 60:
			return
		_through(st, t, func(tt: int) -> void:
			var p: Vector2 = player.global_position
			if st[4] == 0:   # 바닥에서 3번 머리 위로
				steer_to(400.0)
				if st[3] == 0 and player.is_on_floor() and p.y > 440.0:
					Input.action_press("jump"); st[3] = tt
				elif st[3] > 0 and tt >= st[3] + 3:
					Input.action_release("jump")
					if player.is_on_floor() and p.y < 360.0:
						st[4] = 1; st[3] = 0
			else:   # 탑 꼭대기에서 오른쪽 턱으로
				go(1)
				if st[3] == 0:
					Input.action_press("jump"); st[3] = tt
				elif tt >= st[3] + 3:
					Input.action_release("jump")), -1, 600)
	check("3-5 solved with 3 ghosts", lm.cleared, "%s step=%d failed=%d" % [player.global_position, st[0], failed.size()])
	save_solution()
