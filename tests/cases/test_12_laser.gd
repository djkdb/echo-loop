extends "res://tests/test_base.gd"
## 레이저(A1)

func run_case() -> void:
	var lever: Lever = add_obj("res://objects/lever.tscn", Vector2(170, 1200))
	var srcs: Array[NodePath] = [NodePath("../Lever")]
	# 빔: x 250에서 오른쪽, 몸통 높이(y 1170). 계단(x 400) 옆면에서 막힌다.
	var laser: Laser = add_obj("res://objects/laser.tscn", Vector2(250, 1170), {"sources": srcs})
	await tick(3)
	check("beam stops at world (stair side x=400)", absf(laser.beam_length - 150.0) < 1.0, "len=%.1f" % laser.beam_length)

	# 1) Player가 켜진 빔에 닿으면 실패: 고스트 없음, 루프 번호 그대로, 스폰 복귀, 다음 루프 녹화 600
	await restart()
	var n_fail: int = failed.size()
	await run_loop(func(t: int) -> void:
		if t < 20: steer_to(170.0)
		if t == 20: Input.action_press("interact")
		if t == 22: Input.action_release("interact")
		if t > 30: steer_to(320.0), -1, 400)
	check("1) player touching beam fails the loop", failed.size() == n_fail + 1 and ended.size() == 0, "failed=%d ended=%d" % [failed.size(), ended.size()])
	check("1) failed loop leaves no ghost and keeps loop number", lm.ghost_count() == 0 and lm.loop_index == 1)
	await tick(1)
	check("1) player back at spawn, laser off (lever reset)", player.global_position.distance_to(player.spawn_point.global_position) < 2.0 and not laser.is_on)
	var lens: Array = []
	lm.loop_ended.connect(func(_i: int) -> void: lens.append(player.recording.size()), CONNECT_ONE_SHOT)
	await run_loop()
	check("1) next loop after failure records exactly 600 ticks", lens == [600], str(lens))

	# 2) 고스트는 빔을 막는 방패: 붕괴하지 않고 빔이 고스트에서 끝난다
	await restart()
	await run_loop(func(t: int) -> void: steer_to(300.0), 80)   # g1: 빔 자리(x 300)에 멈춰 선 녹화
	var g: Ghost = lm._ghosts[0]
	collapses.clear()
	var beam: Array = []
	var n_fail2: int = failed.size()
	await run_loop(func(t: int) -> void:
		steer_to(170.0)
		if t == 10: Input.action_press("interact")
		if t == 12: Input.action_release("interact")
		if t == 150: beam.append([laser.is_on, laser.beam_length]), 200)
	check("2) ghost standing in the beam does not collapse", collapses.is_empty() and g.alive, str(collapses))
	check("2) beam ends at the ghost (shield)", beam.size() == 1 and beam[0][0] and absf(beam[0][1] - ((300.0 - 20.0) - 250.0)) < 1.0, str(beam))
	# 고스트 뒤(빔 그림자)에 선 Player는 실패하지 않는다
	await run_loop(func(t: int) -> void:
		steer_to(170.0)
		if t == 10: Input.action_press("interact")
		if t == 12: Input.action_release("interact")
		if t == 60: player.global_position = Vector2(340, 1167.9)
		if t > 60: release_all(), 140)
	check("2) player behind the ghost shield is safe", failed.size() == n_fail2, "failed %d -> %d" % [n_fail2, failed.size()])
	# 고스트가 빠지면(덮어쓰기 대상) 빔이 다시 끝까지 간다
	lm.select_ghost(1)
	var benched_beam: Array = []
	driver.hook = func(t: int) -> void:
		steer_to(170.0)
		if t == 10: Input.action_press("interact")
		if t == 12: Input.action_release("interact")
		if t == 100: benched_beam.append([laser.is_on, laser.beam_length])
	await tick(110)
	driver.hook = Callable()
	check("2) benched ghost no longer blocks the beam", benched_beam.size() == 1 and benched_beam[0][0] and absf(benched_beam[0][1] - 150.0) < 1.0, str(benched_beam))
	lm.select_ghost(1)

	# 3) 닫힌 문이 빔을 막고, 열리면 통과
	remove(laser)
	var plate: PressurePlate = add_obj("res://objects/pressure_plate.tscn", Vector2(200, 1200))
	var dsrc: Array[NodePath] = [NodePath("../PressurePlate")]
	var door: Door = add_obj("res://objects/door.tscn", Vector2(300, 1120), {"sources": dsrc})
	var laser2: Laser = add_obj("res://objects/laser.tscn", Vector2(250, 1170))
	await restart()
	await tick(3)
	var closed_len: float = laser2.beam_length
	var open_len: Array = [0.0]
	await run_loop(func(t: int) -> void:
		steer_to(200.0)
		if t == 60: open_len[0] = laser2.beam_length, 70)
	check("3) closed door blocks the beam", absf(closed_len - 30.0) < 1.0, "len=%.1f" % closed_len)
	check("3) open door lets the beam through", absf(open_len[0] - 150.0) < 1.0, "len=%.1f" % open_len[0])
