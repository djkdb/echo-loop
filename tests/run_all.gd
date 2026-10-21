extends SceneTree
## 모든 자동 테스트를 차례로 실행한다. 실패가 하나라도 있으면 종료 코드 1.
##   godot --headless --path . -s tests/run_all.gd
##   (빠르게: --fixed-fps 60 을 붙이면 실시간을 기다리지 않는다)
##   하나만: ... -s tests/run_all.gd -- --only=test_loop
##   정답 리플레이 다시 만들기: ... -s tests/run_all.gd -- --dir=bots  (tests/bots/<stage>.gd → solutions/<stage>.json)

const CASE_DIR: String = "res://tests/cases/"
## 케이스 하나가 이 물리 프레임 수 안에 끝나지 않으면(스크립트 오류로 멈춤 등) 실패로 친다.
const CASE_FRAME_LIMIT: int = 30000


func _initialize() -> void:
	_run_all()


func _run_all() -> void:
	# _initialize 안에서는 아직 트리가 돌기 전이라 붙인 노드의 get_tree()가 비어 있다.
	await process_frame
	var only: String = ""
	var dir: String = CASE_DIR
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
		elif arg.begins_with("--dir="):
			dir = "res://tests/%s/" % arg.trim_prefix("--dir=")
	var files: Array = Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool: return f.ends_with(".gd"))
	files.sort()
	var total: int = 0
	var bad: Array = []
	for f: String in files:
		if only != "" and not f.begins_with(only):
			continue
		print("== ", f)
		var script: GDScript = load(dir + f) as GDScript
		if script == null or not script.can_instantiate():
			print("  FAIL could not load (parse error?)")
			total += 1
			bad.append(f)
			continue
		var case: Node = script.new()
		root.add_child(case)
		case.start()
		var frames: int = 0
		while not case.done and frames < CASE_FRAME_LIMIT:
			await physics_frame
			frames += 1
		if not case.done:
			print("  FAIL timed out (script error?)")
			case.fails += 1
		total += case.fails
		if case.fails > 0:
			bad.append(f)
		case.teardown()
		root.remove_child(case)
		case.queue_free()
		await physics_frame
		await physics_frame
	print("")
	print("FAILED CASES: ", bad if not bad.is_empty() else "none")
	print("TOTAL FAILS=", total)
	quit(1 if total > 0 else 0)
