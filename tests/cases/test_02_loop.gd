extends "res://tests/test_base.gd"
## LoopManager·HUD(2단계): 600틱 종료, recording 600, R 즉시 종료, Shift+R은 end_loop와 분리, 리셋 복귀.


func run_case() -> void:
	var sp: Vector2 = player.spawn_point.global_position
	driver.probe = func() -> Array: return [player.global_position, player.recording.size(), lm.tick, Input.is_action_just_pressed("end_loop", true), Input.is_action_just_pressed("end_loop")]
	check("priority: player before loop manager", player.process_physics_priority < lm.process_physics_priority)
	check("loop_ticks = 600 (10s)", lm.loop_ticks == 600, str(lm.loop_ticks))
	var lens: Array = []
	lm.loop_ended.connect(func(_i: int) -> void: lens.append([player.recording.size(), lm.tick]))
	await restart()
	var la: Array = await run_loop(func(t: int) -> void: Input.action_press("move_right"))
	check("auto end after exactly 600 ticks with recording length 600", lens.size() == 1 and lens[0] == [600, 600], str(lens))
	check("loop_index = 2 after one loop", lm.loop_index == 2)
	await tick(1)
	var a: Array = driver.log[-1][2]
	check("after reset: player at spawn, recording empty, tick 0", a[0] == sp and a[1] == 0 and a[2] == 0, str(a))
	await frame()
	check("HUD: LOOP 2 / 나 ×2", (hud.get_node("LoopLabel") as Label).text == "LOOP 2" and (hud.get_node("CountLabel") as Label).text == "나 ×2")

	# R: 보인 틱에 즉시 종료
	lens.clear()
	var lr: Array = await run_loop(Callable(), 100)
	var seen: int = -1
	for e: Array in lr:
		if e[2][3]:
			seen = e[1]
	# 로그의 lm.tick은 그 틱 처리 전 값이라, 그 틱에 끝나면 녹화 길이는 seen + 1
	check("R ends the loop on the tick it is seen, recording = ticks so far", lens.size() == 1 and lens[0][0] == lens[0][1] and lens[0][1] == seen + 1, "lens=%s seen=%d" % [lens, seen])

	# Shift+R: restart_stage만, end_loop(exact)는 안 걸림
	lens.clear()
	var restarted: Array = []
	lm.stage_restarted.connect(func() -> void: restarted.append(lm.loop_index), CONNECT_ONE_SHOT)
	await tick(30)
	var start: int = driver.log.size()
	key(KEY_SHIFT, true, true)
	await tick(2)
	key(KEY_R, true, true)
	await tick(3)
	key(KEY_R, false, true)
	key(KEY_SHIFT, false)
	await tick(3)
	var loose: bool = false
	var exact: bool = false
	for e: Array in driver.log.slice(start):
		loose = loose or e[2][4]
		exact = exact or e[2][3]
	check("Shift+R restarts stage once and does not end the loop", restarted.size() == 1 and lens.is_empty() and lm.loop_index == 1)
	check("Shift+R: loose end_loop would match, exact does not", loose and not exact, "loose=%s exact=%s" % [loose, exact])
