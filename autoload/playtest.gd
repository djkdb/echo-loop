extends Node
## 플레이 테스트 기록(autoload Playtest). 스테이지마다 시도한 루프 수, 되돌리기·처음부터 횟수, 처음 클리어까지 걸린
## 실제 시간, 쓴 고스트 수, 별을 user://playtest.json 에 남긴다. 서버로 보내지 않는다.
## 친구가 타이틀 화면 "테스트 결과 복사"로 요약 + JSON을 클립보드에 담아 보내고, tools/playtest_report.py가 모아 본다.

const DEFAULT_PATH: String = "user://playtest.json"
const GAME_VERSION: String = "0.2.0"

## 저장 파일 경로(자동 테스트가 실제 기록을 건드리지 않도록 바꾼다).
var path: String = DEFAULT_PATH
## stage_id -> {starts, loops, undos, restarts, time_sec, cleared, first_clear_sec, first_clear_ghosts, best_ghosts, stars}
var stages: Dictionary = {}

var _stage: String = ""
var _lm: LoopManager
var _since_msec: int = 0
## start_level이 부르는 첫 restart_stage는 사람이 누른 "처음부터"가 아니다.
var _skip_restart: bool = false


func _ready() -> void:
	load_file()


## 스테이지를 시작했을 때(Main이 레벨을 붙인 뒤, start_level 전에) 부른다.
func begin(stage_id: String, lm: LoopManager) -> void:
	end_session()
	_stage = stage_id
	_lm = lm
	_since_msec = Time.get_ticks_msec()
	_skip_restart = true
	var e: Dictionary = entry(stage_id)
	e["starts"] = int(e["starts"]) + 1
	for pair: Array in [[lm.loop_ended, _on_loop], [lm.loop_failed, _on_loop_failed], [lm.ghost_undone, _on_undo],
			[lm.ghosts_changed, _on_ghosts_changed], [lm.stage_restarted, _on_restart], [lm.stage_cleared, _on_clear]]:
		var sig: Signal = pair[0]
		if not sig.is_connected(pair[1]):
			sig.connect(pair[1])
	save_file()


## 스테이지를 떠날 때(씬 전환·종료) 부른다. 아직 못 깬 스테이지면 그동안의 시간을 더한다.
func end_session() -> void:
	if _stage == "":
		return
	_add_time()
	_stage = ""
	_lm = null
	save_file()


func entry(stage_id: String) -> Dictionary:
	if not stages.has(stage_id):
		stages[stage_id] = {"starts": 0, "loops": 0, "undos": 0, "restarts": 0, "time_sec": 0.0, "cleared": false,
			"first_clear_sec": -1.0, "first_clear_ghosts": -1, "best_ghosts": -1, "stars": 0}
	return stages[stage_id]


## 사람이 읽는 요약 + JSON(카톡으로 붙여 보내는 용도).
func report_text() -> String:
	_add_time()
	var lines: PackedStringArray = ["Echo Loop 플레이 테스트 결과 (v%s, %s)" % [GAME_VERSION, _device()]]
	for s: Dictionary in Stages.LIST:
		if not stages.has(s["id"]):
			continue
		var e: Dictionary = stages[s["id"]]
		var head: String = "%s %s: " % [s["code"], s["title"]]
		if e["cleared"]:
			head += "클리어 %s · 고스트 %d명 %s" % [_mmss(e["first_clear_sec"]), e["best_ghosts"], "★".repeat(int(e["stars"]))]
		else:
			head += "못 깸 (%s 동안)" % _mmss(e["time_sec"])
		head += " · 루프 %d · 되돌리기 %d · 처음부터 %d" % [e["loops"], e["undos"], e["restarts"]]
		lines.append(head)
	if lines.size() == 1:
		lines.append("(아직 기록 없음)")
	lines.append("---")
	lines.append(JSON.stringify(to_json()))
	return "\n".join(lines)


func to_json() -> Dictionary:
	return {"version": 1, "game_version": GAME_VERSION, "device": _device(), "stages": stages}


func save_file() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(to_json(), "\t"))


func load_file() -> void:
	stages = {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var doc: Variant = JSON.parse_string(file.get_as_text())
	if doc is Dictionary and (doc as Dictionary).get("stages") is Dictionary:
		stages = (doc["stages"] as Dictionary).duplicate(true)


func _add_time() -> void:
	if _stage == "":
		return
	var now: int = Time.get_ticks_msec()
	var e: Dictionary = entry(_stage)
	if not e["cleared"]:
		e["time_sec"] = snappedf(float(e["time_sec"]) + float(now - _since_msec) / 1000.0, 0.1)
	_since_msec = now


func _count_loop() -> void:
	if _stage != "":
		var e: Dictionary = entry(_stage)
		e["loops"] = int(e["loops"]) + 1


func _on_loop(_i: int) -> void:
	_count_loop()
	save_file()


func _on_loop_failed() -> void:
	_count_loop()


func _on_undo() -> void:
	if _stage != "":
		entry(_stage)["undos"] = int(entry(_stage)["undos"]) + 1


## 되돌리기·다시 찍기 고르기도 지금 루프를 처음부터 하므로 시도 하나로 센다.
func _on_ghosts_changed() -> void:
	_count_loop()


func _on_restart() -> void:
	if _skip_restart:
		_skip_restart = false
		return
	if _stage != "":
		entry(_stage)["restarts"] = int(entry(_stage)["restarts"]) + 1
		_count_loop()


func _on_clear() -> void:
	if _stage == "" or _lm == null:
		return
	_count_loop()
	_add_time()
	var e: Dictionary = entry(_stage)
	var ghosts: int = _lm.ghost_count()
	if not e["cleared"]:
		e["cleared"] = true
		e["first_clear_sec"] = e["time_sec"]
		e["first_clear_ghosts"] = ghosts
	if int(e["best_ghosts"]) < 0 or ghosts < int(e["best_ghosts"]):
		e["best_ghosts"] = ghosts
	var s: Dictionary = Stages.find(_stage)
	if not s.is_empty():
		e["stars"] = maxi(int(e["stars"]), Stages.stars_for(int(e["best_ghosts"]), s["max"], s["record"]))
	save_file()


func _device() -> String:
	var parts: PackedStringArray = ["web" if OS.has_feature("web") else OS.get_name().to_lower()]
	if TouchControls.enabled():
		parts.append("touch")
	return "/".join(parts)


func _mmss(sec: float) -> String:
	var s: int = roundi(maxf(sec, 0.0))
	return "%d분 %02d초" % [s / 60, s % 60]


func _notification(what: int) -> void:
	# 창을 닫을 때도 그때까지의 시간을 남긴다(웹은 탭을 닫으면 못 남길 수 있어 루프마다도 저장한다).
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		end_session()
