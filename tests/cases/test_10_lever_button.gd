extends "res://tests/test_base.gd"
## 레버·시한 버튼·반전 문·interact 재생(A1)

var lever: Lever
var button: TimedButton
var door: Door

func seq(log: Array, idx: int) -> Array:
	# probe 값 idx 번째가 바뀌는 [lm.tick, 값] 목록
	var out: Array = []
	var prev: Variant = null
	for e in log:
		var v: Variant = e[2][idx]
		if v != prev:
			out.append([e[1], v])
			prev = v
	return out

func run_case() -> void:
	lever = add_obj("res://objects/lever.tscn", Vector2(170, 1200))
	var srcs: Array[NodePath] = [NodePath("../Lever")]
	door = add_obj("res://objects/door.tscn", Vector2(260, 1120), {"sources": srcs, "inverted": true})
	button = add_obj("res://objects/timed_button.tscn", Vector2(340, 1200))
	driver.probe = func() -> Array: return [lever.is_on, button.is_on, door.is_open, button.ticks_left]
	await tick(2)
	check("inverted door starts open, lever/button off", door.is_open and not lever.is_on and not button.is_on)

	# ---- A) 레버: 루프 끝까지 유지, 재생 시 같은 틱 / jump 기록
	await restart()
	var la: Array = await run_loop(func(t: int) -> void:
		steer_to(170.0)
		if t == 12: Input.action_press("interact")
		if t == 14: Input.action_release("interact")
		if t == 30: Input.action_press("jump")
		if t == 32: Input.action_release("jump"), 120)
	var lv_rec: Array = seq(la, 0)
	check("A) lever turns on once and stays on until loop end", lv_rec.size() == 2 and lv_rec[1][1] == true, str(lv_rec))
	check("A) inverted door closes after lever on", seq(la, 2).size() == 2 and seq(la, 2)[1][1] == false, str(seq(la, 2)))
	var g1: Ghost = lm._ghosts[0]
	var jumps: int = g1._frames.filter(func(f: Dictionary) -> bool: return f["jump"]).size()
	check("A) recording marks exactly one jump tick", jumps == 1, "jumps=%d" % jumps)
	var lb: Array = await run_loop(Callable(), 120)
	check("A) after reset: lever off, door open at loop start", lb[1][2][0] == false and lb[1][2][2] == true, str(lb[1][2]))
	check("A) ghost pulls lever on the same tick as recording", seq(lb, 0) == lv_rec, "rec=%s replay=%s" % [lv_rec, seq(lb, 0)])

	# ---- B) 시한 버튼 180틱, 다시 누르면 처음부터
	await restart()
	var ba: Array = await run_loop(func(t: int) -> void:
		steer_to(340.0)
		if t == 40 or t == 100: Input.action_press("interact")
		if t == 42 or t == 102: Input.action_release("interact"), 400)
	var bs: Array = seq(ba, 1)
	check("B) button on at first press, re-press extends: on for (2nd press - 1st press) + 180 ticks", bs.size() == 3 and bs[2][0] - bs[1][0] == (100 - 40) + 180, str(bs))
	var bb: Array = await run_loop(Callable(), 400)
	check("B) ghost replays button with identical on/off ticks", seq(bb, 1) == bs, "rec=%s replay=%s" % [bs, seq(bb, 1)])

	# ---- C) 녹화 마지막 틱의 interact를 멈춘 고스트가 반복하지 않음
	await restart()
	var ca: Array = await run_loop(func(t: int) -> void:
		steer_to(340.0)
		if t == 40:
			Input.action_press("interact")
			key(KEY_R, true), -1)
	var g: Ghost = lm._ghosts[0]
	check("C) precondition: last frame has interact", g._frames[-1]["interact"], "len=%d" % g._frames.size())
	var cb: Array = await run_loop(Callable(), 400)
	var cs: Array = seq(cb, 1)
	check("C) frozen ghost presses only once: button on exactly 180 ticks then off", cs.size() == 3 and cs[2][0] - cs[1][0] == 180 and cs[2][1] == false, str(cs))

	# ---- D) 반전 문 + 레버 → 패러독스
	await restart()
	await run_loop(func(t: int) -> void: steer_to(340.0), 80)   # 열린 문을 지나간 녹화
	g = lm._ghosts[0]
	var hit: int = -1
	for i in g._frames.size():
		if (g._frames[i]["pos"] as Vector2).x + 20.0 > 240.0 - 0.08 + 0.5:
			hit = i
			break
	collapses.clear()
	var da: Array = await run_loop(func(t: int) -> void:
		steer_to(170.0)
		if t == 2: Input.action_press("interact")
		if t == 4: Input.action_release("interact"), 120)
	check("D) lever pulled by present-me closes inverted door before ghost arrives", seq(da, 2).size() >= 2 and seq(da, 2)[1][0] < hit, str(seq(da, 2)))
	check("D) ghost collapses exactly on the tick it touches the closed door (paradox)", collapses.size() == 1 and collapses[0][1] == hit, "collapses=%s expected tick %d" % [collapses, hit])
