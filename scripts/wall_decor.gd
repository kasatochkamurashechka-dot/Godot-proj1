class_name WallDecor
extends Node2D
## «Объёмные» стены в духе Hotline Miami. Рисуется поверх тайлов карты при запуске уровня:
##   • тёмный контур по краю стены — однотонные клетки сливаются в сплошную стену;
##   • боковая грань снизу стены — кажется, что стена имеет высоту и мы смотрим чуть сверху;
##   • мягкая тень справа и снизу — стена «стоит» над полом.
## Создаёт room.gd (setup). Тайлы стен сами по себе однотонные (tools/generate_tiles.py).

const FACE_HEIGHT := 5.0                      # высота боковой грани в пикселях
const SIDE_COLOR := Color(0.47, 0.38, 0.55)   # боковая грань
const SIDE_DARK := Color(0.3, 0.23, 0.36)     # нижняя кромка грани
const OUTLINE_COLOR := Color(0.27, 0.2, 0.34) # контур верха стены
const SHADOW_COLOR := Color(0, 0, 0, 0.28)    # тень стены на полу

var room: TileMapLayer


func _draw() -> void:
	var tile := float(room.tile_set.tile_size.x)
	var area: Rect2i = room.get_used_rect()
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if not _is_wall(cell):
				continue
			var pos := Vector2(x, y) * tile
			var below := cell + Vector2i.DOWN
			var right := cell + Vector2i.RIGHT
			# Тени: справа и снизу (под гранью)
			if not _is_wall(right) and _is_ground(right):
				draw_rect(Rect2(pos + Vector2(tile, 3), Vector2(3, tile)), SHADOW_COLOR)
			if not _is_wall(below) and _is_ground(below):
				draw_rect(Rect2(pos + Vector2(3, tile + FACE_HEIGHT), Vector2(tile, 3)), SHADOW_COLOR)
				# Боковая грань стены
				draw_rect(Rect2(pos + Vector2(0, tile), Vector2(tile, FACE_HEIGHT)), SIDE_COLOR)
				draw_rect(Rect2(pos + Vector2(0, tile + FACE_HEIGHT - 1), Vector2(tile, 1)), SIDE_DARK)
			# Контур: линия по каждой стороне, за которой уже не стена
			for side in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if _is_wall(cell + side):
					continue
				match side:
					Vector2i.UP: draw_rect(Rect2(pos, Vector2(tile, 1)), OUTLINE_COLOR)
					Vector2i.DOWN: draw_rect(Rect2(pos + Vector2(0, tile - 1), Vector2(tile, 1)), OUTLINE_COLOR)
					Vector2i.LEFT: draw_rect(Rect2(pos, Vector2(1, tile)), OUTLINE_COLOR)
					Vector2i.RIGHT: draw_rect(Rect2(pos + Vector2(tile - 1, 0), Vector2(1, tile)), OUTLINE_COLOR)


func _is_wall(cell: Vector2i) -> bool:
	return room.get_cell_atlas_coords(cell) == room.WALL_TILE


## Есть ли в клетке пол (а не пустота за краем карты)
func _is_ground(cell: Vector2i) -> bool:
	return room.get_cell_source_id(cell) != -1
