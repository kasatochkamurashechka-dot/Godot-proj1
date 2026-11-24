class_name NoiseRing
extends Node2D
## Расходящийся круг звука: подсказка игроку, на каком расстоянии его слышно.

const LIFETIME := 0.45  # сколько секунд виден круг

var max_radius := 100.0
var strength := 1.0  # яркость (шаги — бледнее, брошенный предмет — ярче)
var color := Color(0.6, 0.9, 1.0)  # голубой — шумит герой, красный — враги

var _age := 0.0


func _ready() -> void:
	material = LightTextures.unshaded()  # светится — виден и в темноте


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var alpha := 0.35 * strength * (1.0 - t)
	draw_arc(Vector2.ZERO, max_radius * t, 0.0, TAU, 32, Color(color, alpha), 1.0)
