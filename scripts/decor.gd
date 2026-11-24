@tool  # рисуется и в редакторе
class_name Decor
extends Node2D
## Декор на полу: не мешает ходить, только рассказывает историю.
## Знаки на полу, записки, чемоданы и ключи пропавших гостей, пятна, люк наверх.
##
## Как поставить: перетащи scenes/props/decor.tscn в сцену (лучше в Props/Decor)
## и выбери вид (kind). Поворот узла поворачивает и рисунок.
## Пока это рисунки-заглушки кодом; позже записки можно будет читать.

# Новые виды добавляем только в конец: в сценах вид хранится номером
enum Kind { SIGIL, NOTE, SUITCASE, ROOM_KEYS, HATCH, STAIN }

## Что это
@export var kind := Kind.SIGIL:
	set(value):
		kind = value
		queue_redraw()
## Размер (для знака — диаметр, для люка и пятна — ширина)
@export var size := 32.0:
	set(value):
		size = value
		queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("decor")
	if kind == Kind.SIGIL:
		material = LightTextures.unshaded()  # знаки слабо светятся в темноте


func _draw() -> void:
	match kind:
		Kind.SIGIL: _draw_sigil()
		Kind.NOTE: _draw_note()
		Kind.SUITCASE: _draw_suitcase()
		Kind.ROOM_KEYS: _draw_keys()
		Kind.HATCH: _draw_hatch()
		Kind.STAIN: _draw_stain()


func _draw_sigil() -> void:
	# Круг с вписанными линиями — странный знак, нарисованный чем-то тёмно-красным
	var c := Color(0.55, 0.05, 0.08, 0.55)
	var radius := size / 2.0
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, c, 1.5)
	draw_arc(Vector2.ZERO, radius * 0.7, 0.0, TAU, 32, c, 1.0)
	var points := PackedVector2Array()
	for i in 7:  # семиконечная «звезда» через вершину
		points.append(Vector2.UP.rotated(TAU * float(i * 3 % 7) / 7.0) * radius * 0.7)
	points.append(points[0])
	draw_polyline(points, c, 1.0)
	draw_circle(Vector2.ZERO, 2.0, c)


func _draw_note() -> void:
	draw_rect(Rect2(-4, -5, 8, 10), Color(0.85, 0.82, 0.68))
	for i in 3:
		draw_line(Vector2(-3, -3 + i * 3), Vector2(2, -3 + i * 3), Color(0.3, 0.3, 0.35), 1.0)


func _draw_suitcase() -> void:
	draw_rect(Rect2(-8, -5, 16, 10), Color(0.4, 0.22, 0.14))
	draw_rect(Rect2(-8, -5, 16, 10), Color(0.2, 0.1, 0.06), false, 1.0)
	draw_rect(Rect2(-3, -7, 6, 2), Color(0.2, 0.1, 0.06))         # ручка
	draw_rect(Rect2(-8, -1, 16, 1), Color(0.6, 0.5, 0.3))          # ремень


func _draw_keys() -> void:
	# Связка ключей от номеров: брелоки с номерами-«ромбиками»
	for i in 5:
		var p := Vector2(-6 + i * 3, sin(i * 1.7) * 3)
		draw_line(p, p + Vector2(2, 4), Color(0.8, 0.7, 0.35), 1.0)
		draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.75, 0.2, 0.25))


func _draw_hatch() -> void:
	# Люк наверх: квадрат в полу с лестницей
	var half := size / 2.0
	draw_rect(Rect2(-half, -half, size, size), Color(0.1, 0.1, 0.12))
	draw_rect(Rect2(-half, -half, size, size), Color(0.45, 0.45, 0.4), false, 2.0)
	var y := -half + 4
	while y < half - 2:  # перекладины лестницы
		draw_line(Vector2(-half + 6, y), Vector2(half - 6, y), Color(0.6, 0.58, 0.5), 2.0)
		y += 6


func _draw_stain() -> void:
	# Тёмное пятно на полу (кровь или что похуже)
	var c := Color(0.25, 0.02, 0.04, 0.6)
	draw_circle(Vector2.ZERO, size * 0.3, c)
	draw_circle(Vector2(size * 0.25, size * 0.1), size * 0.18, c)
	draw_circle(Vector2(-size * 0.2, size * 0.2), size * 0.12, c)
