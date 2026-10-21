class_name ClearPaths
extends Node2D
## CLEAR 뒤 모든 루프 경로(고스트 녹화 + 마지막 나)를 색별 점선으로 겹쳐 그린다. reveal 동안 앞에서부터 그려진다.

const DASH: float = 10.0
const STEP: int = 2

var _paths: Array = []
var _reveal: float = 1.0
var _t: float = 0.0


func show_paths(paths: Array, reveal_seconds: float) -> void:
	_paths = paths
	_reveal = maxf(reveal_seconds, 0.01)
	_t = 0.0
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	if _t < _reveal:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var k: float = clampf(_t / _reveal, 0.0, 1.0)
	for p: Dictionary in _paths:
		var frames: Array = p["frames"]
		var n: int = int(frames.size() * k)
		var color: Color = p["color"]
		var i: int = STEP
		while i < n:
			var a: Vector2 = frames[i - STEP]["pos"]
			var b: Vector2 = frames[i]["pos"]
			if a.distance_to(b) > 0.5:
				draw_dashed_line(a + Vector2(0, 20), b + Vector2(0, 20), Color(color, 0.85), 2.0, DASH)
			i += STEP
