class_name MotelOwner
extends EnemyBase
## Хозяин мотеля — главный охотник в петлях-«жертвах». Убить его нельзя.
##
## Поведение (машина состояний):
##   PATROL      — обходит точки маршрута 1, 2, 3... по порядку
##   INVESTIGATE — услышал шум и идёт проверить, что там
##   CHASE       — видит героя (или только что видел) и гонится
##   SEARCH      — потерял героя: стоит, осматривается, потом возвращается на маршрут
## Если видел, как герой залез в укрытие, идёт туда и вытаскивает его.
## Двери открывает сам, даже запертые: у него ключи от всего мотеля.
## Ходит по карте с помощью поиска пути (Room.find_path), а не сквозь стены.

enum State { PATROL, INVESTIGATE, CHASE, SEARCH }

const PATROL_SPEED := 33.0
const INVESTIGATE_SPEED := 52.0
const CHASE_SPEED := 78.0    # медленнее идущего героя (90), но быстрее крадущегося (45)
const VIEW_RANGE := 180.0    # дальность зрения
const VIEW_ANGLE := 40.0     # половина ширины конуса зрения, в градусах
const CLOSE_SENSE := 18.0    # вплотную чувствует героя даже спиной
const CATCH_RANGE := 14.0    # с какого расстояния хватает героя
const SEARCH_TIME := 3.0     # сколько секунд ищет на месте, прежде чем вернуться к маршруту
const WAYPOINT_REACHED := 3.0

# --- Цвета-заглушки ---
const SUIT_COLOR := Color(0.45, 0.3, 0.2)
const HAIR_COLOR := Color(0.75, 0.75, 0.72)
# Цвет «взгляда» (тусклого конуса света перед хозяином) в разных состояниях
const VIEW_COLORS := {
	State.PATROL: Color(0.8, 0.8, 0.9),
	State.INVESTIGATE: Color(1.0, 0.6, 0.15),
	State.CHASE: Color(1.0, 0.1, 0.15),
	State.SEARCH: Color(1.0, 0.6, 0.15),
}
const VIEW_ENERGY := 0.45

## Маршрут для карт из редактора: узел, внутри которого лежат точки (Marker2D).
## Хозяин обходит их по порядку сверху вниз, как они идут в дереве сцены.
@export var patrol_route: Node2D

## Точки маршрута в пикселях. Для текстовых карт их задаёт main.gd,
## для карт из редактора они берутся из patrol_route.
var patrol_points: Array[Vector2] = []
var state := State.PATROL

var _patrol_index := 0
var _path := PackedVector2Array()
var _path_index := 0
var _search_timer := 0.0
var _search_turn := 1.0
var _had_sight := false
var _hide_target := Vector2.ZERO
var _has_hide_target := false
var _room: Node
var _view_light: PointLight2D


func _ready() -> void:
	super()  # EnemyBase находит героя
	counts_for_clear = false  # бессмертного не нужно убивать для зачистки
	material = LightTextures.unshaded()  # значки «?» и «!» видны в темноте
	# Конус зрения показываем тусклым светом: стены его обрезают, сквозь них он не виден
	_view_light = LightTextures.make_light(LightTextures.cone(VIEW_ANGLE), VIEW_RANGE,
			VIEW_COLORS[state], VIEW_ENERGY)
	_view_light.shadow_item_cull_mask = LightTextures.CHARACTER_SHADOW_MASK
	add_child(_view_light)
	_room = get_tree().get_first_node_in_group("room")
	Game.noise_made.connect(_on_noise)
	if patrol_route:
		patrol_points.clear()
		for point in patrol_route.get_children():
			if point is Marker2D:
				patrol_points.append(point.global_position)
	# Откладываем до конца кадра: к этому моменту карта успеет построить поиск пути
	_back_to_patrol.call_deferred()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	if player.is_dead:
		velocity = Vector2.ZERO
		return

	var sees := _sees_player()
	if sees:
		last_seen = player.global_position
		if state != State.CHASE:
			_start_chase()

	match state:
		State.PATROL:
			if _follow_path(PATROL_SPEED):
				_next_patrol_point()
		State.INVESTIGATE:
			if _follow_path(INVESTIGATE_SPEED):
				_start_search()
		State.CHASE:
			_chase(sees)
		State.SEARCH:
			# Стоит и поворачивается, осматриваясь
			velocity = Vector2.ZERO
			rotation += _search_turn * 1.8 * delta
			_search_timer -= delta
			if _search_timer <= 0.0:
				_back_to_patrol()

	_had_sight = sees
	_view_light.color = VIEW_COLORS[state]
	move_and_open_doors()
	play_footsteps(delta, "owner_step", -2.0, 320.0)


## Видит ли хозяин героя: конусом впереди или вплотную с любой стороны.
func _sees_player() -> bool:
	return can_see_player(VIEW_RANGE, VIEW_ANGLE) or can_see_player(CLOSE_SENSE)


func _chase(sees: bool) -> void:
	# Видел, как герой залез в укрытие — идём туда и вытаскиваем
	if _has_hide_target:
		if global_position.distance_to(_hide_target) <= CATCH_RANGE + 4.0:
			_has_hide_target = false
			player.die(Vector2.RIGHT.rotated(rotation))
			return
		_follow_path(CHASE_SPEED)
		return

	if sees:
		# Видим героя — идём прямо на него
		var to_player := player.global_position - global_position
		if to_player.length() <= CATCH_RANGE:
			velocity = Vector2.ZERO
			player.die(to_player.normalized())
			return
		move_to_last_seen(CHASE_SPEED)
		return

	# Только что потеряли из виду — прокладываем путь туда, где видели в последний раз
	if _had_sight or _path_index >= _path.size():
		_go_to(last_seen)
	if _follow_path(CHASE_SPEED):
		_start_search()


## Шум: если слышно, идём проверять. Во время погони без прямой видимости — идём на звук.
func _on_noise(pos: Vector2, radius: float) -> void:
	if player == null or player.is_dead:
		return
	if global_position.distance_to(pos) > radius:
		return
	if state == State.CHASE:
		if not _had_sight and not _has_hide_target:
			last_seen = pos
			_go_to(pos)
		return
	state = State.INVESTIGATE
	_go_to(pos)


## Герой прячется. Если хозяин в этот момент его видит — запомнит место,
## откуда герой залез в укрытие (from_pos), и пойдёт туда.
func notice_hiding(from_pos: Vector2) -> void:
	if _sees_player():
		_start_chase()
		_has_hide_target = true
		_hide_target = from_pos
		_go_to(from_pos)


## Хозяина нельзя убить. Удар только выдаёт героя.
func take_hit(_kind: String, _dir: Vector2) -> void:
	Game.shake(1.0)
	Game.play_sound("punch", global_position, -6.0)
	if player and not player.is_dead and not player.is_hidden:
		last_seen = player.global_position
		_start_chase()


func _start_chase() -> void:
	if state != State.CHASE:
		Game.shake(1.5)  # «он меня заметил!»
		Game.glitch(0.35, 0.4)
		Game.play_sound("spotted", Vector2.INF, -4.0, 0.0)
	state = State.CHASE
	if player and not player.is_hidden:
		last_seen = player.global_position


func _start_search() -> void:
	state = State.SEARCH
	_search_timer = SEARCH_TIME
	_search_turn = 1.0 if randf() < 0.5 else -1.0


func _back_to_patrol() -> void:
	state = State.PATROL
	if patrol_points.size() > 0:
		_go_to(patrol_points[_patrol_index])
	else:
		_path = PackedVector2Array()


func _next_patrol_point() -> void:
	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		return
	_patrol_index = (_patrol_index + 1) % patrol_points.size()
	_go_to(patrol_points[_patrol_index])


## Проложить путь до точки pos в обход стен.
func _go_to(pos: Vector2) -> void:
	if _room == null:
		return
	_path = _room.find_path(global_position, pos)
	# Первая точка пути — клетка, где стоим сейчас; её пропускаем
	_path_index = 1 if _path.size() > 1 else _path.size()


## Идти по проложенному пути. Возвращает true, когда дошли до конца.
func _follow_path(speed: float) -> bool:
	if _path_index >= _path.size():
		velocity = Vector2.ZERO
		return true
	var to_point := _path[_path_index] - global_position
	if to_point.length() < WAYPOINT_REACHED:
		_path_index += 1
		if _path_index >= _path.size():
			velocity = Vector2.ZERO
			return true
		to_point = _path[_path_index] - global_position
	velocity = to_point.normalized() * speed
	rotation = lerp_angle(rotation, to_point.angle(), 0.2)  # плавный поворот головы
	return false


func _draw() -> void:
	if has_node("StoryFigure"):
		return
	draw_circle(Depth.offset(self), 8.0, Depth.COLOR)  # тень
	# Тело: коричневый костюм, седая голова
	draw_circle(Vector2.ZERO, 7.5, SUIT_COLOR)
	draw_circle(Vector2(1, 0), 4.0, HAIR_COLOR)

	# Значок над головой: «?» — что-то услышал, «!» — видит героя.
	# draw_set_transform отменяет поворот, чтобы значок не крутился вместе с хозяином.
	var mark := ""
	var mark_color := Color(1, 0.7, 0.2)
	if state == State.INVESTIGATE or state == State.SEARCH:
		mark = "?"
	elif state == State.CHASE:
		mark = "!"
		mark_color = Color(1, 0.2, 0.25)
	if mark != "":
		draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
		draw_string(ThemeDB.fallback_font, Vector2(-3, -12), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, mark_color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
