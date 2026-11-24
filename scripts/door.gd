@tool  # рисуется и в редакторе, чтобы дверь было видно при расстановке
class_name Door
extends StaticBody2D
## Дверь в проёме стены.
##
## Закрытая дверь работает как стена: сквозь неё не пройти, не видно и не светит.
## Открыть: упереться в неё (толкнуть) или нажать E / ПКМ рядом. Закрыть — E / ПКМ.
## Если открывать не крадучись, скрип слышит хозяин.
## Враги тоже открывают двери, когда упираются в них.
## Запертую дверь (locked) герой и постояльцы открыть не могут, а хозяин может:
## у него ключи от всего мотеля. За ним запертая дверь сама закрывается.
##
## Как поставить: перетащи scenes/props/door.tscn в сцену (лучше в Props/Doors)
## и поставь центр двери в центр проёма. Дверь лежит горизонтально;
## для проёма в вертикальной стене поверни узел на 90°.

const TILE := 16.0
const THICKNESS := 6.0       # толщина закрытой двери в пикселях
const NOISE_RADIUS := 90.0   # как далеко слышно, когда герой открывает дверь не крадучись
const SWING_TIME := 0.18     # за сколько секунд дверь распахивается
const RELOCK_DELAY := 1.5    # через сколько секунд запертая дверь закрывается за хозяином
const HINT_COOLDOWN := 0.8   # чтобы «заперто» не звучало каждый кадр, пока упираемся

const WOOD := Color(0.42, 0.27, 0.17)
const WOOD_EDGE := Color(0.18, 0.11, 0.07)
const HANDLE := Color(0.8, 0.7, 0.4)
const LOCK_COLOR := Color(1.0, 0.3, 0.25)

## Ширина проёма в клетках: 1 — обычная дверь, 2 — двустворчатая
@export_range(1, 3) var length := 1:
	set(value):
		length = value
		_update_shape()
		queue_redraw()
## Заперта ли дверь. В сцене петли можно поставить или снять эту галочку у любой двери
@export var locked := false:
	set(value):
		locked = value
		queue_redraw()
## Открыта ли дверь в начале уровня
@export var is_open := false:
	set(value):
		is_open = value
		# В редакторе и при загрузке сцены — сразу нужное положение, в игре — с анимацией
		if Engine.is_editor_hint() or not is_node_ready():
			_swing = 1.0 if value else 0.0
		_update_shape()
		queue_redraw()

var _swing := 0.0        # 0 — закрыта, 1 — распахнута (для анимации)
var _side := 1.0         # куда распахнулись створки: +1 — вниз, -1 — вверх (в своих координатах)
var _relock_timer := 0.0
var _hint_timer := 0.0
var _collision: CollisionShape2D
var _occluder: LightOccluder2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("doors")  # по этой группе двери находит герой (E рядом с дверью)
	collision_layer = 1    # слой стен: закрытая дверь останавливает всех и закрывает обзор
	collision_mask = 0
	_collision = CollisionShape2D.new()
	_collision.shape = RectangleShape2D.new()
	add_child(_collision)
	# Тень: закрытая дверь не пропускает свет, как стена
	# Контур по часовой стрелке (см. _update_shape): освещается сторона двери, повёрнутая к свету
	_occluder = LightTextures.make_occluder(LightTextures.rect_points(Vector2.ONE))
	add_child(_occluder)
	_update_shape()


## Форма столкновения и тени по ширине двери. Открытая дверь не мешает ни ходьбе, ни свету.
func _update_shape() -> void:
	if _collision == null:
		return  # редактор или сцена ещё загружается
	var half := Vector2(length * TILE, THICKNESS) / 2.0
	(_collision.shape as RectangleShape2D).size = half * 2.0
	_occluder.occluder.polygon = LightTextures.rect_points(half * 2.0)
	_collision.set_deferred("disabled", is_open)
	_occluder.visible = not is_open


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_hint_timer -= delta
	# Плавно поворачиваем створки к нужному положению
	var target := 1.0 if is_open else 0.0
	if _swing != target:
		_swing = move_toward(_swing, target, delta / SWING_TIME)
		queue_redraw()
	# Хозяин прошёл через запертую дверь — она закрывается за ним
	if locked and is_open:
		if is_doorway_blocked():
			_relock_timer = RELOCK_DELAY
		else:
			_relock_timer -= delta
			if _relock_timer <= 0.0:
				close()


## Кто-то упёрся в закрытую дверь. quiet = true — герой крадётся, и хозяин не слышит скрипа.
func push(body: Node2D, quiet := false) -> void:
	if is_open:
		return
	if locked and not body is MotelOwner:
		if body is Player and _hint_timer <= 0.0:
			_hint_timer = HINT_COOLDOWN
			Game.play_sound("door_locked", global_position, -4.0)
			Game.show_hint("HINT_LOCKED")
		return
	open_from(body.global_position, body is EnemyBase)
	if body is Player and not quiet:
		Game.make_noise(global_position, NOISE_RADIUS, 0.6)


## Открыть дверь: створки распахиваются от того, кто открывает (from_pos).
## by_enemy — открыл враг: герой увидит кружок звука, даже если дверь в темноте.
func open_from(from_pos: Vector2, by_enemy := false) -> void:
	if is_open:
		return
	_side = 1.0 if to_local(from_pos).y < 0.0 else -1.0
	_relock_timer = RELOCK_DELAY
	is_open = true
	if by_enemy:
		Game.enemy_sound("door", global_position, -6.0, 320.0, 18.0)
	else:
		Game.play_sound("door", global_position, -6.0)


## Закрыть дверь. Не закрывается, если в проёме кто-то стоит. Возвращает true, если закрылась.
func close() -> bool:
	if not is_open or is_doorway_blocked():
		return false
	is_open = false
	Game.play_sound("door", global_position, -12.0, 0.15)
	return true


## Стоит ли кто-то (герой или живой враг) прямо в проёме.
func is_doorway_blocked() -> bool:
	for group in ["player", "enemies"]:
		for body: Node2D in get_tree().get_nodes_in_group(group):
			if body.get("is_dead"):
				continue
			var local := to_local(body.global_position)
			if absf(local.x) < length * TILE / 2.0 + 2.0 and absf(local.y) < THICKNESS / 2.0 + 8.0:
				return true
	return false


## Расстояние от точки до проёма двери (чтобы понять, стоит ли герой рядом).
func distance_to_point(point: Vector2) -> float:
	var local := to_local(point)
	var half := Vector2(length * TILE, TILE) / 2.0
	return local.clamp(-half, half).distance_to(local)


## Редактор: убираем предупреждение «нет формы столкновения» — форма создаётся при запуске.
func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray()


func _draw() -> void:
	var half_len := length * TILE / 2.0
	# Порог — тёмная полоска в проёме, видна, когда дверь открыта
	draw_rect(Rect2(-half_len, -1.0, half_len * 2.0, 2.0), Color(0.1, 0.08, 0.1, 0.6))
	var angle := _swing * PI / 2.0 * _side
	if length == 1:
		_draw_leaf(Vector2(-half_len, 0), Vector2.RIGHT.rotated(angle), half_len * 2.0)
	else:
		# Двустворчатая: петли с обоих краёв, створки сходятся посередине
		_draw_leaf(Vector2(-half_len, 0), Vector2.RIGHT.rotated(angle), half_len)
		_draw_leaf(Vector2(half_len, 0), Vector2.LEFT.rotated(-angle), half_len)


## Одна створка: от петли hinge в направлении dir, длиной leaf_len.
func _draw_leaf(hinge: Vector2, dir: Vector2, leaf_len: float) -> void:
	var end := hinge + dir * leaf_len
	draw_line(hinge, end, WOOD_EDGE, THICKNESS)
	draw_line(hinge + dir, end - dir, WOOD, THICKNESS - 2.0)
	var handle := hinge + dir * (leaf_len - 4.0)
	if locked:
		# Запертая: красный «замок» вместо ручки
		draw_rect(Rect2(handle - Vector2(2, 2), Vector2(4, 4)), LOCK_COLOR)
	else:
		draw_circle(handle, 1.3, HANDLE)
