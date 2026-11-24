extends TileMapLayer
## Карта уровня (слой тайлов) + всё, что из неё вычисляется:
## поиск пути в обход стен (для хозяина мотеля), тени от стен и их «объём».
##
## Карты рисуются мышкой прямо в редакторе Godot (см. README, «Как рисовать карту»).
## При запуске уровня main.gd вызывает setup(), и карта сама строит поиск пути и тени
## по нарисованным тайлам.
##
## Старые тестовые карты (бой и стелс) по-прежнему заданы текстом в MAPS
## и собираются через build(). Обозначения в тексте:
##   #  — стена (сквозь неё не пройти, не видно и не светит)
##   .  — пол в помещении        ,  — бетон (галерея, двор)
##   :  — асфальт (парковка)     ~  — дно пустого бассейна
##   =  — низкое препятствие: мебель, машина, бортик (не пройти, но видно поверх)
##   _  — шоссе                  -  — шоссе с разметкой
##   P  — место появления героя
##   G  — постоялец (Guest)
##   W  — ночной сторож (Watchman)
##   O  — хозяин мотеля (Owner)
##   1..9 — точки маршрута хозяина (обходит их по порядку номеров)
##   c  — монтировка (crowbar), b — бита (bat), v — бутылка (bottle)
##   H  — шкаф, в котором можно спрятаться (Hide)
##   K  — ключи от машины (Key)
##   X  — выход к машине (eXit), работает только с ключами
##   L  — неоновая лампа, l — мигающая неоновая лампа
##   пробел — пустота (ничего не рисуется)
## Под символами героя, врагов и предметов кладётся пол.

# Координаты тайлов в картинке assets/tiles/greybox_tiles.png
# (картинку рисует tools/generate_tiles.py, порядок тайлов совпадает)
const FLOOR_TILE := Vector2i(0, 0)
const WALL_TILE := Vector2i(1, 0)
const CONCRETE_TILE := Vector2i(2, 0)
const ASPHALT_TILE := Vector2i(3, 0)
const POOL_TILE := Vector2i(4, 0)
const LOW_TILE := Vector2i(5, 0)
const ROAD_TILE := Vector2i(6, 0)
const ROAD_LINE_TILE := Vector2i(7, 0)
const BASEMENT_TILE := Vector2i(8, 0)  # пол подвала
const PUDDLE_TILE := Vector2i(9, 0)    # лужа: под ногами хлюпает, это слышно
const SOURCE_ID := 0

## Какой символ текстовой схемы каким тайлом рисуется
const SYMBOL_TILES := {
	"#": WALL_TILE, ".": FLOOR_TILE, ",": CONCRETE_TILE, ":": ASPHALT_TILE,
	"~": POOL_TILE, "=": LOW_TILE, "_": ROAD_TILE, "-": ROAD_LINE_TILE,
}

# Тестовые схемы: коридор мотеля и номера по обе стороны от него
const MAPS := {
	# Боевая петля: постояльцы, сторож, оружие
	"combat_test": [
		"################################################",
		"#....L.....#....l.....#....L.....#......L......#",
		"#..........#..........#.....b....#.............#",
		"#....L.....#....L.....#....l.....#......L......#",
		"#....P.....#..........#..........#......G......#",
		"#.......c..#..G.......#..........#.............#",
		"#..........#..........#..........#.............#",
		"####..##########..#########..#########..########",
		"#...........L....................l.............#",
		"#....................W.........................#",
		"#..............................................#",
		"####..##########..#########..#########..########",
		"#..........#..........#..........#.............#",
		"#..........#..........#..........#.......G.....#",
		"#..........#..........#..........#.............#",
		"#..........#....c.....#..........#.............#",
		"#..........#..........#..........#.............#",
		"################################################",
	],
	# Петля-«жертва»: хозяин, шкафы, бутылки, ключи и выход
	"stealth_test": [
		"################################################",
		"#..........#..........#..........#......l......#",
		"#..H.......#.......H..#..........#..H..........#",
		"#..........#..........#.....3....#.............#",
		"#....P.....#..........#..........#.............#",
		"#..........#....v.....#........H.#.............#",
		"#..........#..........#..........#.............#",
		"####..##########..#########..#########..########",
		"#...........l....................L.............#",
		"X......1...........O.....v...............2.....#",
		"#..............................................#",
		"####..##########..#########..#########..########",
		"#..........#..........#..........#.............#",
		"#..H.......#..........#.......H..#.......4.....#",
		"#..........#....v.....#..........#.............#",
		"#..........#..........#..........#..........K..#",
		"#.......H..#..........#....L.....#..H..........#",
		"################################################",
	],
}

# Сюда запишутся координаты точек появления (в пикселях) — только для текстовых карт
var player_spawn := Vector2.ZERO
## Всё остальное, что надо расставить: список пар [символ, позиция]
var spawns: Array = []
## Точки маршрута хозяина, уже отсортированные по номеру
var patrol_points: Array[Vector2] = []

# AStarGrid2D — встроенный в Godot поиск кратчайшего пути по сетке клеток
var _astar := AStarGrid2D.new()
# Клетки, занятые мебелью (Furniture): клетка -> true
var _furniture_cells := {}


## Строит тестовую карту по текстовой схеме с именем map_name (из MAPS).
func build(map_name: String) -> void:
	build_from_rows(MAPS[map_name])


## Рисует тайлы по текстовой схеме (список строк) и запоминает,
## где кого поставить (player_spawn, spawns, patrol_points).
func build_from_rows(rows: Array) -> void:
	clear()
	spawns.clear()
	patrol_points.clear()
	var numbered_points := {}  # номер точки маршрута -> позиция

	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			var symbol := line[x]
			var cell := Vector2i(x, y)
			if symbol == " ":
				continue
			# Известный символ — свой тайл; герой, враги, предметы стоят на полу
			set_cell(cell, SOURCE_ID, SYMBOL_TILES.get(symbol, FLOOR_TILE))

			# map_to_local даёт центр клетки в пикселях
			var pos := map_to_local(cell)
			if symbol == "P":
				player_spawn = pos
			elif symbol.is_valid_int():
				numbered_points[symbol.to_int()] = pos
			elif not SYMBOL_TILES.has(symbol):
				spawns.append([symbol, pos])

	# Точки маршрута — по возрастанию номеров
	var numbers := numbered_points.keys()
	numbers.sort()
	for n in numbers:
		patrol_points.append(numbered_points[n])


## Готовит карту к игре: поиск пути и тени от стен по нарисованным тайлам.
## Вызывается из main.gd при запуске уровня.
func setup() -> void:
	var area := get_used_rect()
	_collect_furniture_cells()
	_build_pathfinding(area)
	_build_light_occluders(area)
	# Контур, «высота» и тени стен (см. wall_decor.gd)
	var decor := WallDecor.new()
	decor.room = self
	add_child(decor)


## Стоит ли точка pos (в пикселях) в луже.
func is_puddle(pos: Vector2) -> bool:
	return get_cell_atlas_coords(local_to_map(to_local(pos))) == PUDDLE_TILE


## Можно ли ходить по клетке: есть тайл, это не стена и не препятствие, и на ней нет мебели.
func is_walkable(cell: Vector2i) -> bool:
	if get_cell_source_id(cell) == -1:
		return false  # пустота
	if _furniture_cells.has(cell):
		return false
	var tile := get_cell_atlas_coords(cell)
	return tile != WALL_TILE and tile != LOW_TILE


## Запоминаем клетки, которые хотя бы частично заняты мебелью.
func _collect_furniture_cells() -> void:
	_furniture_cells.clear()
	var tile := Vector2(tile_set.tile_size)
	for item in get_tree().get_nodes_in_group("obstacles"):
		# Чуть ужимаем прямоугольник, чтобы касание края клетки не считалось
		var rect: Rect2 = item.get_world_rect().grow(-1.0)
		var first := Vector2i((rect.position / tile).floor())
		var last := Vector2i((rect.end / tile).floor())
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				_furniture_cells[Vector2i(x, y)] = true


## Тени от стен. У каждой стены своя обводка (замкнутый LightOccluder2D):
##   • сплошные стены режем на прямоугольные отрезки, и каждый закрываем целиком —
##     свет на стену не попадает, тень идёт строго от её краёв (LightTextures.CLOSED_CULL);
##   • отдельно стоящие куски стены (колонны галереи и логова) — это предметы на локации:
##     они освещены со стороны лампы, а за ними тень (LightTextures.OBJECT_CULL).
const PILLAR_MAX_CELLS := 16  # кусок стены не больше стольких клеток и без соседей — колонна

func _build_light_occluders(area: Rect2i) -> void:
	for old in get_children():
		if old is LightOccluder2D:
			old.queue_free()
	var tile := Vector2(tile_set.tile_size)
	var seen := {}
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if seen.has(cell) or get_cell_atlas_coords(cell) != WALL_TILE:
				continue
			var piece := _wall_piece(cell, seen)
			var bounds := Rect2i(piece[0], Vector2i.ONE)
			for c in piece:
				bounds = bounds.expand(c).merge(Rect2i(c, Vector2i.ONE))
			if piece.size() <= PILLAR_MAX_CELLS and piece.size() == bounds.get_area():
				# Колонна: одна обводка-предмет
				add_child(LightTextures.make_occluder(LightTextures.rect_points(
						Vector2(bounds.size) * tile, (Vector2(bounds.position) + Vector2(bounds.size) / 2.0) * tile)))
			else:
				for rect in _split_into_rects(piece):
					add_child(LightTextures.make_occluder(LightTextures.rect_points(
							Vector2(rect.size) * tile, (Vector2(rect.position) + Vector2(rect.size) / 2.0) * tile),
							LightTextures.SHADOW_LAYER_WALLS, LightTextures.CLOSED_CULL))


## Все клетки стены, связанные с start (соседи по сторонам). Помечает их в seen.
func _wall_piece(start: Vector2i, seen: Dictionary) -> Array[Vector2i]:
	var piece: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		piece.append(cell)
		for side in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + side
			if not seen.has(next) and get_cell_atlas_coords(next) == WALL_TILE:
				seen[next] = true
				queue.append(next)
	return piece


## Режем кусок стены на прямоугольники: берём полосу вправо, потом тянем её вниз,
## пока строка ниже такая же. Каждый прямоугольник — отдельный отрезок стены со своей обводкой.
func _split_into_rects(piece: Array[Vector2i]) -> Array[Rect2i]:
	var left := {}
	for c in piece:
		left[c] = true
	var cells := piece.duplicate()
	cells.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	var rects: Array[Rect2i] = []
	for c: Vector2i in cells:
		if not left.has(c):
			continue
		var width := 1
		while left.has(c + Vector2i(width, 0)):
			width += 1
		var height := 1
		while true:
			var row_ok := true
			for dx in width:
				if not left.has(c + Vector2i(dx, height)):
					row_ok = false
					break
			if not row_ok:
				break
			height += 1
		for dy in height:
			for dx in width:
				left.erase(c + Vector2i(dx, dy))
		rects.append(Rect2i(c, Vector2i(width, height)))
	return rects


## Готовим сетку для поиска пути: стены, препятствия и пустота непроходимы.
func _build_pathfinding(area: Rect2i) -> void:
	_astar.region = area
	_astar.cell_size = Vector2(tile_set.tile_size)
	_astar.offset = _astar.cell_size / 2.0  # путь проходит через центры клеток
	# По диагонали — только если не задеваем угол стены
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if not is_walkable(cell):
				_astar.set_point_solid(cell, true)


## Кратчайший путь между двумя точками (в пикселях) в обход стен.
## Возвращает список точек; пустой — если пути нет.
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := local_to_map(from)
	var goal := local_to_map(to)
	if not _astar.is_in_boundsv(start) or not _astar.is_in_boundsv(goal):
		return PackedVector2Array()
	if _astar.is_point_solid(start) or _astar.is_point_solid(goal):
		return PackedVector2Array()
	return _astar.get_point_path(start, goal)
