@tool  # рисуется и в редакторе, чтобы укрытие было видно при расстановке
class_name HideSpot
extends Node2D
## Укрытие: шкаф, шкафчик, ванна, место под кроватью или машиной, мусорный бак, за стеллажом.
## Спрятаться и вылезти — E / ПКМ рядом. Спрятавшегося героя враги не видят,
## если только не заметили, как он туда залез. Вылезает герой туда же, откуда залез.
##
## Как поставить: перетащи scenes/props/hide_spot.tscn в сцену (лучше в Props/HideSpots),
## выбери вид (kind) и размер (size).
## Шкаф, шкафчик и ванна рисуются сами. Кровать, машина, бак и стеллаж — это мебель
## (scripts/furniture.gd), поэтому укрытие кладут прямо поверх неё, того же размера:
## само оно тогда ничего не рисует, только глаза спрятавшегося героя.

# Новые виды добавляем только в конец: в сценах вид хранится номером
enum Kind { WARDROBE, LOCKER, BATH, BED, CAR, DUMPSTER, SHELF }

## Какой звук при входе и выходе
const SOUNDS := {
	Kind.WARDROBE: "wardrobe", Kind.LOCKER: "bin_lid", Kind.BATH: "rustle",
	Kind.BED: "rustle", Kind.CAR: "rustle", Kind.DUMPSTER: "bin_lid", Kind.SHELF: "rustle",
}
const INTERACT_GAP := 10.0  # с какого расстояния от края укрытия можно в него залезть

const WOOD := Color(0.28, 0.16, 0.1)
const WOOD_EDGE := Color(0.55, 0.36, 0.22)
const METAL := Color(0.36, 0.42, 0.5)
const METAL_EDGE := Color(0.62, 0.68, 0.74)
const EYES := Color(1, 1, 1, 0.85)

## Вид укрытия
@export var kind := Kind.WARDROBE:
	set(value):
		kind = value
		queue_redraw()
## Размер в пикселях (ширина, высота)
@export var size := Vector2(14, 14):
	set(value):
		size = value
		queue_redraw()

## Сидит ли кто-то внутри (меняет герой)
var occupied := false:
	set(value):
		occupied = value
		queue_redraw()
## Откуда выглядывает спрятавшийся (точка на краю, в своих координатах)
var _peek_point := Vector2.ZERO


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("hide_spots")  # по этой группе укрытия находят герой и хозяин
		# Шкаф, шкафчик и ванна — свои предметы, им нужна своя обводка для теней.
		# Остальные укрытия лежат на мебели, у которой обводка уже есть
		if kind in [Kind.WARDROBE, Kind.LOCKER, Kind.BATH]:
			add_child(LightTextures.make_occluder(LightTextures.rect_points(size),
					LightTextures.SHADOW_LAYER_WALK_THROUGH))


## Расстояние от точки до края укрытия (0 — точка внутри).
func distance_to_point(point: Vector2) -> float:
	var local := to_local(point)
	return local.clamp(-size / 2.0, size / 2.0).distance_to(local)


## Герой залез внутрь со стороны from_pos.
func enter(from_pos: Vector2) -> void:
	occupied = true
	# Глаза выглядывают с того края, с которого залезли
	_peek_point = to_local(from_pos).clamp(-size / 2.0 + Vector2(3, 3), size / 2.0 - Vector2(3, 3))
	Game.play_sound(SOUNDS[kind], Vector2.INF, -6.0)


func leave() -> void:
	occupied = false
	Game.play_sound(SOUNDS[kind], Vector2.INF, -8.0)


func _draw() -> void:
	var r := Rect2(-size / 2.0, size)
	if kind in [Kind.WARDROBE, Kind.LOCKER, Kind.BATH]:  # у кровати, машины и бака тень рисует мебель
		draw_rect(Rect2(r.position + Depth.offset(self), r.size), Depth.COLOR)
	match kind:
		Kind.WARDROBE:
			draw_rect(r, WOOD)
			draw_rect(r, WOOD_EDGE, false, 1.0)
			draw_line(Vector2(0, r.position.y), Vector2(0, r.end.y), WOOD_EDGE, 1.0)  # щель между створками
		Kind.LOCKER:
			draw_rect(r, METAL)
			draw_rect(r, METAL_EDGE, false, 1.0)
			for i in 3:  # вентиляционные прорези
				var y := r.position.y + 3.0 + i * 2.0
				draw_line(Vector2(r.position.x + 3, y), Vector2(r.end.x - 3, y), METAL.darkened(0.5), 1.0)
		Kind.BATH:
			draw_rect(r, Color(0.86, 0.88, 0.9))                                  # ванна
			draw_rect(r.grow(-2), Color(0.66, 0.74, 0.8))                         # внутри
			draw_line(r.position, Vector2(r.position.x, r.end.y), Color(0.45, 0.6, 0.55), 2.0)  # шторка
			if occupied:
				draw_rect(r.grow(-1), Color(0.45, 0.6, 0.55, 0.85))              # шторка задёрнута
		_:
			# Кровать, машина, бак рисует мебель. В редакторе — пунктир, чтобы укрытие было видно
			if Engine.is_editor_hint():
				draw_rect(r, Color(1, 0.9, 0.3, 0.6), false, 1.0)
	if occupied:
		var eyes := _peek_point
		if kind == Kind.WARDROBE or kind == Kind.LOCKER:
			eyes = Vector2.ZERO  # из щели посередине
		# Из укрытия поблёскивают глаза
		draw_circle(eyes + Vector2(-1.5, -1), 0.8, EYES)
		draw_circle(eyes + Vector2(1.5, -1), 0.8, EYES)
