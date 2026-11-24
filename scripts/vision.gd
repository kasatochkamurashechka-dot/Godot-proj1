class_name Vision
extends CanvasLayer
## Поле зрения героя: видно только то, что рядом и не загорожено стенами.
##
## Как это работает:
##   1. Каждый кадр из героя во все стороны пускаем лучи (RAYS штук) до первой стены
##      (закрытая дверь тоже стена). Получается «многоугольник видимости».
##   2. Рисуем его белым на чёрном в отдельной невидимой картинке (SubViewport, «маска»).
##      Чем дальше от героя, тем серее — так край зрения плавно уходит в темноту.
##   3. Эту маску кладём поверх всей игры с режимом смешивания «умножение»:
##      белое оставляет картинку как есть, чёрное делает её тёмной.
## За стенами, за закрытыми дверьми и вдали поэтому темно, даже если там горит лампа.
## Стены показываем отдельно, по клеткам карты: клетка стены видна, если рядом с ней есть
## пол, который герой видит. Яркость считается в каждом углу клетки по расстоянию до героя,
## поэтому стена гаснет плавно. (Раньше клетка стены показывалась, только если в неё
## попал луч, — при взгляде вдоль стены лучи попадали через клетку, и по стене «бегали»
## чёрные квадратики.)
## Маска рисуется в полном размере экрана и размывается шейдером shaders/vision_blur.gdshader —
## так край поля зрения мягкий и без «лесенки». (Уменьшенная маска давала ступеньки 4×4 пикселя
## на краю тени от колонн.)
## С включённым фонариком (F) по направлению взгляда видно дальше и ярче.
##
## Слои экрана: игра (0) → эта маска (2) → значки звуков (3) → VHS-эффект (5) → интерфейс (10).

const RAYS := 240               # сколько лучей: больше — ровнее край, но дороже
const NEAR := 40.0              # до этого расстояния видно полностью
const FAR := 65.0               # дальше этого — темно
const BRIGHTNESS := 0.75        # яркость поля зрения без фонарика (1 — как есть, меньше — тусклее)
const FLASH_NEAR := 150.0       # то же вдоль луча включённого фонарика
const FLASH_FAR := 215.0
const FLASH_BRIGHTNESS := 1.0
const FLASH_SOFT := 10.0        # мягкость краёв луча фонарика, в градусах
const WALL_PEEK := 2.0          # чуть заходим за край стены (саму клетку стены рисуем отдельно)
const DOOR_PEEK := 4.0          # в дверь — заходим немного, она тонкая
const OUTSIDE := 0.05           # яркость того, что вне поля зрения (0 — чёрное)
const BLUR_RADIUS := 4.0        # мягкость края зрения: радиус размытия в пикселях экрана
const BLUR_SHADER := preload("res://shaders/vision_blur.gdshader")

var _player: Player
var _room: TileMapLayer
var _mask: SubViewport
var _drawer: MaskDrawer


## Рисовальщик маски: живёт внутри SubViewport и рисует треугольники видимости.
class MaskDrawer extends Node2D:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var size := Vector2.ZERO
	var outside := 0.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(outside, outside, outside))
		if indices.size() > 0:
			RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colors)


func _ready() -> void:
	layer = 2
	_player = get_tree().get_first_node_in_group("player") as Player
	_room = get_tree().get_first_node_in_group("room") as TileMapLayer
	var screen_size := get_viewport().get_visible_rect().size
	_mask = SubViewport.new()
	_mask.size = Vector2i(screen_size)
	_mask.disable_3d = true
	_mask.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_mask)
	_drawer = MaskDrawer.new()
	_drawer.size = screen_size
	_drawer.outside = OUTSIDE
	_mask.add_child(_drawer)
	# Картинка-маска поверх игры: шейдер размывает её и умножает на неё всё, что под ней
	var overlay := TextureRect.new()
	overlay.texture = _mask.get_texture()
	overlay.size = screen_size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var blur := ShaderMaterial.new()
	blur.shader = BLUR_SHADER
	blur.set_shader_parameter("blur_radius", BLUR_RADIUS)
	overlay.material = blur
	add_child(overlay)


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	var origin := _player.global_position
	var space := _player.get_world_2d().direct_space_state
	# Из координат мира в координаты экрана (учитывает камеру и её тряску)
	var to_screen := get_viewport().get_canvas_transform()

	var center_brightness := _brightness(_player.facing())
	var points := PackedVector2Array([to_screen * origin])
	var colors := PackedColorArray([_gray(minf(center_brightness, BRIGHTNESS))])
	for i in RAYS:
		var dir := Vector2.RIGHT.rotated(TAU * i / RAYS)
		var reach := _reach(dir)  # x — ближняя граница, y — дальняя
		var bright := _brightness(dir)
		var query := PhysicsRayQueryParameters2D.create(origin, origin + dir * reach.y, 1)  # 1 — стены и двери
		var hit := space.intersect_ray(query)
		var distance := reach.y
		if not hit.is_empty():
			var peek := DOOR_PEEK if hit.collider is Door else WALL_PEEK
			distance = minf(reach.y, origin.distance_to(hit.position) + peek)
		# Две точки на каждый луч: до ближней границы — полностью видно, дальше — темнеет
		var near := minf(distance, reach.x)
		points.append(to_screen * (origin + dir * near))
		colors.append(_gray(bright))
		points.append(to_screen * (origin + dir * distance))
		colors.append(_gray(lerpf(OUTSIDE, bright, _fade(distance, reach))))

	# Треугольники: центр + ближние точки соседних лучей, и «лента» между ближними и дальними
	var indices := PackedInt32Array()
	for i in RAYS:
		var j := (i + 1) % RAYS
		var near_i := 1 + i * 2
		var far_i := near_i + 1
		var near_j := 1 + j * 2
		var far_j := near_j + 1
		indices.append_array([0, near_i, near_j])
		indices.append_array([near_i, far_i, far_j])
		indices.append_array([near_i, far_j, near_j])
	if _room:
		_add_visible_walls(origin, space, to_screen, points, colors, indices)
	_drawer.points = points
	_drawer.colors = colors
	_drawer.indices = indices
	_drawer.queue_redraw()


## Клетки стен рядом с видимым полом — целиком, двумя треугольниками каждая.
## Яркость в каждом углу своя (по расстоянию и направлению от героя): у соседних клеток
## общие углы одинаковой яркости, поэтому стена гаснет плавно, без ступенек.
func _add_visible_walls(origin: Vector2, space: PhysicsDirectSpaceState2D, to_screen: Transform2D,
		points: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var tile := Vector2(_room.tile_set.tile_size)
	var radius := int(ceil(FLASH_FAR / tile.x)) + 1
	var center := _room.local_to_map(_room.to_local(origin))
	var seen_floor := {}  # клетка пола -> видна ли (считаем один раз за кадр)
	var corner_index := {}  # угол клетки (в клетках) -> номер точки, чтобы соседние клетки делили углы
	# Проёмы закрытых дверей показываем так же, как стену: иначе в стене тёмная «дырка» с клетку
	var door_cells := _closed_door_cells()
	# 1) Клетки стен (и закрытых дверей), рядом с которыми есть видимый пол.
	#    Только по полу, а не по попаданию отдельных лучей: попадание лучей при взгляде
	#    вдоль стены случайно, из-за него клетки и «мигали»
	var visible := {}
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var cell := Vector2i(x, y)
			if not _is_solid(cell, door_cells):
				continue
			for side in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if not door_cells.has(cell + side) and _floor_seen(cell + side, origin, space, seen_floor):
					visible[cell] = true
					break
	# 2) Стыки и углы: клетка стены, примыкающая к видимой стене, тоже видна (один шаг,
	#    чтобы видимость не «протекала» по стенам в соседние комнаты). Без этого на стыках
	#    стен оставались тёмные квадраты — у такой клетки соседний пол есть только наискосок.
	var joints := []
	for cell: Vector2i in visible:
		for side in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + side
			if not visible.has(next) and _is_solid(next, door_cells):
				joints.append(next)
	for cell in joints:
		visible[cell] = true
	# Рисуем: два треугольника на клетку, общие углы — общие точки
	for cell: Vector2i in visible:
		var ids := []
		for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var key: Vector2i = cell + corner
			if not corner_index.has(key):
				var world := _room.to_global(Vector2(key) * tile)
				corner_index[key] = points.size()
				points.append(to_screen * world)
				colors.append(_gray(_brightness_at(world, origin)))
			ids.append(corner_index[key])
		indices.append_array([ids[0], ids[1], ids[2], ids[0], ids[2], ids[3]])


## Клетка — стена или проём закрытой двери (для маски зрения это одно и то же).
func _is_solid(cell: Vector2i, door_cells: Dictionary) -> bool:
	return door_cells.has(cell) or _room.get_cell_atlas_coords(cell) == _room.WALL_TILE


## Клетки, которые сейчас закрывают двери (проёмы закрытых дверей).
func _closed_door_cells() -> Dictionary:
	var cells := {}
	var tile := float(_room.tile_set.tile_size.x)
	for door: Door in get_tree().get_nodes_in_group("doors"):
		if door.is_open:
			continue
		for i in door.length:
			# Центр i-й клетки проёма вдоль двери (дверь лежит вдоль своей оси X)
			var local := Vector2(-door.length * tile / 2.0 + tile / 2.0 + i * tile, 0)
			cells[_room.local_to_map(_room.to_local(door.to_global(local)))] = true
	return cells


## Видит ли герой клетку пола: между ними нет стены (дальность тут не важна —
## далёкая стена и так гаснет по яркости углов, а резкий обрыв по клетке дал бы «ступеньку»).
func _floor_seen(cell: Vector2i, origin: Vector2, space: PhysicsDirectSpaceState2D, cache: Dictionary) -> bool:
	if cache.has(cell):
		return cache[cell]
	var result := false
	if _room.get_cell_source_id(cell) != -1 and _room.get_cell_atlas_coords(cell) != _room.WALL_TILE:
		var target := _room.to_global(_room.map_to_local(cell))
		if target.distance_to(origin) <= FLASH_FAR + 16.0:
			# Центр и четыре точки у углов: клетку видно, даже если её центр закрыт углом стены
			for offset in [Vector2.ZERO, Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5)]:
				var query := PhysicsRayQueryParameters2D.create(origin, target + offset, 1)
				if space.intersect_ray(query).is_empty():
					result = true
					break
	cache[cell] = result
	return result


## Яркость маски в точке мира: по направлению (фонарик) и расстоянию от героя.
func _brightness_at(world: Vector2, origin: Vector2) -> float:
	var offset := world - origin
	var dir := offset.normalized() if offset.length() > 0.01 else _player.facing()
	return lerpf(OUTSIDE, _brightness(dir), _fade(offset.length(), _reach(dir)))


## Насколько светло в направлении dir: по лучу фонарика ярче, чем просто вокруг.
func _brightness(dir: Vector2) -> float:
	return lerpf(BRIGHTNESS, FLASH_BRIGHTNESS, _flash_amount(dir))


## Видимость на расстоянии distance: 1 — до ближней границы, 0 — за дальней.
func _fade(distance: float, reach: Vector2) -> float:
	return 1.0 - clampf((distance - reach.x) / (reach.y - reach.x), 0.0, 1.0)


func _gray(value: float) -> Color:
	return Color(value, value, value)


## Насколько направление dir попадает в луч фонарика: 1 — в луче, 0 — вне (края плавные).
func _flash_amount(dir: Vector2) -> float:
	if not _player.flashlight_on or _player.is_hidden or _player.is_dead:
		return 0.0
	var angle := rad_to_deg(absf(_player.facing().angle_to(dir)))
	return clampf((Player.FLASHLIGHT_ANGLE + FLASH_SOFT - angle) / FLASH_SOFT, 0.0, 1.0)


## Насколько далеко видно в направлении dir: Vector2(ближняя граница, дальняя граница).
func _reach(dir: Vector2) -> Vector2:
	# Вдоль луча фонарика видно дальше, края луча плавные
	return Vector2(NEAR, FAR).lerp(Vector2(FLASH_NEAR, FLASH_FAR), _flash_amount(dir))
