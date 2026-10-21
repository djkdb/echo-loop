extends "res://tests/test_base.gd"
## 리플레이: CLEAR 때 user://replays/<stage>.json 저장 → 리플레이 씬이 같은 결과로 재생.


func test_level() -> String:
	return "res://levels/level_1_2.tscn"


func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	DirAccess.remove_absolute(ReplayIO.path_for("level_1_2"))
	await restart()
	await run_loop(func(t: int) -> void: steer_to(90.0), 120)
	var st: Array = [0, 0, ""]
	await run_loop(func(t: int) -> void:
		if t > 20:
			go(1)
			tap_step(st, 0, player.global_position.x >= 34.0), -1, 600)
	check("precondition: stage cleared", lm.cleared)
	await tick(2)
	var originals: Array = [lm.ghosts()[0].frames().duplicate(true), player.recording.duplicate(true)]
	check("CLEAR saves user://replays/level_1_2.json", FileAccess.file_exists(ReplayIO.path_for("level_1_2")))
	var doc: Dictionary = ReplayIO.load_run("level_1_2")
	var same: bool = doc.get("runs", []).size() == 2
	for i in 2:
		if not same:
			break
		var a: Array = originals[i]
		var b: Array = doc["runs"][i]
		# CLEAR 뒤에도 Player 녹화는 계속 쌓이므로 저장본은 그 앞부분과 같아야 한다
		same = same and b.size() <= a.size() and b.size() > 50
		for k in mini(a.size(), b.size()):
			if (a[k]["pos"] as Vector2) != (b[k]["pos"] as Vector2) or a[k]["interact"] != b[k]["interact"] or a[k]["flip"] != b[k]["flip"]:
				same = false
				break
	check("loaded replay equals the recordings exactly (2 runs: keeper + me)", same)

	# 게임을 치우고 리플레이 씬으로 재생(드라이버는 LoopManager를 읽으므로 같이 멈춘다)
	driver.set_physics_process(false)
	remove_child(main)
	main.queue_free()
	await tick(2)
	var replay: Node2D = (load("res://game/replay.tscn") as PackedScene).instantiate()
	add_child(replay)
	var door: Door = replay.level.get_node("Door")
	var ok_pos: Array = [true, -1]
	var door_opened: Array = [false]
	var t: int = 0
	while t < 400:
		await tick(1)
		t += 1
		for i in 2:
			var g: Ghost = replay.ghosts[i]
			var frames: Array = doc["runs"][i]
			# 틱 T까지 처리된 뒤(다음 틱 시작) 고스트는 frames[T-1]에 있다(녹화보다 짧으면 마지막 위치)
			if replay.tick >= 1 and g.global_position != (frames[mini(replay.tick - 1, frames.size() - 1)]["pos"] as Vector2) and ok_pos[0]:
				ok_pos[0] = false
				ok_pos[1] = replay.tick
		door_opened[0] = door_opened[0] or door.is_open
	var me: Ghost = replay.ghosts[1]
	check("replay ghosts follow the recordings every tick", ok_pos[0], "first mismatch tick=%d" % ok_pos[1])
	check("replay: keeper opens the door, me reaches the exit, nobody collapses", door_opened[0] and me.global_position.x > 250.0 and replay.ghosts.all(func(g: Ghost) -> bool: return g.alive), "me=%s" % me.global_position)
	check("replay: last run drawn in 'me' style", me.me_style and not replay.ghosts[0].me_style)
	replay.queue_free()
