extends "res://tests/test_base.gd"
## 이동·점프·코요테 타임·점프 버퍼·녹화(1단계). 600틱보다 오래 돌므로 LoopManager를 끈다.


func run_case() -> void:
	lm.process_mode = Node.PROCESS_MODE_DISABLED
	# [just_pressed(jump), on_floor, vy] — 플레이어가 이번 틱에 보는 값
	driver.probe = func() -> Array: return [Input.is_action_just_pressed("jump"), player.is_on_floor(), player.velocity.y]
	await tick(40)
	check("layers: player layer 2, mask 21", player.collision_layer == 2 and player.collision_mask == 21)
	check("lands on floor at spawn", player.is_on_floor() and absf(player.global_position.y - 1168.0) < 1.0, str(player.global_position))
	var n0: int = player.recording.size()
	await tick(10)
	check("recording +1 per tick with pos/flip/interact/jump", player.recording.size() == n0 + 10 and player.recording[-1].has_all(["pos", "flip", "interact", "jump"]))

	var x0: float = player.global_position.x
	driver.hook = func(t: int) -> void: Input.action_press("move_right")
	await tick(31)
	driver.hook = func(t: int) -> void: Input.action_release("move_right")
	await tick(2)
	var dx: float = player.global_position.x - x0
	check("move right: exactly 6px (360px/s) per tick", dx >= 174.0 and absf(dx / 6.0 - roundf(dx / 6.0)) < 0.01, "%.2f" % dx)

	# 바닥에서 점프: 입력이 보인 틱에 바로
	var start: int = driver.log.size()
	driver.hook = func(t: int) -> void: Input.action_press("jump")
	await tick(2)
	driver.hook = func(t: int) -> void: Input.action_release("jump")
	await tick(80)
	var s: int = _seen(start)
	check("floor jump on the tick input is seen", s >= 0 and _jumped_at(s))

	# 코요테: 스텝2(위면 y 1000)에서 왼쪽으로 걸어 내려가며 누르는 틱을 바꿔 본다
	var res: Dictionary = {}
	for p in range(5, 30):
		player.reset()
		player.global_position = Vector2(600, 967)
		driver.hook = Callable()
		await tick(10)
		start = driver.log.size()
		var pp: int = p
		# LoopManager를 꺼서 lm.tick이 안 늘므로 물리 프레임 번호로 센다
		var f0: int = Engine.get_physics_frames()
		driver.hook = func(_t: int) -> void:
			var i: int = Engine.get_physics_frames() - f0
			Input.action_press("move_left")
			if i == pp: Input.action_press("jump")
			if i == pp + 2: Input.action_release("jump")
		await tick(pp + 8)
		driver.hook = func(t: int) -> void: release_all()
		await tick(2)
		s = _seen(start)
		if s >= 0:
			var air: int = 0
			var k: int = s
			while k >= 0 and not driver.log[k][2][1]:
				air += 1
				k -= 1
			res[air] = _jumped_at(s)
		await tick(50)
	var coyote_ok: bool = res.size() > 8
	for air: int in res:
		coyote_ok = coyote_ok and (res[air] == (air <= 6))
	check("coyote: jump allowed for 6 airborne ticks (0.1s), not after", coyote_ok, str(res))

	# 버퍼: 떨어지는 중 누르는 틱을 바꿔 보고, 보인 틱과 착지 틱 차이로 판정
	var bres: Dictionary = {}
	for p in range(15, 30):
		player.reset()
		player.global_position = Vector2(120, 900)
		driver.hook = Callable()
		start = driver.log.size()
		var pp: int = p
		var f0: int = Engine.get_physics_frames()
		driver.hook = func(_t: int) -> void:
			var i: int = Engine.get_physics_frames() - f0
			if i == pp: Input.action_press("jump")
			if i == pp + 1: Input.action_release("jump")
		await tick(70)
		driver.hook = Callable()
		s = _seen(start)
		var land: int = -1
		for k in range(maxi(s, 0), driver.log.size()):
			if driver.log[k][2][1]:
				land = k
				break
		if s < 0 or land < 0:
			continue
		var j: bool = false
		for k in range(s, mini(land + 3, driver.log.size() - 1)):
			j = j or _jumped_at(k)
		bres[land - s] = j
		await tick(10)
	var buf_ok: bool = bres.size() > 6
	for d: int in bres:
		if d <= 8:
			buf_ok = buf_ok and (bres[d] == (d <= 5))
	check("jump buffer: press up to 5 ticks before landing (6 ticks = 0.1s) jumps on landing", buf_ok, str(bres))

	# reset: 녹화 비움, 스폰 복귀, 정지
	player.global_position = Vector2(400, 500)
	player.velocity = Vector2(100, 100)
	player.reset()
	check("reset: recording cleared, at spawn, velocity zero", player.recording.is_empty() and player.global_position == player.spawn_point.global_position and player.velocity == Vector2.ZERO)


func _seen(from: int) -> int:
	for t in range(from, driver.log.size()):
		if driver.log[t][2][0]:
			return t
	return -1


func _jumped_at(t: int) -> bool:
	return t + 1 < driver.log.size() and driver.log[t][2][2] >= 0.0 and driver.log[t + 1][2][2] < 0.0
