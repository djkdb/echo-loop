class_name Puff
extends Node2D
## 작은 먼지 한 알: velocity로 날아가며 lifetime 동안 옅어지고 스스로 사라진다(연출 전용).

var velocity: Vector2 = Vector2.ZERO
var color: Color = Palette.ME
var radius: float = 4.0
var lifetime: float = 0.3

var _age: float = 0.0


func _ready() -> void:
	top_level = true
	z_index = 5


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	position += velocity * delta
	velocity *= 0.9
	queue_redraw()


func _draw() -> void:
	var k: float = 1.0 - _age / lifetime
	draw_circle(Vector2.ZERO, radius * (0.6 + 0.4 * k), Color(color, 0.55 * k))


## pos에서 좌우·위로 흩어지는 먼지 n개를 parent 아래에 만든다.
static func burst(parent: Node, pos: Vector2, color: Color, n: int = 3) -> void:
	for i in n:
		var p := Puff.new()
		var dir: float = -1.0 + 2.0 * float(i) / float(maxi(n - 1, 1))
		p.position = pos + Vector2(dir * 10.0, -2.0)
		p.velocity = Vector2(dir * 90.0, -40.0 - 20.0 * absf(dir))
		p.color = color
		parent.add_child(p)
