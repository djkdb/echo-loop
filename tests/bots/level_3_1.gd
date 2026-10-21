extends "res://tests/test_base.gd"
## 3-1 릴레이: k번째 나는 앞의 구멍들을 건너(앞의 나가 버튼으로 연 문을 지나) k번째 구멍 속 시한 버튼을 계속 누른다.
## 마지막 나는 세 구멍을 건너 세 문을 지나 출구로.

const HOLES: Array = [[40.0, 100.0], [180.0, 240.0], [320.0, 380.0]]
const LANDINGS: Array = [160.0, 300.0, 450.0]


func test_level() -> String:
	return "res://levels/level_3_1.tscn"


## k개 구멍을 건넌 뒤 then(t)을 부른다.
func _cross(st: Array, k: int, t: int, then: Callable) -> void:
	if st[0] >= 2 * k:
		then.call(t)
		return
	var i: int = st[0] / 2
	# 구멍 바로 뒤의 문이 열릴 때까지(앞의 나가 버튼을 누를 때까지) 구멍 앞에서 기다린다
	if st[0] == 2 * i and not (level.get_node("Door%d" % (i + 1)) as Door).is_open:
		steer_to(HOLES[i][0] - 20.0)
		return
	hop_step(st, 2 * i, HOLES[i][0] - 20.0, LANDINGS[i])


func _presser(k: int) -> Callable:
	var st: Array = [0, 0, ""]
	var last: Array = [-1000]
	return func(t: int) -> void:
		_cross(st, k, t, func(tt: int) -> void:
			var p: Vector2 = player.global_position
			if p.y < 300.0:
				steer_to((HOLES[k][0] + HOLES[k][1]) * 0.5)
			else:
				go(0)
				# 칸 바닥에서 2.5초마다 다시 눌러 문을 계속 열어 둔다
				if tt - last[0] >= 150 and player.is_on_floor():
					Input.action_press("interact")
					last[0] = tt
				elif tt - last[0] == 3:
					Input.action_release("interact"))


func run_case() -> void:
	keep_exit = true
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	await restart()
	for k in 3:
		await record_loop(_presser(k), 330)
	var st: Array = [0, 0, ""]
	await record_loop(func(t: int) -> void:
		_cross(st, 3, t, func(_t: int) -> void: go(1)), -1, 600)
	check("3-1 solved with 3 ghosts", lm.cleared, "%s step=%d" % [player.global_position, st[0]])
	save_solution()
