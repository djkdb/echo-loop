extends Node
## 리플레이 저장·불러오기(autoload ReplayIO). CLEAR 때 그 스테이지의 모든 루프 녹화를
## user://replays/<stage>.json 에 저장하고, 리플레이 씬(game/replay.tscn)이 불러와 재생한다.
## 위치는 full precision으로 저장해 불러온 녹화가 원래 녹화와 같은 결과를 낸다.

const DIR: String = "user://replays"
const VERSION: int = 1


func path_for(stage_id: String) -> String:
	return "%s/%s.json" % [DIR, stage_id]


## runs: 루프 순서대로의 녹화 목록(마지막이 CLEAR한 "지금의 나").
func save_run(stage_id: String, level_path: String, loop_seconds: float, runs: Array) -> Error:
	DirAccess.make_dir_recursive_absolute(DIR)
	var data: Array = []
	for frames: Array in runs:
		var arr: Array = []
		for f: Dictionary in frames:
			var p: Vector2 = f["pos"]
			arr.append([p.x, p.y, f["flip"], f["interact"], f.get("jump", false)])
		data.append(arr)
	var doc: Dictionary = {"version": VERSION, "stage": stage_id, "level": level_path, "loop_seconds": loop_seconds, "runs": data}
	var file := FileAccess.open(path_for(stage_id), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(doc, "", false, true))
	return OK


## {"level": String, "loop_seconds": float, "runs": Array[Array[Dictionary]]}. 없으면 빈 Dictionary.
func load_run(stage_id: String) -> Dictionary:
	var file := FileAccess.open(path_for(stage_id), FileAccess.READ)
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
	return {"level": doc["level"], "loop_seconds": float(doc["loop_seconds"]), "runs": runs, "stage": doc.get("stage", stage_id)}
