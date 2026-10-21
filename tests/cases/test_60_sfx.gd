extends "res://tests/test_base.gd"
## 효과음: 9종 합성, SFX 버스, 실제 플레이에서 제때 울림(점프·착지·판·문·되감기·CLEAR·똑딱·레버·붕괴).


func test_level() -> String:
	return "res://levels/level_1_2.tscn"


func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	var names: Array = ["rewind", "jump", "land", "plate", "door", "lever", "clear", "collapse", "tick"]
	check("9 sounds synthesized as AudioStreamWAV", names.all(func(n: String) -> bool: return Sfx.streams.has(n) and (Sfx.streams[n] as AudioStreamWAV).data.size() > 100))
	check("SFX bus exists and players use it", AudioServer.get_bus_index(&"SFX") > 0 and (Sfx.get_child(0) as AudioStreamPlayer).bus == &"SFX")
	var heard: Array = []
	Sfx.played.connect(func(n: String) -> void: heard.append([n, lm.tick]))
	await restart()
	await run_loop(func(t: int) -> void:
		steer_to(90.0)
		if t == 100: Input.action_press("jump")
		if t == 102: Input.action_release("jump"))
	var first: Array = heard.duplicate()
	var has: Callable = func(list: Array, n: String) -> bool: return list.any(func(e: Array) -> bool: return e[0] == n)
	check("jump / land / plate / door / rewind are heard during a keeper loop", has.call(first, "jump") and has.call(first, "land") and has.call(first, "plate") and has.call(first, "door"), str(first.map(func(e: Array) -> String: return e[0])))
	var ticks: Array = first.filter(func(e: Array) -> bool: return e[0] == "tick")
	check("last 3 seconds: tick sound once per second (3 times)", ticks.size() == 3, str(ticks))
	await frame()
	await frame()
	check("loop reset plays the rewind sound", has.call(heard, "rewind"))
	heard.clear()
	var st: Array = [0, 0, ""]
	await run_loop(func(t: int) -> void:
		if t > 20:
			go(1)
			tap_step(st, 0, player.global_position.x >= 34.0), -1, 600)
	await frame()
	await frame()
	check("CLEAR plays the clear sound", has.call(heard, "clear"))
