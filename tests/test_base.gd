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


func start() -> void:
	release_all()
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
