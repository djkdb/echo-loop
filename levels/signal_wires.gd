class_name SignalWires
extends Node2D
## 보내는 쪽(판·레버·버튼) → 받는 쪽(문·발판·레이저) 신호선. 소스가 켜지면 0.25초에 걸쳐 빛이 받는 쪽까지 차오른다.
## 경로: 소스 바닥에서 수평으로 받는 쪽 x까지, 그다음 받는 쪽 중심까지 수직(연출 전용).

const FILL_SECONDS: float = 0.25
const DRAIN_SECONDS: float = 0.15

## [{"source": Node, "points": PackedVector2Array, "length": float, "fill": float}]
var _wires: Array[Dictionary] = []


## 레벨 아래에서 connected_sources()가 있는 받는 쪽을 모두 찾아 선을 만든다.
func build(level: Node) -> void:
	_wires.clear()
	for node: Node in level.find_children("*", "", true, false):
		if not node.has_method("connected_sources"):
			continue
		var to: Vector2 = (node as Node2D).global_position
		for source: Node in node.connected_sources():
			var from: Vector2 = (source as Node2D).global_position + Vector2(0, -3)
			var pts := PackedVector2Array([from, Vector2(to.x, from.y), to])
			_wires.append({"source": source, "points": pts, "length": _length(pts), "fill": 0.0})
	queue_redraw()


func _process(delta: float) -> void:
	var changed: bool = false
	for w: Dictionary in _wires:
		var src: Node = w["source"]
		var target: float = 1.0 if is_instance_valid(src) and src.is_on else 0.0
		var step: float = delta / (FILL_SECONDS if target > w["fill"] else DRAIN_SECONDS)
		var f: float = move_toward(w["fill"], target, step)
		if f != w["fill"]:
			w["fill"] = f
			changed = true
	if changed:
		queue_redraw()


func _draw() -> void:
	for w: Dictionary in _wires:
		var pts: PackedVector2Array = w["points"]
		draw_polyline(pts, Color(Palette.SIGNAL, 0.16), 3.0)
		if w["fill"] > 0.0:
			var lit: PackedVector2Array = _cut(pts, w["length"] * w["fill"])
			draw_polyline(lit, Color(Palette.SIGNAL, 0.35), 9.0)
			draw_polyline(lit, Palette.SIGNAL, 3.0)


func _length(pts: PackedVector2Array) -> float:
	var total: float = 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	return total


## 앞에서부터 len만큼만 남긴 경로.
func _cut(pts: PackedVector2Array, len: float) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	var left: float = len
	for i in range(1, pts.size()):
		var seg: float = pts[i - 1].distance_to(pts[i])
		if left >= seg:
			out.append(pts[i])
			left -= seg
		else:
			out.append(pts[i - 1].move_toward(pts[i], left))
			break
	return out
