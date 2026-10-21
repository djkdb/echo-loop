extends "res://tests/test_base.gd"
## 움직이는 고스트 위에 선 Player가 같이 움직이고 떨어지지 않는다(3단계 핵심 조건).


func run_case() -> void:
	# 녹화: 120틱 쉬었다가 오른쪽으로 걸음
	await restart()
	await run_loop(func(t: int) -> void:
		if t >= 120 and t < 180: Input.action_press("move_right")
		else: Input.action_release("move_right"))
	var g: Ghost = lm.ghosts()[0]
	# 재생: 스폰에서 겹친 채 제자리 점프로 머리 위에 올라탐
	var info: Array = [0.0, 0.0, true]
	await run_loop(func(t: int) -> void:
		if t == 5: Input.action_press("jump")
		if t == 8: Input.action_release("jump")
		if t == 100: info[0] = player.global_position.x - g.global_position.x
		if t > 100 and t < 260:
			info[1] = maxf(info[1], absf((player.global_position.x - g.global_position.x) - info[0]))
			info[2] = info[2] and player.is_on_floor(), 262)
	check("horizontal carry: stays on ghost head every tick", info[2])
	check("horizontal carry: offset drift <= one tick of motion (6px)", info[1] <= 6.01, "drift=%.2f" % info[1])
	# 고스트 점프에 실려 올라가기
	await restart()
	await run_loop(func(t: int) -> void:
		if t == 130: Input.action_press("jump")
		if t == 132: Input.action_release("jump"), 300)
	g = lm.ghosts()[0]
	var rise: Array = [0.0, 0.0]
	await run_loop(func(t: int) -> void:
		if t == 5: Input.action_press("jump")
		if t == 8: Input.action_release("jump")
		if t == 100: rise[0] = player.global_position.y
		if t > 100: rise[1] = maxf(rise[1], rise[0] - player.global_position.y), 260)
	await tick(1)
	check("vertical carry: player lifted with the ghost's jump and back on its head", rise[1] > 150.0, "rise=%.1f" % rise[1])

	# 움직이는 고스트 위에서는 점프 불가(슈퍼 점프·올라타기 부스트 방지), 고스트가 서 있으면 보통 점프
	for case: Array in [[131, "while the ghost rises"], [153, "at the ghost's apex"], [165, "while the ghost falls"]]:
		await restart()
		await run_loop(func(t: int) -> void:
			if t == 130: Input.action_press("jump")
			if t == 132: Input.action_release("jump"), 300)
		var hop: Array = [0.0, 1e9, false]
		await run_loop(func(t: int) -> void:
			if t == 5: Input.action_press("jump")
			if t == 8: Input.action_release("jump")
			if t == 100: hop[0] = player.global_position.y
			if t == case[0]: Input.action_press("jump")
			if t == case[0] + 3: Input.action_release("jump")
			hop[1] = minf(hop[1], player.global_position.y), 260)
		check("no jump off a moving ghost (%s): rise stays at the ghost's own hop" % case[1], hop[0] - hop[1] < 180.0, "rise=%.1f" % (hop[0] - hop[1]))
	await restart()
	await run_loop(func(t: int) -> void:
		if t == 130: Input.action_press("jump")
		if t == 132: Input.action_release("jump"), 300)
	var still: Array = [0.0, 1e9]
	await run_loop(func(t: int) -> void:
		if t == 5: Input.action_press("jump")
		if t == 8: Input.action_release("jump")
		if t == 80: still[0] = player.global_position.y
		if t == 85: Input.action_press("jump")
		if t == 88: Input.action_release("jump")
		if t < 125: still[1] = minf(still[1], player.global_position.y), 260)
	check("standing ghost is a normal jump platform", still[0] - still[1] > 170.0, "rise=%.1f" % (still[0] - still[1]))
