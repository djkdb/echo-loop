extends "res://tests/test_base.gd"
## 오브젝트 시연 방이 혼자 풀린다(A3)

func test_level() -> String:
	return "res://levels/level_test_objects.tscn"

func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	var lift: MovingPlatform = level.get_node("Lift")
	var laser: Laser = level.get_node("Laser")
	var blue: ColorDoor = level.get_node("BlueDoor")
	var box: Box = level.get_node("Box")
	check("objects room: 15s loop, 4 ghosts", lm.loop_ticks == 900 and lm.max_ghosts == 4)
	driver.probe = func() -> Array: return [player.global_position, lift.global_position, laser.is_on, blue.is_open, box.box_position]
	await restart()
	var phase: Array = [0]
	var step: Callable = func(t: int) -> void:
		var p: Vector2 = player.global_position
		var ph: int = phase[0]
		if ph == 0:   # 레버(80)를 당겨 레이저 끄기
			steer_to(80.0)
			if absf(p.x - 80.0) < 4.0:
				Input.action_press("interact"); phase[0] = 1
		elif ph == 1:
			Input.action_release("interact")
			if not laser.is_on: phase[0] = 2
		elif ph == 2: # 상자를 판(220) 위로 민다
			steer_to(176.0)
			if box.box_position.x >= 218.0:
				phase.append(t); phase[0] = 7
		elif ph == 7: # 제자리 점프 후 앞으로 → 상자를 넘는다
			Input.action_release("move_right")
			if t == phase[1] + 1: Input.action_press("jump")
			if t >= phase[1] + 5:
				Input.action_release("jump"); phase[0] = 3
		elif ph == 3: # 엘리베이터(410)가 바닥에 올 때 올라탄다
			if lift.global_position.y > 475.0 or p.x > 345.0: steer_to(410.0)
			else: steer_to(325.0)
			if p.x > 360.0 and p.y < 400.0: phase[0] = 4
		elif ph == 4: # 꼭대기까지 타고 간다
			steer_to(410.0)
			if lift.global_position.y < 260.0: phase[0] = 5
		elif ph == 5: # 왼쪽 선반으로, 주황 문 통과 → 시한 버튼(230)
			steer_to(230.0)
			if absf(p.x - 230.0) < 4.0 and p.y < 160.0:
				Input.action_press("interact"); phase[0] = 6
		else:         # 파랑 문이 열린 3초 안에 출구(80)로
			Input.action_release("interact")
			steer_to(20.0)
	var log: Array = await run_loop(step, -1, 900)
	check("objects room is solvable alone: box→plate, lever→laser off, lift up, orange door, button→blue door, exit", lm.cleared, "phase=%d player=%s" % [phase[0], player.global_position])
