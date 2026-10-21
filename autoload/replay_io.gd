extends Node
## 리플레이 저장·불러오기(autoload ReplayIO). CLEAR 때 그 스테이지의 모든 루프 녹화를
## user://replays/<stage>.json 에 저장하고, 리플레이 씬(game/replay.tscn)이 불러와 재생한다.
## 위치는 full precision으로 저장해 불러온 녹화가 원래 녹화와 같은 결과를 낸다.

const DIR: String = "user://replays"
## 개발자 정답 리플레이(레벨마다 하나, 별 3개 기준). 형식은 같고 입력 기록(inputs·end_at)이 더 있다.
const SOLUTION_DIR: String = "res://solutions"
const VERSION: int = 1


func path_for(stage_id: String) -> String:
	return "%s/%s.json" % [DIR, stage_id]


## runs: 루프 순서대로의 녹화 목록(마지막이 CLEAR한 "지금의 나").
func save_run(stage_id: String, level_path: String, loop_seconds: float, runs: Array) -> Error:
	DirAccess.make_dir_recursive_absolute(DIR)
	var doc: Dictionary = {"version": VERSION, "stage": stage_id, "level": level_path, "loop_seconds": loop_seconds, "runs": encode_runs(runs)}
	var file := FileAccess.open(path_for(stage_id), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(doc, "", false, true))
	return OK


func solution_path(stage_id: String) -> String:
	return "%s/%s.json" % [SOLUTION_DIR, stage_id]


## 녹화 runs를 JSON에 넣는 배열로(위치는 full precision).
func encode_runs(runs: Array) -> Array:
	var data: Array = []
	for frames: Array in runs:
		var arr: Array = []
		for f: Dictionary in frames:
			var p: Vector2 = f["pos"]
			arr.append([p.x, p.y, f["flip"], f["interact"], f.get("jump", false)])
		data.append(arr)
	return data


## {"level": String, "loop_seconds": float, "runs": Array[Array[Dictionary]]}. 없으면 빈 Dictionary.
func load_run(stage_id: String) -> Dictionary:
	return load_file(path_for(stage_id), stage_id)


## 정답 리플레이. load_run 결과에 "inputs"·"end_at"이 더 있다.
func load_solution(stage_id: String) -> Dictionary:
	return load_file(solution_path(stage_id), stage_id)


func load_file(path: String, stage_id: String = "") -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var doc: Variant = JSON.parse_string(file.get_as_text())
	if not doc is Dictionary:
		return {}
	var runs: Array = []
	for arr: Array in doc["runs"]:
		var frames: Array[Dictionary] = []
		for v: Array in arr:
			frames.append({"pos": Vector2(v[0], v[1]), "flip": v[2], "interact": v[3], "jump": v[4] if v.size() > 4 else false})
		runs.append(frames)
	var out: Dictionary = {"level": doc["level"], "loop_seconds": float(doc["loop_seconds"]), "runs": runs, "stage": doc.get("stage", stage_id)}
	for k: String in ["inputs", "end_at"]:
		if doc.has(k):
			out[k] = doc[k]
	return out
