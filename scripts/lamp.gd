@tool  # рисуется и в редакторе: видно трубку и примерно, куда она светит
class_name Lamp
extends Node2D
## Неоновая лампа-трубка на стене: цветной свет с тенями от стен. Может мигать.
##
## Как поставить: центр лампы — на край стены (где стена переходит в пол).
## Трубка лежит вдоль стены (локальная ось X), свет идёт в комнату (локальная ось +Y).
## Поворот узла задаёт, на какой стене висит лампа:
##   0° — на стене сверху (светит вниз), 180° — на стене снизу (светит вверх),
##   -90° — на стене слева (светит вправо), 90° — на стене справа (светит влево).

const COLORS := [
	Color(1.0, 0.25, 0.75),  # маджента
	Color(0.25, 0.9, 1.0),   # циан
	Color(1.0, 0.75, 0.3),   # тёплый жёлтый
	Color(1.0, 0.12, 0.1),   # красный — только для опасных мест
]
const LIGHT_RANGE := 95.0   # радиус света каждой из двух «точек» трубки
const ENERGY := 0.6         # яркость каждой «точки»
const LIGHT_DEPTH := 8.0    # насколько свет вынесен от стены в комнату
const TUBE_WIDTH := 3.0

## Цвет: 0 — маджента, 1 — циан, 2 — тёплый жёлтый, 3 — красный (опасность)
@export_range(0, 3) var color_index := 0:
	set(value):
		color_index = value
		queue_redraw()
## Длина трубки в пикселях (16 — одна клетка)
@export var length := 56.0:
	set(value):
		length = value
		queue_redraw()
## Мигает ли лампа (неисправный неон)
@export var flicker := false
## Горит ли лампа. Выключенную удобно оставить на карте и включать в нужных петлях
@export var lit := true:
	set(value):
		lit = value
		queue_redraw()

var _lights: Array[PointLight2D] = []
var _hum: AudioStreamPlayer2D
var _timer := 0.0
var _on := true  # для мигания: горит ли сейчас


func _ready() -> void:
	if Engine.is_editor_hint():
		return  # в редакторе только рисуем
	add_to_group("lamps")
	if not lit:
		return  # у выключенной лампы нет света и гула
	material = LightTextures.unshaded()  # сама трубка видна и в темноте
	# Длинная трубка светит двумя «точками» по её длине — так свет вытянут вдоль стены
	for x in [-length / 4.0, length / 4.0]:
		var light := LightTextures.make_light(LightTextures.radial(), LIGHT_RANGE, _color(), ENERGY)
		light.position = Vector2(x, LIGHT_DEPTH)
		add_child(light)
		_lights.append(light)
	# Тихий гул неона: слышно, только если стоять рядом
	_hum = AudioStreamPlayer2D.new()
	_hum.stream = Game.get_sound("neon_hum")
	_hum.volume_db = -16.0
	_hum.max_distance = 100.0
	_hum.autoplay = true
	add_child(_hum)


func _process(delta: float) -> void:
	if not flicker or _lights.is_empty():
		return
	_timer -= delta
	if _timer <= 0.0:
		# Случайно то горит, то почти гаснет — как неисправный неон
		_on = randf() > 0.35
		for light in _lights:
			light.energy = ENERGY if _on else 0.05
		_hum.volume_db = -16.0 if _on else -40.0  # погасла — затихла
		_timer = randf_range(0.03, 0.3)
		queue_redraw()


## Сцена закрывается — глушим зацикленный гул, чтобы он не «повис» в звуковой системе.
func _exit_tree() -> void:
	if _hum:
		_hum.stop()


func _color() -> Color:
	return COLORS[color_index % COLORS.size()]


func _draw() -> void:
	var color := _color()
	if Engine.is_editor_hint():
		# В редакторе: примерная область света перед стеной
		for x in [-length / 4.0, length / 4.0]:
			draw_arc(Vector2(x, LIGHT_DEPTH), LIGHT_RANGE * 0.7, 0.0, TAU, 32, Color(color, 0.25), 1.0)
	var brightness := 1.0
	if not lit:
		brightness = 0.25
	elif not _on:
		brightness = 0.3
	var tube := Rect2(-length / 2.0, 0.0, length, TUBE_WIDTH)
	if lit and _on:
		draw_rect(tube.grow(2.0), Color(color, 0.3))   # ореол вокруг трубки
	draw_rect(tube, color * brightness)
	draw_rect(Rect2(tube.position + Vector2(1, 1), Vector2(length - 2, 1)),
			color.lightened(0.6) * brightness)             # яркая сердцевина
