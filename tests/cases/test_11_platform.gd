extends "res://tests/test_base.gd"
## 이동 발판: 탑승·재생 결정론·끼임 방지(A1)

func seq_of(log: Array, idx: int) -> Array:
	return log.map(func(e: Array) -> Variant: return e[2][idx])

func run_case() -> void:
	# A) 항상 움직이는 세로 엘리베이터: 바닥과 같은 높이에서 시작해 200px 오르내림
	var lift: MovingPlatform = add_obj("res://objects/moving_platform.tscn", Vector2(300, 1210))
	driver.probe = func() -> Array:
		var g: Vector2 = lm._ghosts[0].global_position if lm.ghost_count() > 0 else Vector2.ZERO
		return [lift.global_position, player.global_position, player.is_on_floor(), g]
	await restart()
	# 발판이 바닥 높이로 돌아오는 200틱에 맞춰 올라탄다
	var la: Array = await run_loop(func(t: int) -> void:
		if t < 192: steer_to(220.0)
		else: steer_to(300.0), 400)
	# 플레이어가 발판에 탄 뒤(위로 올라간 구간) 발판 윗면과의 간격
	var ride: Array = la.filter(func(e: Array) -> bool: return e[1] > 215 and (e[2][0] as Vector2).y < 1150.0)
	var max_gap: float = 0.0
	for e in ride:
		max_gap = maxf(max_gap, absf(((e[2][0] as Vector2).y - 10.0) - ((e[2][1] as Vector2).y + 32.0)))
	check("A) player rides the lift up and down (stays on top)", ride.size() > 50 and max_gap <= 4.5, "ride ticks=%d max gap/overlap=%.2f" % [ride.size(), max_gap])
	collapses.clear()
	var lb: Array = await run_loop(Callable(), 400)
	var lc: Array = await run_loop(Callable(), 400)
	check("A) ghost riding the lift never collapses (2 replays)", collapses.is_empty(), str(collapses))
	check("A) ghost positions identical across replays", seq_of(lb, 3) == seq_of(lc, 3))
	check("A) lift positions identical every loop", seq_of(la, 0) == seq_of(lb, 0) and seq_of(lb, 0) == seq_of(lc, 0))
	check("A) after reset lift back at start", (lb[1][2][0] as Vector2).distance_to(Vector2(300, 1210)) < 2.1, str(lb[1][2][0]))
	remove(lift)

	# B) 압력판이 눌린 동안만 움직임, 고스트가 눌러도 같은 움직임
	var plate: PressurePlate = add_obj("res://objects/pressure_plate.tscn", Vector2(200, 1200))
	var srcs: Array[NodePath] = [NodePath("../PressurePlate")]
	var plat: MovingPlatform = add_obj("res://objects/moving_platform.tscn", Vector2(330, 1000), {"sources": srcs, "travel": Vector2(0, -150)})
	driver.probe = func() -> Array: return [plat.global_position, plate.is_on]
	await restart()
	var ba: Array = await run_loop(func(t: int) -> void:
		if t < 100: steer_to(200.0)
		else: steer_to(120.0), 300)
	var moved_while_on: bool = false
	var still_after_off: bool = true
	var off_tick: int = -1
	for i in range(1, ba.size()):
		if ba[i][2][1] and ba[i][2][0] != ba[i - 1][2][0]: moved_while_on = true
		if off_tick < 0 and ba[i - 1][2][1] and not ba[i][2][1]: off_tick = i
	for i in range(off_tick + 2, ba.size()):
		if ba[i][2][0] != ba[i - 1][2][0]: still_after_off = false
	check("B) platform moves while plate is pressed and stops when released", moved_while_on and off_tick > 0 and still_after_off, "off at %d" % off_tick)
	var bb: Array = await run_loop(Callable(), 300)
	check("B) same platform motion when a ghost presses the plate", seq_of(ba, 0) == seq_of(bb, 0))

	# C) 내려오는 발판에 밀린 녹화도 재생 때 붕괴하지 않는다(가짜 패러독스 방지)
	remove(plat); remove(plate)
	var lift2: MovingPlatform = add_obj("res://objects/moving_platform.tscn", Vector2(300, 1210))
	driver.probe = Callable()
	await restart()
	await run_loop(func(t: int) -> void: steer_to(300.0), 400)
	collapses.clear()
	await run_loop(Callable(), 400)
	await run_loop(Callable(), 400)
	check("C) ghost whose recording was squeezed by the lift does not collapse", collapses.is_empty(), str(collapses))
