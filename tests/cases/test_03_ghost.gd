extends "res://tests/test_base.gd"
## 녹화 → 고스트 재생(3단계): 재생 일치, T틱 = recording[T-1], 벽 붕괴, 상한, 밟기, 짧은 녹화 정지,
## 스폰 겹침, 리셋 순간이동 튕김, 리셋 때 누르던 키 차단, Shift+R 삭제.


func run_case() -> void:
	var sp: Vector2 = player.spawn_point.global_position
	driver.probe = func() -> Array:
		var gp: Array = []
		for g: Ghost in lm.ghosts():
			gp.append(g.global_position)
		return [player.global_position, player.is_on_floor(), gp]
	await restart()
	await run_loop(func(t: int) -> void:
		if t < 70: steer_to(540.0)
		if t == 40: Input.action_press("jump")
		if t == 42: Input.action_release("jump")
		if t > 200 and t < 260: steer_to(200.0)
		if t >= 260: release_all())
	var g1: Ghost = lm.ghosts()[0]
	var frames: Array = g1.frames()
	check("ghost created with 600 frames (deep copy survives reset)", frames.size() == 600 and player.recording.size() <= 1)
	check("ghost layer 3, mask world+ghost_barrier (33), sync_to_physics", g1.collision_layer == 4 and g1.collision_mask == 33 and g1.sync_to_physics)
	var l2: Array = await run_loop()
	var l3: Array = await run_loop()
	var p2: Array = l2.map(func(e: Array) -> Vector2: return e[2][2][0])
	var p3: Array = l3.map(func(e: Array) -> Vector2: return e[2][2][0])
	var bad: int = -1
	for k in p2.size():
		if p2[k] != (frames[maxi(k - 1, 0)]["pos"] as Vector2):
			bad = k
			break
	check("replay twice: ghost positions identical every tick", p2.size() == 600 and p2 == p3)
	check("ghost at tick T == recording[T-1] (no off-by-one)", bad == -1, "first bad=%d" % bad)
	check("max_ghosts=2: count stays 2", lm.ghost_count() == 2 and lm.ghosts_root.get_child_count() == 2)

	# 경로 위 벽 → 닿는 틱에 붕괴, 다음 루프에 부활
	var hit: int = blocked_frame(frames, 320.0)
	var wall: StaticBody2D = add_wall(Rect2(320, 100, 20, 1100))
	collapses.clear()
	await run_loop()
	var c1: Array = collapses.filter(func(c: Array) -> bool: return c[0] == 1)
	check("wall on path -> collapsed exactly on the tick it would enter", c1.size() == 1 and c1[0][1] == hit, "c=%s expected %d" % [c1, hit])
	remove(wall)
	await tick(1)
	check("collapsed ghost revives on reset", g1.alive and g1.visible)

	# Shift+R → 고스트 0
	await tap_key(KEY_R, true)
	await tick(2)
	check("Shift+R removes all ghosts", lm.ghost_count() == 0 and lm.ghosts_root.get_child_count() == 0 and lm.loop_index == 1)

	# 짧은 녹화(R로 일찍 끝냄) → 마지막 위치에 실체 유지 / 그 위에 서기 / 스폰 겹침에 안 밀림
	await restart()
	await run_loop(func(t: int) -> void:
		if t < 30: Input.action_press("move_right")
		else: release_all(), 60)
	var gs: Ghost = lm.ghosts()[0]
	var last: Vector2 = gs.frames()[-1]["pos"]
	var stop_ok: Array = [true]
	var start_x: Array = [0.0]
	var lb: Array = await run_loop(func(t: int) -> void:
		if t == 2: start_x[0] = player.global_position.x
		if t > 70 and gs.global_position != last: stop_ok[0] = false
		if t >= 100 and t < 128: Input.action_press("move_right")
		if t == 115: Input.action_press("jump")
		if t == 117: Input.action_release("jump")
		if t >= 128: Input.action_release("move_right"), 300)
	var on_ghost: Array = lb.filter(func(e: Array) -> bool: return e[1] > 200 and e[1] < 298)
	check("short-recording ghost stays at last position, alive & solid", stop_ok[0] and gs.alive and not gs.get_node("CollisionShape2D").disabled)
	check("player can stand on the stopped ghost", on_ghost.size() > 50 and on_ghost.all(func(e: Array) -> bool: return e[2][1] and absf((e[2][0] as Vector2).y - (last.y - 64.0)) < 1.0))
	check("spawn overlap: player not pushed sideways at loop start", absf(start_x[0] - sp.x) < 0.01, "x=%.2f" % start_x[0])

	# 고스트 위에 선 채 루프 종료(시간 초과) → 다음 루프 시작 때 튕기지 않음
	var n_end: int = ended.size()
	await run_loop(func(t: int) -> void: pass)
	await tick(8)
	var max_d: float = 0.0
	for e: Array in driver.log.slice(driver.log.size() - 8):
		max_d = maxf(max_d, (e[2][0] as Vector2).distance_to(sp))
	check("standing on ghost at loop end -> next loop starts at spawn (not flung)", max_d < 10.0, "max dist=%.1f" % max_d)

	# 리셋 순간 D를 누른 채면 다음 루프에서 안 움직임, 뗐다 누르면 움직임
	await restart()
	await tick(5)
	Input.action_press("move_right")
	await tick(20)
	await tap_key(KEY_R)
	await tick(3)
	var x0: float = player.global_position.x
	await tick(30)
	check("D held through reset -> no movement next loop", absf(player.global_position.x - x0) < 0.01)
	Input.action_release("move_right")
	await tick(2)
	Input.action_press("move_right")
	await tick(10)
	Input.action_release("move_right")
	check("after release & re-press -> moves", player.global_position.x - x0 > 30.0)
