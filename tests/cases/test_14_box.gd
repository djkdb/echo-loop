extends "res://tests/test_base.gd"
## 상자: 밀기·판·탑승·레이저 차단, 녹화=재생(A1)

func run_case() -> void:
	var box: Box = add_obj("res://objects/box.tscn", Vector2(220, 1100))
	var plate: PressurePlate = add_obj("res://objects/pressure_plate.tscn", Vector2(340, 1200))
	driver.probe = func() -> Array: return [box.box_position, plate.is_on, player.global_position, player.is_on_floor()]
	await restart()
	await tick(40)
	check("box falls and lands on the floor", absf(box.box_position.y - 1176.0) < 0.6, "y=%.3f" % box.box_position.y)

	# 1) Player가 밀어 압력판 위로 → 녹화 / 재생 루프에서 상자 경로·판 상태 동일
	await restart()
	var la: Array = await run_loop(func(t: int) -> void:
		if t < 60: steer_to(300.0)
		else: steer_to(120.0), 200)
	var end_x: float = (la[150][2][0] as Vector2).x
	check("1) player pushes the box to the right (onto the plate)", end_x > 320.0 and end_x < 360.0, "box x=%.2f" % end_x)
	check("1) box presses the plate after player walks away", la[150][2][1] and (la[150][2][2] as Vector2).x < 200.0)
	var lb: Array = await run_loop(Callable(), 200)
	var lc: Array = await run_loop(Callable(), 200)
	var rec_boxes: Array = la.map(func(e: Array) -> Variant: return e[2][0])
	var rep_boxes: Array = lb.map(func(e: Array) -> Variant: return e[2][0])
	var rep2: Array = lc.map(func(e: Array) -> Variant: return e[2][0])
	var first_diff: int = -1
	for i in mini(rec_boxes.size(), rep_boxes.size()):
		if rec_boxes[i] != rep_boxes[i]:
			first_diff = i
			break
	check("1) ghost pushes the box exactly like the recording (every tick)", first_diff == -1 and rec_boxes.size() == rep_boxes.size(), "first diff tick=%d rec=%s rep=%s" % [first_diff, rec_boxes[first_diff] if first_diff >= 0 else "", rep_boxes[first_diff] if first_diff >= 0 else ""])
	check("1) two replays identical", rep_boxes == rep2)
	check("1) reset returns box to its start (placed at y=1100, falls again)", (lb[0][2][0] as Vector2).distance_to(Vector2(220, 1100)) < 1.0, str(lb[0][2][0]))
	check("1) no ghost collapsed while pushing", collapses.is_empty(), str(collapses))

	# 2) 상자 위에 올라서기, 고스트가 미는 상자 위에서 같이 이동
	remove(box)
	box = add_obj("res://objects/box.tscn", Vector2(220, 1176))
	var box2: Box = box
	driver.probe = func() -> Array: return [box2.box_position, plate.is_on, player.global_position, player.is_on_floor()]
	await restart()
	await run_loop(func(t: int) -> void:
		if t > 60 and t < 100: steer_to(330.0)
		if t == 100: Input.action_release("move_right"), 110)       # g1: 60틱 쉬었다가 밀기
	var rode: Array = await run_loop(func(t: int) -> void:
		if t == 6: Input.action_press("jump")
		if t == 8: Input.action_release("jump")
		if t < 6: steer_to(150.0)
		elif t < 30: steer_to(220.0)
		else:
			Input.action_release("move_right"); Input.action_release("move_left"), 108)
	var on_box: Array = rode.filter(func(e: Array) -> bool: return e[1] > 52 and e[1] < 106)
	var stand_ok: bool = on_box.all(func(e: Array) -> bool: return e[2][3] and absf(((e[2][0] as Vector2).y - 24.0) - ((e[2][2] as Vector2).y + 32.0)) < 3.0)
	var carried: float = (on_box[-1][2][2] as Vector2).x - (on_box[0][2][2] as Vector2).x
	var box_moved: float = (on_box[-1][2][0] as Vector2).x - (on_box[0][2][0] as Vector2).x
	check("2) player stands on the box", stand_ok)
	check("2) player is carried when a ghost pushes the box", box_moved > 50.0 and absf(carried - box_moved) <= 6.5, "box moved %.1f, player moved %.1f" % [box_moved, carried])

	# 3) 상자가 레이저를 막는다
	var laser: Laser = add_obj("res://objects/laser.tscn", Vector2(60, 1170))
	await restart()
	await tick(5)
	var box_left: float = box.box_position.x - 24.0
	check("3) box blocks the laser beam", absf(laser.beam_length - (box_left - 60.0)) < 1.0, "len=%.1f expected %.1f" % [laser.beam_length, box_left - 60.0])
	remove(laser)
