@tool  # рисуется и в редакторе, чтобы мебель было видно при расстановке
class_name Furniture
extends StaticBody2D
## Мебель и прочие крупные предметы: кровать, машина, стойка, котёл, трубы подвала и т.п.
## Это «низкое препятствие»: сквозь него не пройти (ни герою, ни врагам),
## но поверх него видно, и свет через него проходит.
##
## Как поставить: перетащи scenes/props/furniture.tscn в сцену (лучше в Props/Furniture),
## выбери вид (kind) и размер (size) в инспекторе. Удобно, когда размер кратен 16
## (размеру клетки), а предмет стоит ровно по сетке.
## Предмет рисуется «вертикально»: у кровати подушка сверху, у машины капот сверху.
## Чтобы развернуть, поверни узел (rotation) — на 90° или 180°.
## Пока это рисунки-заглушки кодом; на этапе графики их заменят спрайты.

# Новые виды добавляем только в конец: в сценах вид хранится номером
enum Kind { BED, CAR, STAIRS, BOILER, WASHERS, COUNTER, DESK, DUMPSTER, VENDING,
	SHELF, PIPES, PANEL, FREEZER, CRATES }

## У каждого предмета своя обводка для теней: он освещён со стороны лампы, за ним тень.
## Кроме лестницы — это пролёт в полу, а не предмет. Видимость для врагов от теней
## не зависит: поверх любой мебели по-прежнему видно.
const NO_SHADOW_KINDS := [Kind.STAIRS]

## Что это за предмет
@export var kind := Kind.BED:
	set(value):
		kind = value
		queue_redraw()
## Размер в пикселях (ширина, высота). 16 пикселей = одна клетка
@export var size := Vector2(48, 64):
	set(value):
		size = value
		queue_redraw()
## Основной цвет: кузов машины, одеяло, автомат с напитками
@export var color := Color(0.55, 0.25, 0.35):
	set(value):
		color = value
		queue_redraw()

const DARK := Color(0.08, 0.07, 0.1)
const GLASS := Color(0.12, 0.16, 0.24)
const METAL := Color(0.38, 0.4, 0.44)
const WOOD := Color(0.42, 0.26, 0.15)
const WOOD_LIGHT := Color(0.55, 0.36, 0.22)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("obstacles")  # по этой группе карта узнаёт, какие клетки заняты
	collision_layer = 8  # слой 4 «низкие препятствия»: сталкиваются герой и враги
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	# Своя обводка: предмет отбрасывает тень (слой «мебель»)
	if not kind in NO_SHADOW_KINDS:
		add_child(LightTextures.make_occluder(LightTextures.rect_points(size),
				LightTextures.SHADOW_LAYER_FURNITURE))
	# Автоматы с напитками светятся в темноте. Свет стоит внутри самого автомата,
	# поэтому обводки мебели (и его собственная) ему не мешают — только стены
	if kind == Kind.VENDING:
		var glow := LightTextures.make_light(LightTextures.radial(), 60.0, color.lightened(0.3), 0.7)
		glow.shadow_item_cull_mask = LightTextures.SHADOW_LAYER_WALLS
		add_child(glow)


## Прямоугольник, который предмет занимает в мире (с учётом поворота).
## Нужен карте для поиска пути.
func get_world_rect() -> Rect2:
	var r := Rect2(-size / 2.0, size)
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var world := Rect2(global_transform * corners[0], Vector2.ZERO)
	for corner in corners:
		world = world.expand(global_transform * corner)
	return world


## Редактор: убираем предупреждение «нет формы столкновения» — форма создаётся при запуске.
func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray()


func _draw() -> void:
	var r := Rect2(-size / 2.0, size)
	if kind != Kind.STAIRS:  # лестница уходит вниз, а не стоит на полу — без тени
		draw_rect(Rect2(r.position + Depth.offset(self), r.size), Depth.COLOR)
	match kind:
		Kind.BED: _draw_bed(r)
		Kind.CAR: _draw_car(r)
		Kind.STAIRS: _draw_stairs(r)
		Kind.BOILER: _draw_boiler(r)
		Kind.WASHERS: _draw_washers(r)
		Kind.COUNTER: _draw_counter(r)
		Kind.DESK: _draw_desk(r)
		Kind.DUMPSTER: _draw_dumpster(r)
		Kind.VENDING: _draw_vending(r)
		Kind.SHELF: _draw_shelf(r)
		Kind.PIPES: _draw_pipes(r)
		Kind.PANEL: _draw_panel(r)
		Kind.FREEZER: _draw_freezer(r)
		Kind.CRATES: _draw_crates(r)


func _draw_bed(r: Rect2) -> void:
	draw_rect(r, WOOD)                                      # каркас
	var mattress := r.grow(-2)
	draw_rect(mattress, Color(0.82, 0.82, 0.86))            # простыня
	var pillow := Rect2(mattress.position + Vector2(3, 2), Vector2(mattress.size.x - 6, 9))
	draw_rect(pillow, Color(0.96, 0.96, 0.98))              # подушка
	draw_rect(pillow, Color(0.7, 0.7, 0.75), false, 1.0)
	var blanket_top := mattress.position.y + mattress.size.y * 0.4
	var blanket := Rect2(mattress.position.x, blanket_top, mattress.size.x, mattress.end.y - blanket_top)
	draw_rect(blanket, color)                               # одеяло
	draw_line(blanket.position, Vector2(blanket.end.x, blanket.position.y), color.lightened(0.35), 2.0)


func _draw_car(r: Rect2) -> void:
	# Колёса торчат по бокам
	var wheel := Vector2(3, 9)
	for y in [r.position.y + 7, r.end.y - 16]:
		draw_rect(Rect2(Vector2(r.position.x - 1, y), wheel), DARK)
		draw_rect(Rect2(Vector2(r.end.x - 2, y), wheel), DARK)
	var body := r.grow_individual(-1, 0, -1, 0)
	draw_rect(body, color)                                  # кузов
	draw_rect(body, color.darkened(0.45), false, 1.0)
	var h := body.size.y
	# Лобовое и заднее стекло, крыша между ними
	var windshield := Rect2(body.position.x + 3, body.position.y + h * 0.27, body.size.x - 6, h * 0.16)
	var rear := Rect2(body.position.x + 3, body.position.y + h * 0.74, body.size.x - 6, h * 0.1)
	draw_rect(windshield, GLASS)
	draw_rect(rear, GLASS)
	draw_rect(Rect2(windshield.position.x, windshield.end.y, windshield.size.x, rear.position.y - windshield.end.y),
			color.lightened(0.12))                          # крыша
	# Фары спереди (сверху) и фонари сзади
	draw_rect(Rect2(body.position.x + 2, body.position.y, 5, 2), Color(1, 0.95, 0.7))
	draw_rect(Rect2(body.end.x - 7, body.position.y, 5, 2), Color(1, 0.95, 0.7))
	draw_rect(Rect2(body.position.x + 2, body.end.y - 2, 5, 2), Color(0.9, 0.1, 0.15))
	draw_rect(Rect2(body.end.x - 7, body.end.y - 2, 5, 2), Color(0.9, 0.1, 0.15))


func _draw_stairs(r: Rect2) -> void:
	draw_rect(r.grow(2),DARK)
	var depth := r.size.y / 7.0
	for i in range(7):
		var tread := Rect2(r.position+Vector2(2,i*depth),Vector2(r.size.x-4,depth))
		draw_rect(tread,Color("#373643").lightened(0.055*i))
		draw_line(tread.position,tread.position+Vector2(tread.size.x,0),Color("#bcb2a0"),1.5)
	for x in [r.position.x,r.end.x]:
		for i in range(3):
			var foot := Vector2(x,r.position.y+i*r.size.y/2)
			draw_line(foot,foot+Vector2(-2,-7),METAL,2)
		draw_line(Vector2(x-2,r.position.y-7),Vector2(x-2,r.end.y-7),Color("#e7bd82"),2)


func _draw_boiler(r: Rect2) -> void:
	draw_rect(r, Color(0.22, 0.23, 0.26))
	var center := r.get_center()
	var radius := minf(r.size.x, r.size.y) / 2.0 - 2.0
	draw_circle(center, radius, METAL)                      # бак
	draw_arc(center, radius, 0.0, TAU, 24, METAL.lightened(0.3), 1.0)
	draw_line(center, Vector2(r.end.x, center.y), Color(0.5, 0.3, 0.2), 3.0)  # труба
	draw_circle(center + Vector2(-radius * 0.4, -radius * 0.4), 2.0, Color(0.9, 0.2, 0.15))  # манометр


func _draw_washers(r: Rect2) -> void:
	# Ряд стиральных машин по 16 пикселей вдоль длинной стороны
	var along_x := r.size.x >= r.size.y
	var count := maxi(1, int((r.size.x if along_x else r.size.y) / 16.0))
	for i in count:
		var cell := Rect2(r.position + (Vector2(16 * i, 0) if along_x else Vector2(0, 16 * i)), Vector2(16, 16))
		draw_rect(cell.grow(-1), Color(0.86, 0.86, 0.9))
		draw_rect(cell.grow(-1), Color(0.5, 0.5, 0.55), false, 1.0)
		draw_circle(cell.get_center(), 4.0, Color(0.25, 0.3, 0.42))  # дверца-иллюминатор


func _draw_counter(r: Rect2) -> void:
	draw_rect(r, WOOD)
	draw_rect(r.grow(-2), WOOD_LIGHT)                       # столешница
	draw_circle(r.get_center() + Vector2(0, -r.size.y * 0.3), 2.0, Color(0.9, 0.8, 0.3))  # звонок


func _draw_desk(r: Rect2) -> void:
	draw_rect(r, WOOD)
	draw_rect(r.grow(-1), WOOD_LIGHT, false, 1.0)
	draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(9, 11)), Color(0.85, 0.82, 0.7))   # бумаги
	draw_rect(Rect2(r.position + Vector2(16, 6), Vector2(8, 8)), Color(0.85, 0.82, 0.7))
	draw_circle(r.end - Vector2(7, 7), 3.0, Color(0.15, 0.4, 0.25))                      # настольная лампа


func _draw_dumpster(r: Rect2) -> void:
	var green := Color(0.16, 0.36, 0.24)
	draw_rect(r, green)
	draw_rect(r, green.darkened(0.5), false, 1.0)
	var x := r.position.x + 4
	while x < r.end.x - 2:                                  # рёбра крышки
		draw_line(Vector2(x, r.position.y + 2), Vector2(x, r.end.y - 2), green.lightened(0.25), 1.0)
		x += 6


func _draw_vending(r: Rect2) -> void:
	# Автоматы по 16 пикселей шириной, цвета чередуются
	var count := maxi(1, int(r.size.x / 16.0))
	for i in count:
		var cell := Rect2(r.position + Vector2(16 * i, 0), Vector2(16, r.size.y))
		var c := color if i % 2 == 0 else color.inverted().lerp(color, 0.3)
		draw_rect(cell.grow(-1), c.darkened(0.3))
		draw_rect(Rect2(cell.position + Vector2(3, 3), Vector2(10, cell.size.y - 6)), c.lightened(0.4))  # витрина


func _draw_shelf(r: Rect2) -> void:
	# Металлический стеллаж: рама, полки и коробки на них
	draw_rect(r, METAL.darkened(0.3))
	draw_rect(r, METAL, false, 1.0)
	var along_x := r.size.x >= r.size.y
	var length := r.size.x if along_x else r.size.y
	var i := 0
	var pos := 3.0
	while pos < length - 6.0:
		var box_len := 6.0 + float((i * 7) % 5)  # коробки разной длины
		var box := Rect2(r.position + Vector2(pos, 3), Vector2(box_len, r.size.y - 6)) if along_x \
				else Rect2(r.position + Vector2(3, pos), Vector2(r.size.x - 6, box_len))
		draw_rect(box, WOOD_LIGHT if i % 2 == 0 else Color(0.6, 0.55, 0.42))
		pos += box_len + 2.0
		i += 1


func _draw_pipes(r: Rect2) -> void:
	# Две-три трубы вдоль длинной стороны, с хомутами и вентилем
	var along_x := r.size.x >= r.size.y
	var thickness := r.size.y if along_x else r.size.x
	var count := maxi(1, int(thickness / 6.0))
	var width := thickness / count
	for i in count:
		var c := color.lerp(METAL, 0.5) if i % 2 == 0 else METAL
		var pipe := Rect2(r.position + Vector2(0, i * width + 1), Vector2(r.size.x, width - 2)) if along_x \
				else Rect2(r.position + Vector2(i * width + 1, 0), Vector2(width - 2, r.size.y))
		draw_rect(pipe, c)
		# Блик вдоль трубы
		var shine := Rect2(pipe.position + Vector2(0, 1), Vector2(pipe.size.x, 1)) if along_x \
				else Rect2(pipe.position + Vector2(1, 0), Vector2(1, pipe.size.y))
		draw_rect(shine, c.lightened(0.35))
	var length := r.size.x if along_x else r.size.y
	var pos := 6.0
	while pos < length:  # хомуты
		var clamp_rect := Rect2(r.position + Vector2(pos, 0), Vector2(2, r.size.y)) if along_x \
				else Rect2(r.position + Vector2(0, pos), Vector2(r.size.x, 2))
		draw_rect(clamp_rect, DARK)
		pos += 20.0
	draw_circle(r.get_center(), minf(thickness / 2.0, 5.0), Color(0.75, 0.15, 0.12))  # вентиль


func _draw_panel(r: Rect2) -> void:
	# Электрощит: серый ящик с рядами автоматов и большим рубильником
	draw_rect(r, Color(0.3, 0.32, 0.3))
	draw_rect(r, Color(0.5, 0.52, 0.48), false, 1.0)
	var x := r.position.x + 3
	while x < r.end.x - 10:
		draw_rect(Rect2(x, r.position.y + 3, 3, r.size.y - 6), DARK)
		draw_rect(Rect2(x, r.position.y + 3, 3, 2), Color(0.9, 0.85, 0.3))
		x += 5
	draw_rect(Rect2(r.end.x - 8, r.position.y + 2, 5, r.size.y - 4), Color(0.75, 0.15, 0.12))  # рубильник


func _draw_freezer(r: Rect2) -> void:
	# Морозильный ларь: белый, с крышкой, ручкой и инеем
	draw_rect(r, Color(0.8, 0.84, 0.86))
	draw_rect(r, Color(0.5, 0.55, 0.6), false, 1.0)
	draw_rect(r.grow(-3), Color(0.88, 0.92, 0.95))
	draw_rect(Rect2(r.get_center().x - 5, r.end.y - 4, 10, 2), METAL)  # ручка
	draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x * 0.4, 1)), Color(0.7, 0.9, 1.0))  # иней


func _draw_crates(r: Rect2) -> void:
	# Груда деревянных ящиков: сетка ящиков примерно по 16 пикселей
	var cols := maxi(1, int(r.size.x / 16.0))
	var rows := maxi(1, int(r.size.y / 16.0))
	var cell := Vector2(r.size.x / cols, r.size.y / rows)
	for y in rows:
		for x in cols:
			var box := Rect2(r.position + Vector2(x, y) * cell, cell).grow(-1)
			draw_rect(box, WOOD if (x + y) % 2 == 0 else WOOD_LIGHT)
			draw_rect(box, WOOD.darkened(0.5), false, 1.0)
			draw_line(box.position, box.end, WOOD.darkened(0.4), 1.0)  # доска наискосок
