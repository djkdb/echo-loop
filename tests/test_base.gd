extends Node
## 자동 테스트 공용 하네스. 테스트 케이스는 이 스크립트를 상속하고 run_case()를 구현한다.
## 필요하면 test_level()로 레벨을 고른다(기본 levels/level_test.tscn).
##
## 입력 타이밍: 드라이버(process_physics_priority -100)가 매 틱 맨 먼저 hook을 부른다.
## hook 안에서 Input.action_press 한 입력은 엔진 규칙상 "다음 틱"에 just_pressed로 보인다.

var main: Node
var player: Player
var lm: LoopManager
var hud: Hud
var level: Level
var driver: Node
var fails: int = 0
var done: bool = false
var ended: Array = []      # loop_ended 발생 물리 프레임
var failed: Array = []     # loop_failed 발생 물리 프레임
var collapses: Array = []  # [ghost number, lm.tick]
var keep_exit: bool = false

const DRIVER_SRC := """
extends Node
var lm: Node
var hook: Callable
var probe: Callable
var log: Array = []
func _physics_process(_d: float) -> void:
	if hook.is_valid():
		hook.call(lm.tick)
	log.append([Engine.get_physics_frames(), lm.tick, probe.call() if probe.is_valid() else null])
"""


## 레벨 경로. 케이스가 덮어쓴다.
func test_level() -> String:
	return "res://levels/level_test.tscn"


## 케이스 본문. 케이스가 덮어쓴다.
func run_case() -> void:
	pass


## 테스트가 실제 클리어 기록(user://progress.json)을 건드리지 않게 쓰는 파일.
const TEST_PROGRESS_PATH: String = "user://test_progress.json"


func start() -> void:
	release_all()
	Progress.path = TEST_PROGRESS_PATH
	Progress.best = {}
	Progress.flags = {}
	Progress.pending_stage = ""
	Playtest.path = "user://test_playtest.json"
	Playtest.stages = {}
	main = load("res://game/main.tscn").instantiate()
	main.level_scene = load(test_level())
	add_child(main)
	await tick(1)
	player = main.get_node("Player")
	lm = main.get_node("LoopManager")
	hud = main.get_node("HUD")
	level = main.level
	if not keep_exit and level.exit != null:
		level.exit.process_mode = Node.PROCESS_MODE_DISABLED
	var gs := GDScript.new()
	gs.source_code = DRIVER_SRC
	gs.reload()
	driver = Node.new()
	driver.set_script(gs)
	driver.process_physics_priority = -100
	driver.lm = lm
	add_child(driver)
	lm.loop_ended.connect(_on_loop_ended)
	lm.loop_failed.connect(func() -> void: failed.append(Engine.get_physics_frames()))
	await run_case()
	release_all()
	done = true


func _on_loop_ended(_i: int) -> void:
	ended.append(Engine.get_physics_frames())
	for g: Ghost in lm.ghosts():
		watch_ghost(g)


func watch_ghost(g: Ghost) -> void:
	if not g.has_meta("watched"):
		g.set_meta("watched", true)
		g.collapsed.connect(func() -> void: collapses.append([g.number, lm.tick]))


func check(label: String, ok: bool, info: String = "") -> void:
	print(("  PASS " if ok else "  FAIL ") + label + ("  " + info if info != "" else ""))
	if not ok:
		fails += 1


func tick(n: int = 1) -> void:
	for i in n:
		await get_tree().physics_frame


func frame() -> void:
	await get_tree().process_frame


func release_all() -> void:
	for a in ["move_left", "move_right", "jump", "interact"]:
		Input.action_release(a)


func key(code: Key, pressed: bool, shift: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = pressed
	ev.shift_pressed = shift
	Input.parse_input_event(ev)


func tap_key(code: Key, shift: bool = false) -> void:
	key(code, true, shift)
	await tick(2)
	key(code, false, shift)


## 틱 시작(노드 처리 전)에 다시 시작 → 이번 틱이 새 루프의 lm.tick 0
func restart() -> void:
	release_all()
	lm.restart_stage()


## 한 루프 진행. on_tick(t)은 매 틱 드라이버 차례에 불린다. end_at >= 0 이면 그 틱에 R을 누른다.
## 루프가 끝나거나(종료·실패) CLEAR되면 그 루프의 드라이버 로그를 돌려준다.
func run_loop(on_tick: Callable = Callable(), end_at: int = -1, max_ticks: int = 2000) -> Array:
	var start_i: int = driver.log.size()
	var n_end: int = ended.size()
	var n_fail: int = failed.size()
	var pressed_r: Array = [false]
	driver.hook = func(t: int) -> void:
		if on_tick.is_valid():
			on_tick.call(t)
		if end_at >= 0 and t >= end_at and not pressed_r[0]:
			key(KEY_R, true)
			pressed_r[0] = true
	var guard: int = 0
	while ended.size() == n_end and failed.size() == n_fail and not lm.cleared and guard < max_ticks:
		await tick(1)
		guard += 1
	driver.hook = Callable()
	release_all()
	key(KEY_R, false)
	return driver.log.slice(start_i)


## x 좌표로 걸어가 멈추는 입력(on_tick 안에서 매 틱 호출).
func steer_to(x: float) -> void:
	var px: float = player.global_position.x
	if px < x - 3.0:
		Input.action_press("move_right"); Input.action_release("move_left")
	elif px > x + 3.0:
		Input.action_press("move_left"); Input.action_release("move_right")
	else:
		Input.action_release("move_right"); Input.action_release("move_left")


func add_obj(path: String, pos: Vector2, props: Dictionary = {}) -> Node:
	var n: Node = load(path).instantiate()
	for k in props:
		n.set(k, props[k])
	n.position = pos
	level.add_child(n)
	return n


func add_wall(rect: Rect2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	wall.add_child(cs)
	wall.position = rect.get_center()
	level.add_child(wall)
	return wall


func remove(n: Node) -> void:
	n.get_parent().remove_child(n)
	n.free()


## 녹화 프레임 중 pred(pos)가 처음 참인 인덱스.
func first_frame(frames: Array, pred: Callable) -> int:
	for i in frames.size():
		if pred.call(frames[i]["pos"]):
			return i
	return -1


## 고스트가 x_left 면에 0.5px 넘게 파고드는 첫 프레임(오른쪽으로 걸어갈 때 막히는 틱 = 붕괴 틱).
func blocked_frame(frames: Array, x_left: float) -> int:
	return first_frame(frames, func(p: Vector2) -> bool: return p.x + 20.0 > x_left - 0.08 + Ghost.BLOCK_TOLERANCE)


func teardown() -> void:
	release_all()
	key(KEY_R, false)
	key(KEY_SHIFT, false)


# --- 정답 리플레이(tests/bots/*.gd → solutions/<stage>.json, tests/solution_case.gd가 검증) ---

const INPUT_ACTIONS: Array[String] = ["move_left", "move_right", "jump", "interact"]
var sol_inputs: Array = []
var sol_end_at: Array = []
var sol_runs: Array = []
## 봇 디버깅: 환경 변수 BOT_TRACE=1이면 record_loop가 6틱마다 위치를 찍는다.
var _trace: bool = OS.get_environment("BOT_TRACE") != ""


## 지금 눌린 입력을 한 글자(16진수 비트: 1 왼쪽, 2 오른쪽, 4 점프, 8 상호작용)로.
func input_code() -> String:
	var bits: int = 0
	for i in INPUT_ACTIONS.size():
		if Input.is_action_pressed(INPUT_ACTIONS[i]):
			bits |= 1 << i
	return "%x" % bits


func apply_code(code: String) -> void:
	var bits: int = code.hex_to_int()
	for i in INPUT_ACTIONS.size():
		if bits & (1 << i):
			Input.action_press(INPUT_ACTIONS[i])
		else:
			Input.action_release(INPUT_ACTIONS[i])


## run_loop와 같고, 매 틱 hook이 정한 입력을 기록해 둔다(봇 전용). 첫 틱(t = 0)에는 입력하지 않는다. 루프가 고스트가 됐으면 그 녹화, CLEAR면 지금의 나 녹화를 남긴다.
func record_loop(on_tick: Callable, end_at: int = -1, max_ticks: int = 2000) -> Array:
	var codes: PackedStringArray = []
	var n_ghosts: int = lm.ghost_count()
	var log: Array = await run_loop(func(t: int) -> void:
		# 첫 틱엔 모두 뗀다: 리셋 순간 누르고 있던 키는 한 번 뗄 때까지 무시되므로(Player 규칙)
		# 앞 루프 끝에 누르던 키를 그대로 누르면 이번 루프 내내 안 먹는다.
		if t == 0:
			release_all()
		elif on_tick.is_valid():
			on_tick.call(t)
		if _trace and t % 6 == 0:
			print("    t=%d loop=%d p=%s floor=%s in=%s" % [t, lm.loop_index, player.global_position, player.is_on_floor(), input_code()])
		codes.append(input_code()), end_at, max_ticks)
	sol_inputs.append("".join(codes))
	sol_end_at.append(end_at)
	if lm.cleared:
		sol_runs.append(player.recording.duplicate(true))
	elif lm.ghost_count() > n_ghosts:
		sol_runs.append(lm.ghosts()[-1].frames().duplicate(true))
	return log


## 저장된 입력 한 루프를 그대로 재생한다.
func play_inputs(codes: String, end_at: int, max_ticks: int = 2000) -> Array:
	return await run_loop(func(t: int) -> void:
		apply_code(codes[t] if t < codes.length() else "0"), end_at, max_ticks)


func save_solution() -> void:
	var stage: String = main.stage_id()
	var runs: Array = ReplayIO.encode_runs(sol_runs)
	# 소수 셋째 자리면 붕괴 판정 허용 오차(0.5px)보다 훨씬 정밀하고 파일은 절반쯤 된다.
	for arr: Array in runs:
		for v: Array in arr:
			v[0] = snappedf(v[0], 0.001)
			v[1] = snappedf(v[1], 0.001)
	var doc: Dictionary = {"version": ReplayIO.VERSION, "stage": stage, "level": level.scene_file_path,
		"loop_seconds": level.loop_seconds, "ghosts": sol_runs.size() - 1, "runs": runs,
		"inputs": sol_inputs, "end_at": sol_end_at}
	var path: String = ProjectSettings.globalize_path(ReplayIO.solution_path(stage))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(doc, "", false, true) + "\n")
	file.close()
	print("  saved %s (%d ghosts)" % [ReplayIO.solution_path(stage), sol_runs.size() - 1])


## 녹화를 고스트로 바로 넣는다(정답에서 고스트 하나를 뺀 구성 검증용). restart() 직후에 부른다.
func inject_ghosts(runs: Array) -> void:
	for frames: Array in runs:
		var g: Ghost = lm.ghost_scene.instantiate() as Ghost
		var copy: Array[Dictionary] = []
		copy.assign(frames.duplicate(true))
		g.setup(copy, lm.ghost_count() + 1)
		lm.ghosts_root.add_child(g)
		lm.ghosts().append(g)
	lm.call("_reset_all")


## 봇용 단계 진행: st = [단계, 누르고 있는 남은 틱]. 단계가 step이고 cond면 action을 3틱 누르고 다음 단계로.
## (hook에서 누른 입력은 다음 틱에 just_pressed로 보이므로 바로 떼지 않는다.)
func tap_step(st: Array, step: int, cond: bool, action: String = "jump") -> void:
	if st[1] > 0:
		st[1] -= 1
		if st[1] == 0:
			Input.action_release(st[2])
		return
	if st[0] == step and cond:
		Input.action_press(action)
		st[1] = 3
		if st.size() < 3:
			st.append(action)
		st[2] = action
		st[0] = step + 1


## 봇용: 왼쪽(-1)·정지(0)·오른쪽(1) 중 하나만 누른다.
func go(d: int) -> void:
	if d > 0:
		Input.action_press("move_right"); Input.action_release("move_left")
	elif d < 0:
		Input.action_press("move_left"); Input.action_release("move_right")
	else:
		Input.action_release("move_right"); Input.action_release("move_left")


## 봇용 구멍 건너기: step 단계에서 from_x까지 가서 뛰고, step+1 단계에서 to_x로 날아가 내려앉으면 step+2로.
func hop_step(st: Array, step: int, from_x: float, to_x: float) -> void:
	var p: Vector2 = player.global_position
	if st[0] == step:
		steer_to(from_x)
		tap_step(st, step, absf(p.x - from_x) < 4.0 and player.is_on_floor())
	elif st[0] == step + 1:
		steer_to(to_x)
		tap_step(st, -1, false)
		if st[1] == 0 and player.is_on_floor() and absf(p.x - to_x) < 4.0:
			st[0] = step + 2
