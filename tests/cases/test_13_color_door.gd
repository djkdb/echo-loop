extends "res://tests/test_base.gd"
## 색 문(A1)

func run_case() -> void:
	check("layers: player mask 21 (world+ghost+player_barrier), ghost mask 33 (world+ghost_barrier)", player.collision_mask == 21 and (load("res://actors/ghost.tscn").instantiate() as Ghost).collision_mask == 33)
	var blue: ColorDoor = add_obj("res://objects/color_door.tscn", Vector2(240, 1120), {"door_color": ColorDoor.DoorColor.BLUE})
	await tick(2)
	check("blue door on player_barrier layer, closed", blue.collision_layer == 16 and not blue.is_open)

	# 1) 파랑: Player는 막힘
	await restart()
	await run_loop(func(t: int) -> void: steer_to(330.0), 60)
	var g: Ghost = lm._ghosts[0]
	var px: float = (g._frames[-1]["pos"] as Vector2).x
	check("1) blue door blocks the player", px < 220.0 + 0.5, "x=%.2f" % px)
	# 파랑 문을 지나가는 고스트(합성 경로): 붕괴하지 않음
	await restart()
	var frames: Array[Dictionary] = []
	for i in 120:
		frames.append({"pos": Vector2(minf(150.0 + 4.0 * i, 330.0), 1167.995), "flip": false, "interact": false, "jump": false})
	var ghost: Ghost = lm.ghost_scene.instantiate()
	ghost.setup(frames, 1)
	lm.ghosts_root.add_child(ghost)
	watch_ghost(ghost)
	ghost.reset()
	collapses.clear()
	await tick(80)
	check("1) ghost passes through blue door", collapses.is_empty() and ghost.global_position.x > 300.0, "x=%.1f collapses=%s" % [ghost.global_position.x, collapses])
	lm.ghosts_root.remove_child(ghost)
	ghost.free()
	remove(blue)

	# 2) 주황: Player는 통과, 그 녹화를 재생하는 고스트는 문에 닿는 틱에 붕괴
	var orange: ColorDoor = add_obj("res://objects/color_door.tscn", Vector2(240, 1120), {"door_color": ColorDoor.DoorColor.ORANGE})
	await restart()
	await run_loop(func(t: int) -> void: steer_to(330.0), 60)
	g = lm._ghosts[0]
	px = (g._frames[-1]["pos"] as Vector2).x
	check("2) orange door lets the player through", px > 320.0, "x=%.2f" % px)
	var hit: int = -1
	for i in g._frames.size():
		if (g._frames[i]["pos"] as Vector2).x + 20.0 > 220.0 - 0.08 + 0.5:
			hit = i
			break
	collapses.clear()
	await run_loop(Callable(), 60)
	check("2) ghost replaying through orange door collapses on touching tick", collapses.size() == 1 and collapses[0][1] == hit, "collapses=%s expected %d" % [collapses, hit])

	# 3) 신호로 열리는 색 문(주황, 압력판): 열려 있을 때는 고스트도 통과
	remove(orange)
	var plate: PressurePlate = add_obj("res://objects/pressure_plate.tscn", Vector2(330, 1200))
	var src: Array[NodePath] = [NodePath("../PressurePlate")]
	var o2: ColorDoor = add_obj("res://objects/color_door.tscn", Vector2(240, 1120), {"door_color": ColorDoor.DoorColor.ORANGE, "sources": src})
	await restart()
	await run_loop(func(t: int) -> void: steer_to(330.0), 200)   # g1: 판 위에 서 있는 문지기(주황 문 통과 녹화)
	collapses.clear()
	await run_loop(Callable(), 120)
	check("3) orange door collapses ghost while closed (plate not yet pressed)", collapses.size() == 1, str(collapses))
