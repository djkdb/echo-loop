extends "res://tests/test_base.gd"
## 릴스 제작 도구(D5): F10(debug_collapse) 강제 붕괴, 리플레이 --trim/--seamless/--text, 긴 릴스 문구 자동 축소,
## 문제편 렌더 씬(방 보여 주기 → 고스트 없이 실패 → "정답은 다음 릴스", 고스트가 남지 않음).


func test_level() -> String:
	return "res://levels/level_1_2.tscn"


func run_case() -> void:
	# F10: 가장 최근 고스트 붕괴(디버그 빌드)
	await restart()
	await run_loop(func(t: int) -> void: steer_to(90.0), 40)
	await run_loop(func(t: int) -> void: steer_to(40.0), 40)
	collapses.clear()
	key(KEY_F10, true)
	await tick(3)
	key(KEY_F10, false)
	check("F10 collapses the latest ghost (debug build)", OS.is_debug_build() and collapses.size() == 1 and collapses[0][0] == lm.ghost_count() and not lm.ghosts()[-1].alive, str(collapses))
	# 긴 문구는 한 줄에 맞게 줄어든다
	var reels: ReelsMode = main.get_node("ReelsMode")
	reels.text = "혼자서는 못 올라가는 턱, 어떻게 넘을까? 정말 어렵다"
	reels.set_active(true)
	await frame()
	var lab: Label = reels._label
	var w: float = lab.get_theme_font("font").get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lab.get_theme_font_size("font_size")).x
	check("long reels text shrinks to fit the 720px slot", w <= 720.0 - 32.0 + 0.5 and lab.get_theme_font_size("font_size") < 50, "w=%.0f size=%d" % [w, lab.get_theme_font_size("font_size")])
	reels.set_active(false)

	driver.set_physics_process(false)
	remove_child(main)
	main.queue_free()
	# 리플레이 --trim/--text: 마지막 녹화 + 0.75초에서 루프가 끝난다
	var replay: Node2D = (load("res://game/replay.tscn") as PackedScene).instantiate()
	replay.stage_id = "level_2_2"
	replay.solution = true
	replay.trim = true
	replay.seamless = true
	replay.text = "과거의 나 둘을 쌓아 탈출"
	replay.reels = true
	add_child(replay)
	var doc: Dictionary = ReplayIO.load_solution("level_2_2")
	var last: int = (doc["runs"][-1] as Array).size()
	check("replay --trim ends the loop 45 ticks after the last run", replay.loop_ticks == mini(480, last + 45), "%d vs %d" % [replay.loop_ticks, last + 45])
	check("replay --text sets the reels line", (replay.get_node("ReelsMode")._label as Label).text == "과거의 나 둘을 쌓아 탈출")
	replay.queue_free()
	await tick(1)
	# 문제편 씬: 보여 주기 → 실패 → 다음 릴스 문구, 고스트 0명
	var prob: Node = (load("res://tools/reels_problem.tscn") as PackedScene).instantiate()
	prob.stage_id = "level_1_2"
	add_child(prob)
	await tick(10)
	var showing: bool = prob._phase == "show" and prob._main.process_mode == Node.PROCESS_MODE_DISABLED
	var guard: int = 0
	while prob._phase != "next" and guard < 1200:
		await tick(1)
		guard += 1
	var lm2: LoopManager = prob._main.get_node("LoopManager")
	check("problem reel: shows the room, fails the first loop without ghosts, then the 'next reel' line", showing and prob._phase == "next" and lm2.ghost_count() == 0 and not lm2.cleared and prob._next_label.visible, "phase=%s ghosts=%d" % [prob._phase, lm2.ghost_count()])
	Progress.path = TEST_PROGRESS_PATH
	Playtest.path = "user://test_playtest.json"
	remove_child(prob)
	prob.free()
