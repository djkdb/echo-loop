extends "res://tests/test_base.gd"
## 정답 리플레이 검증(챕터별 케이스가 상속해 stages()를 정한다). solutions/<stage>.json마다:
## 1) 저장된 입력을 실제 게임에 넣으면 같은 녹화가 나오고 CLEAR된다(= 클리어 가능, 레벨을 고쳐 답이 깨지면 여기서 걸린다).
## 2) 고스트 수 ≤ 레벨 상한.
## 3) 정답에서 루프 하나를 빼고 나머지 입력을 그대로 재생하면 CLEAR되지 않는다
##    (= 이 답에서 고스트 하나라도 적으면 안 된다). 전역 최소임은 레벨 설계 근거로 보장한다(docs/levels.md).

const POS_TOLERANCE: float = 0.01


func stages() -> Array[String]:
	return []


func test_level() -> String:
	return "res://levels/%s.tscn" % stages()[0]


func run_case() -> void:
	keep_exit = true
	for stage: String in stages():
		await _verify(stage)


func _verify(stage: String) -> void:
	var doc: Dictionary = ReplayIO.load_solution(stage)
	if doc.is_empty():
		check("%s: solution file exists" % stage, false, ReplayIO.solution_path(stage))
		return
	if main.stage_id() != stage:
		main.load_level(load(doc["level"]))
		level = main.level
	level.exit.process_mode = Node.PROCESS_MODE_INHERIT
	var runs: Array = doc["runs"]
	var inputs: Array = doc["inputs"]
	var n: int = runs.size() - 1
	check("%s: %d ghosts within the cap (%d)" % [stage, n, lm.max_ghosts], n <= lm.max_ghosts and inputs.size() == runs.size())
	await restart()
	var same: bool = true
	for i in inputs.size():
		await play_inputs(inputs[i], int(doc["end_at"][i]))
		var got: Array = player.recording if i == n else (lm.ghosts()[i].frames() if lm.ghost_count() > i else [])
		same = same and _same_path(got, runs[i])
	check("%s: stored inputs reproduce the stored runs" % stage, same)
	check("%s: stored inputs CLEAR the stage" % stage, lm.cleared)
	# 루프 하나를 통째로 빼고 나머지 입력을 그대로 재생: 그 고스트가 마지막 루프에서든 다른 고스트를 녹화할 때든
	# 필요했다면 CLEAR되지 않는다(예: 2-5 파랑 문은 녹화 때만 열려 있으면 된다).
	for skip in n:
		await restart()
		for j in inputs.size():
			if j != skip:
				await play_inputs(inputs[j], int(doc["end_at"][j]) if j < n else -1, lm.loop_ticks + 5)
			if lm.cleared:
				break
		check("%s: without loop %d (ghost %d) the rest of the inputs do not CLEAR" % [stage, skip + 1, skip + 1], not lm.cleared)


func _same_path(a: Array, b: Array) -> bool:
	if a.size() < b.size() or b.is_empty():
		return false
	for k in b.size():
		if (a[k]["pos"] as Vector2).distance_to(b[k]["pos"]) > POS_TOLERANCE or a[k]["interact"] != b[k]["interact"]:
			return false
	return true
