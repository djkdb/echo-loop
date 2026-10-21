extends "res://tests/test_base.gd"
## 되돌리기·덮어쓰기·타임라인(A2)

func run_case() -> void:
	var plate: PressurePlate = add_obj("res://objects/pressure_plate.tscn", Vector2(330, 1200))
	driver.probe = func() -> Array: return [plate.is_on]
	# 고스트 2명: 1번은 판으로, 2번은 점프 두 번 + E
	await restart()
	await run_loop(func(t: int) -> void: steer_to(330.0), 120)
	await run_loop(func(t: int) -> void:
		if t == 10 or t == 60: Input.action_press("jump")
		if t == 12 or t == 62: Input.action_release("jump")
		if t == 30: Input.action_press("interact")
		if t == 32: Input.action_release("interact"), 120)
	check("setup: 2 ghosts, loop 3", lm.ghost_count() == 2 and lm.loop_index == 3)

	# 타임라인 데이터
	var tl: Timeline = hud.get_node("Timeline")
	var rows: Array[Dictionary] = tl.rows()
	var g2: Ghost = lm.ghosts()[1]
	var exp_j: Array = []
	var exp_i: Array = []
	for i in g2.frames().size():
		if g2.frames()[i]["jump"]: exp_j.append(i + 1)
		if g2.frames()[i]["interact"]: exp_i.append(i + 1)
	check("timeline: one row per ghost + me", rows.size() == 3)
	check("timeline: ghost 2 row has its 2 jumps and 1 interact at recorded ticks", Array(rows[1]["jumps"]) == exp_j and Array(rows[1]["interacts"]) == exp_i and exp_j.size() == 2 and exp_i.size() == 1, "jumps=%s interacts=%s" % [rows[1]["jumps"], rows[1]["interacts"]])
	check("timeline: row colors are ghost colors", rows[0]["color"] == Ghost.COLORS[0] and rows[1]["color"] == Ghost.COLORS[1])

	# 덮어쓰기: 1번 선택 → 1번 빠진 채 루프 재시작
	await tick(30)
	var g1: Ghost = lm.ghosts()[0]
	var old_g1_last: Vector2 = g1.frames()[-1]["pos"]
	var old_g2: Array = g2.frames().duplicate(true)
	await tap_key(KEY_1)
	await tick(3)
	check("select 1: target=1, ghost 1 benched (hidden, not alive), loop restarted", lm.overwrite_target == 1 and g1.benched and not g1.alive and not g1.visible and lm.tick < 5, "tick=%d" % lm.tick)
	await frame()
	var count_text: String = (hud.get_node("CountLabel") as Label).text
	check("HUD shows overwrite selection", count_text.contains("1번 다시 찍기"), count_text)
	await tick(60)
	check("benched ghost does not press the plate", not plate.is_on)
	# 같은 번호 다시 → 취소
	await tap_key(KEY_1)
	await tick(3)
	check("select 1 again cancels", lm.overwrite_target == 0 and not g1.benched and g1.alive)
	await tap_key(KEY_1)
	await tick(2)
	var la: Array = await run_loop(func(t: int) -> void: steer_to(200.0), 90)
	check("after loop: ghost 1 replaced by new recording, ghost 2 untouched, still 2 ghosts", lm.ghost_count() == 2 and absf((g1.frames()[-1]["pos"] as Vector2).x - 200.0) < 4.0 and (old_g1_last.x > 300.0) and g2.frames() == old_g2 and not g1.benched and lm.overwrite_target == 0, "g1 last=%s" % g1.frames()[-1]["pos"])
	check("loop index advanced", lm.loop_index == 4)

	# 되돌리기: 마지막(2번) 삭제, 루프 번호 -1, 루프 재시작
	await tick(20)
	await tap_key(KEY_BACKSPACE)
	await tick(2)
	check("undo removes last ghost only", lm.ghost_count() == 1 and lm.ghosts()[0] == g1 and lm.loop_index == 3 and lm.tick < 4, "count=%d loop=%d tick=%d" % [lm.ghost_count(), lm.loop_index, lm.tick])
	check("undo removed ghost from tree", lm.ghosts_root.get_child_count() == 1)
	await tap_key(KEY_BACKSPACE)
	await tick(2)
	await tap_key(KEY_BACKSPACE)
	await tick(2)
	check("undo with no ghosts is harmless (only the real removal lowers the loop number)", lm.ghost_count() == 0 and lm.loop_index == 2, "loop=%d" % lm.loop_index)
	# 없는 번호 선택은 무시
	await tap_key(KEY_3)
	await tick(2)
	check("selecting a non-existent ghost is ignored", lm.overwrite_target == 0)
