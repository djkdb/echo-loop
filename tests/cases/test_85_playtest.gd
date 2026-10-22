extends "res://tests/test_base.gd"
## 플레이 테스트 기록(D4): 스테이지별 루프 수·되돌리기·처음부터·처음 클리어 시간·고스트·별을 user:// 에 저장,
## 타이틀의 "테스트 결과 복사"가 요약 + JSON을 만든다.


func test_level() -> String:
	return "res://levels/level_1_2.tscn"


func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	var e: Dictionary = Playtest.entry("level_1_2")
	check("stage start is logged", int(e["starts"]) == 1 and int(e["restarts"]) == 0)
	await restart()
	check("restart (Shift+R) is counted", int(e["restarts"]) == 1)
	await run_loop(func(t: int) -> void: steer_to(90.0), 40)
	lm.undo_ghost()
	await tick(2)
	check("loops and undos are counted", int(e["loops"]) >= 3 and int(e["undos"]) == 1, "%s" % e)
	await restart()
	var doc: Dictionary = ReplayIO.load_solution("level_1_2")
	for i in doc["inputs"].size():
		await play_inputs(doc["inputs"][i], int(doc["end_at"][i]))
	check("first clear stores ghosts, stars and the real time", lm.cleared and e["cleared"] and int(e["first_clear_ghosts"]) == 1 and int(e["stars"]) == 3 and float(e["first_clear_sec"]) >= 0.0, "%s" % e)
	Playtest.stages = {}
	Playtest.load_file()
	check("log is saved to user:// and loads back", Playtest.stages.has("level_1_2") and Playtest.stages["level_1_2"]["cleared"])
	var text: String = Playtest.report_text()
	var json: Variant = JSON.parse_string(text.rsplit("---", true, 1)[1])
	check("report text = readable summary + JSON", text.contains("1-2 문지기: 클리어") and json is Dictionary and (json as Dictionary)["stages"].has("level_1_2"), text.split("\n")[1])
	var title: Title = (load("res://ui/title.tscn") as PackedScene).instantiate() as Title
	add_child(title)
	await frame()
	title.copy_button.pressed.emit()
	await frame()
	check("title has the copy button and confirms the copy", title.copy_button.text == "테스트 결과 복사" and title._copied.visible)
	title.queue_free()
