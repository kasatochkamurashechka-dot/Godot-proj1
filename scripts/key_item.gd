@tool  # рисуется и в редакторе
class_name KeyItem
extends Node2D
## Ключи от машины. Подбираются автоматически, когда герой подходит вплотную.

const COLOR := Color(1.0, 0.85, 0.2)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("keys")  # по этой группе ключи находит main.gd
	material = LightTextures.unshaded()  # светится — виден и в темноте


func _process(_delta: float) -> void:
	queue_redraw()  # мигающее свечение


func _draw() -> void:
	# Пульсирующее свечение, чтобы ключи было видно в темноте
	var pulse := 0.15 + 0.1 * sin(Time.get_ticks_msec() / 200.0)
	draw_circle(Vector2.ZERO, 8.0, Color(COLOR, pulse))
	draw_arc(Vector2(-2, 0), 2.5, 0.0, TAU, 12, COLOR, 1.0)    # кольцо
	draw_line(Vector2(0.5, 0), Vector2(5, 0), COLOR, 1.0)       # стержень
	draw_line(Vector2(4, 0), Vector2(4, 2), COLOR, 1.0)         # бородка
