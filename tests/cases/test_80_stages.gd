extends "res://tests/test_base.gd"
## 스테이지 목록·별점·클리어 기록·스테이지 선택 화면(C2).


func test_level() -> String:
	return "res://levels/level_1_1.tscn"


func run_case() -> void:
	# 1) 목록이 레벨·정답과 맞는다
	var bad: Array = []
	for s: Dictionary in Stages.LIST:
		var lv: Level = (load(Stages.path(s["id"])) as PackedScene).instantiate() as Level
		var doc: Dictionary = ReplayIO.load_solution(s["id"])
		var rec: int = doc.get("runs", []).size() - 1
		if lv.max_ghosts != s["max"] or rec != s["record"] or s["record"] > s["max"]:
			bad.append("%s max=%d/%d record=%d/%d" % [s["id"], lv.max_ghosts, s["max"], rec, s["record"]])
		lv.free()
	check("stage list: 15 stages, max_ghosts and dev records match levels and solutions", Stages.LIST.size() == 15 and bad.is_empty(), str(bad))

	# 2) 별점 규칙
	check("stars: record or fewer = 3, under the cap = 2, at the cap = 1, not cleared = 0",
		Stages.stars_for(1, 1, 1) == 3 and Stages.stars_for(2, 3, 1) == 2 and Stages.stars_for(3, 3, 1) == 1
		and Stages.stars_for(2, 4, 2) == 3 and Stages.stars_for(-1, 3, 1) == 0)

	# 3) 기록: 최소만 남고, 파일로 저장·복원, 앞 스테이지를 깨면 다음이 열린다
	DirAccess.remove_absolute(TEST_PROGRESS_PATH)
	Progress.best = {}
	check("progress: only 1-1 is unlocked at first", Progress.is_unlocked("level_1_1") and not Progress.is_unlocked("level_1_2"))
	Progress.record_clear("level_2_1", 2)
	var better: bool = Progress.record_clear("level_2_1", 1)
	var worse: bool = Progress.record_clear("level_2_1", 2)
	check("progress: keeps the fewest ghosts", better and not worse and Progress.best_ghosts("level_2_1") == 1 and Progress.stars("level_2_1") == 3)
	Progress.record_clear("level_1_1", 1)
	Progress.best = {}
	Progress.load_file()
	check("progress: saved to and loaded from user:// file", Progress.best_ghosts("level_2_1") == 1 and Progress.is_cleared("level_1_1") and Progress.is_unlocked("level_1_2") and not Progress.is_unlocked("level_1_3"))
	check("progress: total stars", Progress.total_stars() == 6, str(Progress.total_stars()))

	# 4) 선택 화면: 15장, 잠긴 카드는 시작되지 않고 열린 카드는 고른다
	var sel: StageSelect = (load("res://ui/stage_select.tscn") as PackedScene).instantiate() as StageSelect
	add_child(sel)
	await frame()
	var picked: Array = []
	for card: StageCard in sel.cards:
		card.chosen.disconnect(sel.start_stage)
		card.chosen.connect(func(id: String) -> void: picked.append(id))
	check("select screen: 15 cards in 3 chapters, focus on the first uncleared stage", sel.cards.size() == 15 and sel.cards[1].has_focus(), str(sel.cards.map(func(c: StageCard) -> bool: return c.has_focus())))
	check("select screen: lock/clear/stars shown per card", sel.cards[0].cleared and sel.cards[0].stars == 3 and sel.cards[1].unlocked and not sel.cards[2].unlocked)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	sel.cards[2]._gui_input(click)
	sel.cards[1]._gui_input(click)
	check("select screen: locked card ignored, unlocked card chosen by click/tap", picked == ["level_1_2"], str(picked))
	sel.queue_free()

	# 5) 메뉴에서 들어온 게임: 그 스테이지를 열고, CLEAR하면 기록과 별점이 남는다
	driver.set_physics_process(false)
	remove_child(main)
	main.queue_free()
	Progress.best = {}
	Progress.pending_stage = "level_1_2"
	main = load("res://game/main.tscn").instantiate()
	add_child(main)
	await tick(1)
	player = main.get_node("Player")
	lm = main.get_node("LoopManager")
	hud = main.get_node("HUD")
	level = main.level
	driver.lm = lm
	driver.set_physics_process(true)
	check("game from menu opens the chosen stage", main.from_menu and main.stage_id() == "level_1_2" and hud.menu_mode)
	var doc: Dictionary = ReplayIO.load_solution("level_1_2")
	await restart()
	for i in doc["inputs"].size():
		await play_inputs(doc["inputs"][i], int(doc["end_at"][i]))
	await frame()
	await frame()
	check("CLEAR from menu records the ghosts used (1) -> 3 stars", lm.cleared and Progress.best_ghosts("level_1_2") == 1 and Progress.stars("level_1_2") == 3)
	var stars_node: StarIcons = hud._clear_stars
	check("CLEAR panel shows the stars and the next-stage hint", stars_node.count == 3 and (hud.get_node("ClearPanel/HintLabel") as Label).text.contains("E 다음"))
	Progress.pending_stage = ""
