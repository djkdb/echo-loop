extends Node
## 클리어 기록(autoload Progress). 스테이지마다 CLEAR한 최소 고스트 수를 user://progress.json 에 저장한다.
## 별점은 Stages 목록의 상한·개발자 기록으로 계산하므로 기록만 남긴다.

const DEFAULT_PATH: String = "user://progress.json"

## 저장 파일 경로(자동 테스트가 실제 기록을 건드리지 않도록 바꾼다).
var path: String = DEFAULT_PATH
## stage_id -> 그 스테이지를 CLEAR한 최소 고스트 수.
var best: Dictionary = {}
## 스테이지 선택 화면이 고른 스테이지. Main이 _ready에서 읽고, 비어 있으면 자기 level_scene을 쓴다.
var pending_stage: String = ""


func _ready() -> void:
	load_file()


## CLEAR 기록. 이전보다 적은 고스트면 갱신하고 true.
func record_clear(stage_id: String, ghosts: int) -> bool:
	if best.has(stage_id) and int(best[stage_id]) <= ghosts:
		return false
	best[stage_id] = ghosts
	save_file()
	return true


func is_cleared(stage_id: String) -> bool:
	return best.has(stage_id)


func best_ghosts(stage_id: String) -> int:
	return int(best.get(stage_id, -1))


func stars(stage_id: String) -> int:
	var s: Dictionary = Stages.find(stage_id)
	if s.is_empty() or not is_cleared(stage_id):
		return 0
	return Stages.stars_for(best_ghosts(stage_id), s["max"], s["record"])


func total_stars() -> int:
	var n: int = 0
	for s: Dictionary in Stages.LIST:
		n += stars(s["id"])
	return n


## 첫 스테이지는 처음부터, 나머지는 바로 앞 스테이지를 깨면 열린다.
func is_unlocked(stage_id: String) -> bool:
	var i: int = Stages.index_of(stage_id)
	if i <= 0:
		return i == 0
	return is_cleared(Stages.LIST[i - 1]["id"])


func save_file() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("기록을 저장하지 못했다: %s" % path)
		return
	file.store_string(JSON.stringify({"version": 1, "best": best}, "\t"))


func load_file() -> void:
	best = {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var doc: Variant = JSON.parse_string(file.get_as_text())
	if doc is Dictionary and (doc as Dictionary).get("best") is Dictionary:
		for k: String in doc["best"]:
			best[k] = int(doc["best"][k])
