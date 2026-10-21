extends "res://tests/test_base.gd"
## 타이틀 화면(C3): 로고·설명·조작 안내, 과거의 나 4명이 같은 길을 늦게 따라 뛰는 연출, 시작 씬 설정.


func run_case() -> void:
	var title: Title = (load("res://ui/title.tscn") as PackedScene).instantiate() as Title
	add_child(title)
	await frame()
	var a: Array = title._runners.map(func(v: CharacterVisual) -> Vector2: return v.position)
	for i in 30:
		await frame()
	var b: Array = title._runners.map(func(v: CharacterVisual) -> Vector2: return v.position)
	check("title: me + 4 ghosts run the same path, each a little later", title._runners.size() == 5 and a != b and (b[0] as Vector2) != (b[4] as Vector2))
	var texts: Array = title.get_children().filter(func(n: Node) -> bool: return n is Label).map(func(l: Label) -> String: return l.text)
	check("title: one-line pitch, the 7 controls and the start prompt", texts.has("10초 전의 나와 손잡고 방을 탈출하는 퍼즐") and texts.has("ENTER / TAP") and title.CONTROLS.size() == 7, str(texts.size()))
	check("project starts on the title screen", ProjectSettings.get_setting("application/run/main_scene") == ResourceUID.path_to_uid("res://ui/title.tscn") or ProjectSettings.get_setting("application/run/main_scene") == "res://ui/title.tscn", str(ProjectSettings.get_setting("application/run/main_scene")))
	title.queue_free()
