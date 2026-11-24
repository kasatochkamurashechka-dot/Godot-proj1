class_name EnemyBase
extends CharacterBody2D
## Общая основа для всех врагов: зрение, память о том, где видели героя,
## удар по герою, падение и смерть. Конкретные враги (Guest, Watchman)
## наследуются от этого скрипта и дописывают своё поведение.

## Сигнал «враг умер» — main.gd считает оставшихся врагов.
signal died

const DOWNED_FRICTION := 700.0  # как быстро тормозит сбитый с ног враг
const STRIKE_ANGLE := 75.0      # удар врага попадает в секторе ±75° перед ним
const STEP_LENGTH := 24.0       # длина шага в пикселях: чем быстрее идёт, тем чаще шаги
const FLASHLIGHT_NOTICE := 0.85 # враг замечает луч фонарика героя на этой доле его дальности

var player: Player
var is_dead := false
## Нужно ли убить этого врага для «FLOOR CLEAR» (бессмертного хозяина не считаем)
var counts_for_clear := true
var is_downed := false

# Память: где последний раз видели героя
var last_seen := Vector2.ZERO
var has_target := false

var _downed_timer := 0.0
var _footstep_timer := 0.0
# Маршрут в обход стен к месту, где видели или слышали героя
var _route := PackedVector2Array()
var _route_goal := Vector2.INF
var _route_index := 0


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Player
	Game.noise_made.connect(_on_noise_made)


## Где-то нашумели. Если враг жив и шум долетел — вызываем hear (её дописывают наследники).
func _on_noise_made(pos: Vector2, radius: float) -> void:
	if is_dead or is_downed or global_position.distance_to(pos) > radius:
		return
	hear(pos)


## Враг услышал шум в точке pos. По умолчанию ничего не делает.
func hear(_pos: Vector2) -> void:
	pass


func _process(_delta: float) -> void:
	queue_redraw()  # заглушки рисуются кодом и анимируются каждый кадр


## Можно ли сейчас ударить этого врага.
func can_be_hit() -> bool:
	return not is_dead


## Получить удар. kind: "fist" — кулак, "melee" — оружие, "throw" — брошенный предмет.
## dir — направление удара. Каждый враг переопределяет эту функцию по-своему.
func take_hit(_kind: String, _dir: Vector2) -> void:
	pass


## Видит ли враг героя: в пределах дистанции, в секторе обзора и без стен между ними.
## half_angle_deg = 180 означает обзор во все стороны.
func can_see_player(max_distance: float, half_angle_deg := 180.0) -> bool:
	if player == null or player.is_dead or player.is_hidden:
		return false
	# Попал в луч фонарика героя — замечает свет, куда бы ни смотрел
	if is_lit_by_flashlight():
		return true
	var to_player := player.global_position - global_position
	if to_player.length() > max_distance:
		return false
	if half_angle_deg < 180.0:
		var facing := Vector2.RIGHT.rotated(rotation)
		if absf(facing.angle_to(to_player)) > deg_to_rad(half_angle_deg):
			return false
	return Game.line_of_sight(global_position, player.global_position)


## Светит ли на врага фонарик героя (враг в луче, и между ними нет стены).
func is_lit_by_flashlight() -> bool:
	if player == null or player.is_dead or player.is_hidden or not player.flashlight_on:
		return false
	var from_player := global_position - player.global_position
	if from_player.length() > Player.FLASHLIGHT_RANGE * FLASHLIGHT_NOTICE:
		return false
	if absf(player.facing().angle_to(from_player)) > deg_to_rad(Player.FLASHLIGHT_ANGLE):
		return false
	return Game.line_of_sight(player.global_position, global_position)


## Если видим героя — запоминаем, где он. Возвращает true, если видим.
func look_for_player(max_distance: float, half_angle_deg := 180.0) -> bool:
	if can_see_player(max_distance, half_angle_deg):
		last_seen = player.global_position
		has_target = true
		return true
	return false


## Идти к месту, где последний раз видели (или слышали) героя. Дошли — забываем.
## Если место видно — идём напрямую, если за стеной — в обход, по карте.
func move_to_last_seen(speed: float) -> void:
	var to_target := last_seen - global_position
	if to_target.length() < 4.0:
		has_target = false
		velocity = Vector2.ZERO
		return
	var step := last_seen
	if not clear_walk_to(last_seen):
		step = _next_route_point()
		if step == Vector2.INF:
			has_target = false  # туда не дойти — бросаем
			velocity = Vector2.ZERO
			return
	var dir := (step - global_position).normalized()
	velocity = dir * speed
	rotation = dir.angle()


## Следующая точка маршрута в обход стен. Vector2.INF — пути нет.
func clear_walk_to(goal: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, goal, 9)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _next_route_point() -> Vector2:
	if _route_goal != last_seen:
		_route_goal = last_seen
		var room := get_tree().get_first_node_in_group("room")
		_route = room.find_path(global_position, last_seen) if room else PackedVector2Array()
		_route_index = 1
	while _route_index < _route.size() and global_position.distance_to(_route[_route_index]) < 4.0:
		_route_index += 1
	if _route_index < _route.size():
		return _route[_route_index]
	return last_seen if _route.size() > 0 else Vector2.INF


## Шаги врага: звук в его точке, а если герой рядом — ещё и кружок звука (виден в темноте).
## Вызывать каждый кадр после движения.
func play_footsteps(delta: float, sound := "step", volume_db := -8.0, max_distance := 220.0) -> void:
	var speed := velocity.length()
	if speed < 5.0:
		return
	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		Game.play_sound(sound, global_position, volume_db, 0.11, max_distance)
		_footstep_timer = STEP_LENGTH / speed


## Двигаться (как move_and_slide) и толкать закрытые двери, в которые упёрлись.
func move_and_open_doors() -> void:
	var wanted := velocity  # move_and_slide обнулит скорость в сторону двери, запоминаем заранее
	move_and_slide()
	if wanted.length() < 1.0:
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var door := collision.get_collider() as Door
		if door and wanted.normalized().dot(-collision.get_normal()) > 0.3:
			door.push(self)


func distance_to_player() -> float:
	if player == null:
		return INF
	return global_position.distance_to(player.global_position)


## Ударить героя, если он рядом и перед нами. Возвращает true при попадании.
func try_strike_player(reach: float) -> bool:
	if player == null or player.is_dead:
		return false
	var to_player := player.global_position - global_position
	if to_player.length() > reach:
		return false
	var facing := Vector2.RIGHT.rotated(rotation)
	if absf(facing.angle_to(to_player)) > deg_to_rad(STRIKE_ANGLE):
		return false
	player.die(to_player.normalized())
	return true


## Сбить с ног: враг отлетает, лежит duration секунд, сквозь него можно ходить.
func knock_down(dir: Vector2, duration: float) -> void:
	is_downed = true
	_downed_timer = duration
	velocity = dir * 220.0
	rotation = dir.angle()
	collision_layer = 0  # пока лежит — не мешает герою
	Game.play_sound("punch", global_position)
	Game.hitstop(0.04)
	Game.shake(2.0)


## Вызывается, когда враг поднялся. Переопределяется в наследниках.
func on_got_up() -> void:
	pass


## Лежащий враг скользит по полу и отсчитывает время до подъёма.
## Вызывать из _physics_process наследника, пока is_downed == true.
func process_downed(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, DOWNED_FRICTION * delta)
	move_and_slide()
	_downed_timer -= delta
	if _downed_timer <= 0.0:
		is_downed = false
		collision_layer = 4
		on_got_up()


## Смерть: кровь, стоп-кадр, тряска. Труп остаётся лежать.
func kill(dir: Vector2) -> void:
	if is_dead:
		return
	is_dead = true
	is_downed = false
	velocity = Vector2.ZERO
	rotation = dir.angle()
	collision_layer = 0
	collision_mask = 0
	Game.spawn_blood(global_position, dir)
	Game.play_sound("hit_heavy", global_position)
	Game.play_sound("gore", global_position, -4.0)
	Game.hitstop(0.08)
	Game.shake(4.0)
	died.emit()
