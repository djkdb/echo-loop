extends "res://tests/test_base.gd"
## 리플레이 2배속(phase-e): 틱 수 ×2 + time_scale ×2라 틱당 delta가 같아 1배속과 매 틱 같은 결과
## (발판·상자 위치, 문·판·버튼·레버 상태, 고스트 위치)가 나오고, 리플레이를 닫으면 틱 60/초로 돌아온다.
## CLEAR 패널의 "리플레이 ×2" 버튼은 메뉴에서 들어온 게임에서만 보인다.


func _snapshot(replay: Node2D) -> Array:
	var out: Array = []
	for n: Node in replay.level.find_children("*", "", true, false):
		if n is MovingPlatform or n is Box:
			out.append((n as Node2D).global_position.snapped(Vector2(0.001, 0.001)))
		elif n is Door:
			out.append((n as Door).is_open)
		elif n is PressurePlate or n is Lever or n is TimedButton:
			out.append(n.get("is_on"))
	for g: Ghost in replay.ghosts:
		out.append([g.alive, g.global_position.snapped(Vector2(0.001, 0.001))])
	return out


func _run(stage: String, speed: int) -> Array:
	var replay: Node2D = (load("res://game/replay.tscn") as PackedScene).instantiate()
	replay.stage_id = stage
	replay.solution = true
	replay.speed = speed
	add_child(replay)
	var frames: Array = []
	for i in replay.loop_ticks - 2:
		await tick(1)
		frames.append(_snapshot(replay))
	remove_child(replay)
	replay.queue_free()
	await tick(1)
	return frames


func run_case() -> void:
	check("replay button hidden when the game was not opened from the menu", not hud.replay_button.visible)
	driver.set_physics_process(false)
	remove_child(main)
	main.queue_free()
	var bad: Array = []
	for s: Dictionary in Stages.LIST:
		var a: Array = await _run(s["id"], 1)
		var b: Array = await _run(s["id"], 2)
		if a != b or a.is_empty():
			var at: int = -1
			for i in mini(a.size(), b.size()):
				if a[i] != b[i]:
					at = i
					break
			bad.append("%s first diff tick %d" % [s["id"], at])
	check("2x replay = 1x replay on every tick for all 15 solutions", bad.is_empty(), str(bad))
	check("closing the replay restores 60 ticks/s and time_scale 1", Engine.physics_ticks_per_second == 60 and is_equal_approx(Engine.time_scale, 1.0))
