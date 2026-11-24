class_name BloodSplat
extends Node2D
## Лужа крови на полу. Рисуется один раз случайными кругами и остаётся до рестарта.

const COLORS := [Color(0.55, 0.0, 0.08), Color(0.42, 0.0, 0.06), Color(0.7, 0.02, 0.12)]

var direction := Vector2.RIGHT  # куда летят брызги
var amount := 1.0               # размер лужи (1 — обычная)

var _blobs: Array = []  # список кругов: [центр, радиус, цвет]


func _ready() -> void:
	var dir := direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	# Основная лужа
	for i in int(6 * amount):
		var center := Vector2(randf_range(-5, 5), randf_range(-5, 5))
		_blobs.append([center, randf_range(3, 7) * amount, COLORS.pick_random()])
	# Брызги по направлению удара
	for i in int(8 * amount):
		var distance := randf_range(6, 28) * amount
		var spread := dir.rotated(randf_range(-0.5, 0.5)) * distance
		_blobs.append([spread, randf_range(1, 3), COLORS.pick_random()])


func _draw() -> void:
	for blob in _blobs:
		draw_circle(blob[0], blob[1], blob[2])
