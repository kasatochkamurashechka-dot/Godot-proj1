class_name Watchman
extends EnemyBase
## Ночной сторож мотеля.
##
## В облике ЧЕЛОВЕКА: медленно ходит туда-обратно с фонарём.
##   Луч фонаря — его поле зрения. Сзади его можно убить одним ударом оружия
##   или сбить с ног кулаком.
## Услышав шум, человек идёт проверить, а существо бежит на звук.
## Заметив героя (или попав в луч его фонарика), ПРЕВРАЩАЕТСЯ в существо (TRANSFORM_TIME секунд, в это время уязвим).
## В облике СУЩЕСТВА: быстрый, видит во все стороны, выдерживает CREATURE_HP ударов оружием,
##   кулаки его только отталкивают.

enum State { PATROL, PAUSE, INVESTIGATE, TRANSFORM, HUNT, WINDUP, RECOVER, STAGGER }

# --- Человек ---
const PATROL_SPEED := 30.0
const FLASHLIGHT_RANGE := 150.0  # дальность луча фонаря
const FLASHLIGHT_ANGLE := 28.0   # половина ширины луча, в градусах
const NOTICE_TOUCH := 12.0       # если герой подошёл вплотную — сторож его замечает
const PAUSE_TIME := 1.0          # пауза у стены перед разворотом
const TRANSFORM_TIME := 1.5      # время превращения — окно для удара
const HUMAN_DOWNED_TIME := 2.0

# --- Существо ---
const CREATURE_HP := 3
const CREATURE_SPEED := 100.0      # чуть быстрее героя (90) — от него не убежать по прямой
const CREATURE_SIGHT := 400.0
const CREATURE_WANDER_SPEED := 40.0
const ATTACK_RANGE := 20.0
const STRIKE_REACH := 24.0
const WINDUP_TIME := 0.2
const RECOVER_TIME := 0.35
const STAGGER_TIME := 0.35

# --- Цвета-заглушки ---
const UNIFORM_COLOR := Color(0.2, 0.3, 0.65)
const CAP_COLOR := Color(0.1, 0.14, 0.3)
const SKIN_COLOR := Color(0.9, 0.75, 0.6)
const CREATURE_COLOR := Color(0.12, 0.02, 0.07)
const CREATURE_EYES := Color(1.0, 0.1, 0.2)
const FLASHLIGHT_COLOR := Color(1.0, 0.9, 0.55)

@export var patrol_direction := Vector2.RIGHT  # куда сначала идёт патрулём

var state := State.PATROL
var is_creature := false
var hp := CREATURE_HP
var _timer := 0.0
var _flashlight: PointLight2D  # настоящий фонарь: светит конусом, стены дают тень
var _eyes_glow: PointLight2D   # красное свечение глаз существа


func _ready() -> void:
	super()  # вызываем _ready из EnemyBase (находит героя)
	rotation = patrol_direction.angle()
	_flashlight = LightTextures.make_light(LightTextures.cone(FLASHLIGHT_ANGLE),
			FLASHLIGHT_RANGE, FLASHLIGHT_COLOR, 1.0)
	_flashlight.shadow_item_cull_mask = LightTextures.CHARACTER_SHADOW_MASK
	add_child(_flashlight)
	_eyes_glow = LightTextures.make_light(LightTextures.radial(), 22.0, CREATURE_EYES, 0.8, false)
	_eyes_glow.hide()
	add_child(_eyes_glow)


func _process(delta: float) -> void:
	super(delta)
	_update_lights()


## Фонарь горит, пока сторож — человек на ногах; при превращении мигает.
func _update_lights() -> void:
	var human_up := not is_dead and not is_downed and not is_creature
	_flashlight.visible = human_up
	if state == State.TRANSFORM:
		_flashlight.energy = randf_range(0.0, 1.2)
	else:
		_flashlight.energy = 1.0
	_eyes_glow.visible = is_creature and not is_dead


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if is_downed:
		process_downed(delta)
		return

	_timer -= delta
	match state:
		State.PATROL:
			velocity = patrol_direction * PATROL_SPEED
			rotation = patrol_direction.angle()
			_check_flashlight()
		State.PAUSE:
			velocity = Vector2.ZERO
			_check_flashlight()
			if state == State.PAUSE and _timer <= 0.0:
				patrol_direction = -patrol_direction  # разворот
				state = State.PATROL
		State.INVESTIGATE:
			move_to_last_seen(PATROL_SPEED * 1.4)
			_check_flashlight()
			if state == State.INVESTIGATE and not has_target:
				# Дошёл — никого. Постоит и продолжит обход в прежнюю сторону
				# (PAUSE разворачивает, поэтому заранее разворачиваем «наоборот»)
				patrol_direction = -patrol_direction
				state = State.PAUSE
				_timer = PAUSE_TIME * 2.0
		State.TRANSFORM:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				_become_creature()
		State.HUNT:
			_hunt()
		State.WINDUP:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				velocity = Vector2.RIGHT.rotated(rotation) * 130.0  # рывок
				try_strike_player(STRIKE_REACH)
				state = State.RECOVER
				_timer = RECOVER_TIME
		State.RECOVER, State.STAGGER:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			if _timer <= 0.0:
				state = State.HUNT

	move_and_open_doors()
	if is_creature:
		play_footsteps(delta, "owner_step", -4.0, 320.0)
	else:
		play_footsteps(delta, "step", -8.0, 260.0)

	# Упёрся в стену: человек останавливается и разворачивается, существо поворачивает
	if state == State.PATROL and _hit_wall_ahead(patrol_direction):
		state = State.PAUSE
		_timer = PAUSE_TIME
	elif state == State.HUNT and not has_target and _hit_wall_ahead(Vector2.RIGHT.rotated(rotation)):
		rotation += PI / 2.0 * (1 if randf() < 0.5 else -1)


## Упёрлись ли в стену ВПЕРЕДИ по направлению dir.
## Стена за спиной (касаемся её сразу после разворота) не считается —
## иначе сторож разворачивался бы туда-обратно на месте.
func _hit_wall_ahead(dir: Vector2) -> bool:
	for i in get_slide_collision_count():
		# Нормаль — направление «от стены». Если она смотрит против движения, стена впереди.
		if get_slide_collision(i).get_normal().dot(dir) < -0.5:
			return true
	return false


## Услышал шум: человек идёт посмотреть, существо — бежит туда, если не видит героя.
func hear(pos: Vector2) -> void:
	match state:
		State.PATROL, State.PAUSE, State.INVESTIGATE:
			last_seen = pos
			has_target = true
			state = State.INVESTIGATE
		State.HUNT:
			if not can_see_player(CREATURE_SIGHT):
				last_seen = pos
				has_target = true


## Человек проверяет, не попал ли герой в луч фонаря (или не подошёл ли вплотную).
func _check_flashlight() -> void:
	var touched := distance_to_player() < NOTICE_TOUCH and not player.is_hidden
	if can_see_player(FLASHLIGHT_RANGE, FLASHLIGHT_ANGLE) or touched:
		_start_transform()


func _start_transform() -> void:
	state = State.TRANSFORM
	_timer = TRANSFORM_TIME
	velocity = Vector2.ZERO
	if player and not player.is_dead:
		rotation = (player.global_position - global_position).angle()
	Game.shake(2.0)
	Game.glitch(0.4, TRANSFORM_TIME)
	Game.enemy_sound("transform", global_position, 0.0, 700.0, 40.0)


func _become_creature() -> void:
	is_creature = true
	hp = CREATURE_HP
	state = State.HUNT
	Game.shake(5.0)
	Game.glitch(1.0, 0.7)
	Game.spawn_blood(global_position, Vector2.RIGHT.rotated(rotation), 0.6)  # человеческая оболочка рвётся
	if player and not player.is_dead:
		last_seen = player.global_position
		has_target = true


func _hunt() -> void:
	var sees := look_for_player(CREATURE_SIGHT)
	if sees and distance_to_player() <= ATTACK_RANGE:
		rotation = (player.global_position - global_position).angle()
		state = State.WINDUP
		_timer = WINDUP_TIME
		velocity = Vector2.ZERO
		Game.enemy_sound("growl", global_position, 0.0, 400.0, 22.0)
	elif has_target:
		move_to_last_seen(CREATURE_SPEED)
	else:
		# Потерял героя — бродит, пока снова не увидит
		velocity = Vector2.RIGHT.rotated(rotation) * CREATURE_WANDER_SPEED


func take_hit(kind: String, dir: Vector2) -> void:
	if is_dead:
		return

	if not is_creature:
		# Человек (в том числе во время превращения)
		if kind == "melee" or is_downed:
			kill(dir)
		else:
			knock_down(dir, HUMAN_DOWNED_TIME)
		return

	# Существо: кулаки только отталкивают
	if kind == "fist":
		velocity = dir * 150.0
		state = State.STAGGER
		_timer = 0.2
		Game.shake(1.0)
		Game.play_sound("punch", global_position)
		return

	hp -= 1
	if hp <= 0:
		kill(dir)
		return
	velocity = dir * 220.0
	state = State.STAGGER
	_timer = STAGGER_TIME
	Game.spawn_blood(global_position, dir, 0.5)
	Game.play_sound("creature_hit", global_position)
	Game.hitstop(0.05)
	Game.shake(3.0)


## Поднявшись после удара, человек уже знает о герое и сразу превращается.
func on_got_up() -> void:
	if not is_creature:
		_start_transform()


func _draw() -> void:
	if has_node("StoryFigure") and not is_creature:
		return
	draw_circle(Depth.offset(self), 10.0 if is_creature else 7.5, Depth.COLOR)  # тень
	if is_dead or is_downed:
		var color := CREATURE_COLOR if is_creature else UNIFORM_COLOR
		if is_dead and not is_creature:
			color = color.darkened(0.3)
		draw_rect(Rect2(-9, -5, 16, 10), color)
		draw_circle(Vector2(8, 0), 3.5, CREATURE_EYES if is_creature else SKIN_COLOR)
		return

	if is_creature:
		_draw_creature()
		return

	# Человек: тело и фуражка (луч фонаря — это настоящий свет, см. _flashlight)
	var jitter := Vector2.ZERO
	var body_color := UNIFORM_COLOR
	if state == State.TRANSFORM:
		# Дёргается и мерцает красным — вот-вот превратится
		jitter = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
		if (Time.get_ticks_msec() / 70) % 2 == 0:
			body_color = CREATURE_EYES
	draw_circle(jitter, 7.0, body_color)
	draw_circle(jitter + Vector2(1, 0), 3.5, SKIN_COLOR)
	draw_rect(Rect2(jitter + Vector2(-2, -4), Vector2(5, 8)), CAP_COLOR)  # фуражка


func _draw_creature() -> void:
	# Колючий силуэт: чередуем длинные и короткие «лучи»
	var points := PackedVector2Array()
	var spikes := 9
	for i in spikes * 2:
		var radius := 12.0 if i % 2 == 0 else 6.0
		radius += randf_range(-1.0, 1.0)  # силуэт слегка «шевелится»
		points.append(Vector2.RIGHT.rotated(TAU * i / (spikes * 2)) * radius)
	var color := CREATURE_COLOR
	if state == State.WINDUP:
		color = Color(0.5, 0.0, 0.1)
	draw_colored_polygon(points, color)
	draw_circle(Vector2(6, -3), 1.5, CREATURE_EYES)
	draw_circle(Vector2(6, 3), 1.5, CREATURE_EYES)
