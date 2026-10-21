extends "res://tests/test_base.gd"
## 모든 스테이지가 게임 시작(Main 생성) 직후 저절로 CLEAR·실패되지 않는다.
## (Player가 씬 원점에 있는 채로 물리 서버에 들어가 원점 근처 출구에 낡은 겹침이 생겼던 회귀)


func run_case() -> void:
	driver.set_physics_process(false)
	remove_child(main)
	main.queue_free()
	var files: Array = Array(DirAccess.get_files_at("res://levels/")).filter(func(f: String) -> bool: return f.begins_with("level_") and f.ends_with(".tscn") and not f.begins_with("level_test"))
	files.sort()
	var bad: Array = []
	for f: String in files:
		var m: Node = load("res://game/main.tscn").instantiate()
		m.level_scene = load("res://levels/" + f)
		add_child(m)
		var lm2: LoopManager = m.get_node("LoopManager")
		var fails_before: Array = [0]
		lm2.loop_failed.connect(func() -> void: fails_before[0] += 1)
		await tick(8)
		if lm2.cleared or fails_before[0] > 0 or lm2.tick < 5:
			bad.append(f)
		remove_child(m)
		m.queue_free()
		await tick(1)
	check("%d stages start cleanly (no CLEAR/fail in the first ticks)" % files.size(), bad.is_empty() and files.size() >= 5, str(bad))
