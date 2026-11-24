@tool  # рисуется и в редакторе
class_name ExitZone
extends Node2D
## Выход к машине. Пропускает, только если у героя есть ключи (проверяет main.gd).

const COLOR := Color(0.3, 1.0, 0.6)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("exits")  # по этой группе выход находит main.gd
	material = LightTextures.unshaded()  # светится — виден и в темноте


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var pulse := 0.25 + 0.15 * sin(Time.get_ticks_msec() / 250.0)
	draw_rect(Rect2(-8, -8, 16, 16), Color(COLOR, pulse))
	# Стрелка «наружу» (влево)
	draw_line(Vector2(4, 0), Vector2(-4, 0), COLOR, 1.0)
	draw_line(Vector2(-4, 0), Vector2(-1, -3), COLOR, 1.0)
	draw_line(Vector2(-4, 0), Vector2(-1, 3), COLOR, 1.0)
