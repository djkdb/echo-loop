extends "res://tests/test_base.gd"
## 짓눌린 Player = 루프 실패(D3). 2-2에서 아직 공중인 2번이 탑 위로 오르던 나를 덮쳐 짓누르면 루프가 실패하고
## (고스트로 남지 않음, 루프 번호 그대로), 고스트 점프에 올라타는 정상 운반은 실패가 아니다.


func test_level() -> String:
	return "res://levels/level_2_2.tscn"


func run_case() -> void:
	await restart()
	await run_loop(func(t: int) -> void: steer_to(278.0), 60)
	var s2: Array = [0, 0, ""]
	await run_loop(func(t: int) -> void:
		if t < 20: return
		go(1 if player.global_position.x < 272.0 else 0)
		tap_step(s2, 0, player.global_position.x >= 200.0), 110)
	var n_fail: int = failed.size()
	var n_end: int = ended.size()
	var loop_before: int = lm.loop_index
	var st: Array = [0, 0, ""]
	await run_loop(func(t: int) -> void:
		if t < 40: return
		steer_to(278.0)
		tap_step(st, 0, player.global_position.x >= 180.0), -1, 300)
	check("player crushed under a landing ghost fails the loop", failed.size() == n_fail + 1 and ended.size() == n_end, "failed %d->%d" % [n_fail, failed.size()])
	check("crushed loop leaves no ghost and keeps the loop number", lm.ghost_count() == 2 and lm.loop_index == loop_before)

	# 정상: 고스트 점프에 올라타 함께 오르내림(1틱 지연 파고듦 최대 15px)은 실패가 아니다
	main.load_level(load("res://levels/level_test.tscn"))
	level = main.level
	await restart()
	await run_loop(func(t: int) -> void:
		if t == 130: Input.action_press("jump")
		if t == 132: Input.action_release("jump"), 300)
	var n2: int = failed.size()
	await run_loop(func(t: int) -> void:
		if t == 5: Input.action_press("jump")
		if t == 8: Input.action_release("jump"), 260)
	check("riding a hopping ghost is not a crush", failed.size() == n2)
	# 스폰에서 고스트와 겹친 채 시작해도 실패가 아니다(통과 처리 중)
	var n3: int = failed.size()
	await run_loop(Callable(), 120)
	check("starting inside ghosts at the spawn is not a crush", failed.size() == n3)
