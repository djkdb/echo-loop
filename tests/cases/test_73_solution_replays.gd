extends "res://tests/test_base.gd"
## 정답 리플레이를 리플레이 씬(--solution, 릴스 "정답편" 렌더)으로 재생하면 모든 루프가 겹쳐 끝까지 가고 아무도 붕괴하지 않는다.
## (마지막 "지금의 나"도 고스트로 재생되므로 그 경로가 지형·문과 모순 없는지까지 본다.)


func run_case() -> void:
	driver.set_physics_process(false)
	remove_child(main)
	main.queue_free()
	var bad: Array = []
	for s: Dictionary in Stages.LIST:
		var replay: Node2D = (load("res://game/replay.tscn") as PackedScene).instantiate()
		replay.stage_id = s["id"]
		replay.solution = true
		add_child(replay)
		var ghosts: Array = replay.ghosts
		if replay.level == null or ghosts.size() != int(s["record"]) + 1:
			bad.append("%s: not loaded" % s["id"])
		else:
			var dead: Array = []
			for g: Ghost in ghosts:
				g.collapsed.connect(func() -> void: dead.append(g.number))
			await tick(replay.loop_ticks - 2)
			if not dead.is_empty():
				bad.append("%s: collapsed %s" % [s["id"], dead])
		remove_child(replay)
		replay.queue_free()
		await tick(1)
	check("all 15 solution replays play through in the replay scene with no collapse", bad.is_empty(), str(bad))
