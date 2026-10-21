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
