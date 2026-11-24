class_name Player
extends CharacterBody2D
## Герой: ходит на WASD (с Shift — крадётся), смотрит на курсор,
## бьёт, подбирает и бросает оружие, прячется в укрытиях, открывает двери.
## Нарисован спрайтом assets/sprites/sam.png (32 направления × 4 кадра шага,
## лист делает tools/make_sam_sprites.py). Оружие и след удара рисуются кодом в _draw.

## Сигнал «герой умер» — его слушает main.gd, чтобы показать экран смерти.
signal died

const WEAPON_ITEM_SCENE := preload("res://scenes/weapon_item.tscn")

# --- Движение ---
const SPEED := 90.0       # максимальная скорость, пикселей в секунду (обычный шаг)
const ACCEL := 900.0      # как быстро разгоняется (чем больше, тем резче)
const FRICTION := 1200.0  # как быстро тормозит, когда клавиши отпущены
const SNEAK_SPEED := 45.0 # скорость, когда крадёмся (Shift)

# --- Шум и прятки ---
const RUN_NOISE_RADIUS := 120.0  # на каком расстоянии слышно бегущего героя
const STEP_INTERVAL := 0.4       # как часто шумят шаги при беге, секунд
const PUDDLE_NOISE_RADIUS := 100.0      # шаг по луже: так далеко слышно
const PUDDLE_SNEAK_NOISE_RADIUS := 60.0 # то же крадучись — тише, но всё равно слышно
const DOOR_REACH := 24.0         # с какого расстояния от проёма можно открыть или закрыть дверь

# --- Свет ---
const FLASHLIGHT_RANGE := 210.0
const FLASHLIGHT_ANGLE := 24.5   # половина ширины луча, в градусах (весь луч — 49°)
const FLASHLIGHT_COLOR := Color(1.0, 0.95, 0.85)
const FLASHLIGHT_ENERGY := 0.88  # яркость луча
const AURA_RANGE := 45.0         # слабое свечение вокруг героя, чтобы видеть себя и соседние клетки

# --- Бой ---
const FIST_REACH := 18.0      # дальность удара кулаком
const FIST_COOLDOWN := 0.3    # пауза между ударами кулаком
const HIT_ANGLE := 65.0       # удар задевает врагов в секторе ±65° перед героем
const SWING_TIME := 0.12      # сколько длится анимация замаха
const PICKUP_RADIUS := 30.0   # с какого расстояния можно подобрать оружие

# --- Спрайт ---
const SPRITE_SHEET_PATH := "res://assets/sprites/sam.png"
const SPRITE_DIRECTIONS := 32         # строки листа: направления, по 11,25° (0 — лицом к нам)
const SPRITE_WALK_FRAMES := 4         # столбцы: 0 — стоит, 1 — шаг, 2 — стоит, 3 — шаг другой ногой
const SPRITE_FOOT := Vector2(17, 40)  # где в клетке листа стоят ноги (см. tools/make_sam_sprites.py)
const FEET_OFFSET := Vector2(0, 5)    # ноги чуть ниже центра героя (центр — середина круга столкновений)
const STRIDE := 9.0                   # сколько пикселей пройти на один кадр шага
const BREATH_SPEED := 2.2             # дыхание на месте: скорость
const BREATH_AMOUNT := 0.03           # и насколько «поднимается грудь» (доля роста)
const LUNGE := 2.0                    # рывок спрайта вперёд при ударе, пикселей
const HEAD_COLOR := Color(0.95, 0.78, 0.62)  # кулак при ударе без оружия
const DEAD_TINT := Color(0.55, 0.5, 0.55)    # лежащий Сэм темнее

var is_dead := false
var combat_enabled := true
var light_enabled := true
var weapon := ""  # пустая строка — кулаки, иначе ключ из Weapons.DATA
var is_hidden := false  # сидит в укрытии — враги не видят
var flashlight_on := true  # фонарик (F): светит далеко, но враги замечают свет
var has_key := false    # подобраны ли ключи от машины

var _attack_cooldown := 0.0
var _swing_timer := 0.0
var _step_timer := 0.0
var _hide_spot: HideSpot = null
var _hide_return := Vector2.ZERO  # где стоял перед тем, как спрятаться
var _flashlight: PointLight2D
var _sprite: Sprite2D
var _shadow: FeetShadow
var _walk_phase := 0.0
var _breath := 0.0


## Овальная тень у ног (рисуется под спрайтом)
class FeetShadow extends Node2D:
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 6.5, Depth.COLOR)


func _ready() -> void:
	# Фонарик светит туда же, куда смотрит герой (поворачивается вместе с ним)
	_flashlight = LightTextures.make_light(LightTextures.cone(FLASHLIGHT_ANGLE),
			FLASHLIGHT_RANGE, FLASHLIGHT_COLOR, FLASHLIGHT_ENERGY)
	_flashlight.shadow_item_cull_mask = LightTextures.CHARACTER_SHADOW_MASK
	add_child(_flashlight)
	var aura := LightTextures.make_light(LightTextures.radial(), AURA_RANGE, FLASHLIGHT_COLOR, 0.5)
	aura.shadow_item_cull_mask = LightTextures.CHARACTER_SHADOW_MASK
	add_child(aura)
	# Тень и спрайт рисуются до _draw героя (show_behind_parent), поэтому оружие — поверх
	_shadow = FeetShadow.new()
	_shadow.show_behind_parent = true
	add_child(_shadow)
	_sprite = Sprite2D.new()
	_sprite.texture = load(SPRITE_SHEET_PATH)
	_sprite.hframes = SPRITE_WALK_FRAMES
	_sprite.vframes = SPRITE_DIRECTIONS
	_sprite.centered = false
	_sprite.offset = -SPRITE_FOOT  # точка опоры спрайта — ноги
	_sprite.show_behind_parent = true
	add_child(_sprite)
	_animate(0.0)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if Input.is_action_just_pressed("throw"):
		_interact()
	if light_enabled and Input.is_action_just_pressed("flashlight") and not is_hidden:
		toggle_flashlight()

	# В укрытии не двигаемся и не бьём, только ждём
	if is_hidden:
		return

	_move(delta)
	look_at(get_global_mouse_position())

	_attack_cooldown -= delta
	_swing_timer -= delta

	if combat_enabled and Input.is_action_just_pressed("attack") and _attack_cooldown <= 0.0:
		_attack()

	queue_redraw()


func _process(delta: float) -> void:
	_animate(delta)


## Анимация спрайта: направление по взгляду, шаги по пройденному пути, дыхание, рывок при ударе.
## Сам герой поворачивается к курсору (от этого зависят фонарик и удар), а спрайт —
## нет: он всегда «стоит», меняется только кадр.
func _animate(delta: float) -> void:
	_sprite.visible = not is_hidden
	_shadow.visible = not is_hidden and not is_dead
	_sprite.rotation = -rotation
	_shadow.rotation = -rotation
	var direction := _direction_frame()
	if is_dead:
		# Лежит на боку, темнее
		_sprite.frame = direction * SPRITE_WALK_FRAMES
		_sprite.rotation = -rotation + PI / 2.0
		_sprite.modulate = DEAD_TINT
		_sprite.position = Vector2.ZERO
		_sprite.scale = Vector2.ONE
		return
	_sprite.modulate = Color.WHITE
	var speed := velocity.length()
	var walk := 0
	if speed > 5.0:
		_walk_phase = fmod(_walk_phase + speed * delta / STRIDE, SPRITE_WALK_FRAMES)
		walk = int(_walk_phase)
		_breath = 0.0
	else:
		_walk_phase = 0.0
		_breath += delta
	_sprite.frame = direction * SPRITE_WALK_FRAMES + walk
	# Смещения считаем в «экранных» осях, а спрайт — ребёнок повёрнутого героя,
	# поэтому поворачиваем их обратно на -rotation
	var offset := FEET_OFFSET
	if walk % 2 == 1:
		offset.y -= 1.0  # на шаге чуть подпрыгивает
	if _swing_timer > 0.0:
		var progress := 1.0 - clampf(_swing_timer / SWING_TIME, 0.0, 1.0)
		offset += (facing() * LUNGE * sin(progress * PI)).round()  # рывок к цели
	_sprite.position = offset.rotated(-rotation)
	_shadow.position = (FEET_OFFSET + Vector2(1, 0)).rotated(-rotation)
	var breathe := 1.0 + BREATH_AMOUNT * sin(_breath * BREATH_SPEED * TAU / 2.0)
	_sprite.scale = Vector2(1.0, breathe)


## Номер строки листа по направлению взгляда: 0 — к нам (вниз), 8 — вправо, 16 — вверх, 24 — влево.
func _direction_frame() -> int:
	var angle := rad_to_deg(rotation)  # 0 — вправо, 90 — вниз
	return posmod(int(round((90.0 - angle) / (360.0 / SPRITE_DIRECTIONS))), SPRITE_DIRECTIONS)


func _move(delta: float) -> void:
	var sneaking := Input.is_action_pressed("sneak")
	var max_speed := SNEAK_SPEED if sneaking else SPEED

	# get_vector собирает 4 клавиши в один вектор направления длиной до 1
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * max_speed, ACCEL * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	# move_and_slide двигает героя и сам «скользит» вдоль стен
	move_and_slide()
	_push_doors(input_dir, sneaking)

	# Бегом шумим (шаги слышат враги), крадучись — шаги еле слышны и врагам не слышны
	var moving_speed := velocity.length()
	var room := get_tree().get_first_node_in_group("room")
	var in_puddle: bool = room != null and room.is_puddle(global_position)
	if moving_speed > SNEAK_SPEED + 10.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			if in_puddle:
				Game.make_noise(global_position, PUDDLE_NOISE_RADIUS, 0.6)
				Game.play_sound("splash", Vector2.INF, -6.0, 0.15)
			else:
				Game.make_noise(global_position, RUN_NOISE_RADIUS, 0.4)
				Game.play_sound("step", Vector2.INF, -8.0, 0.15)
			_step_timer = STEP_INTERVAL
	elif moving_speed > 10.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			if in_puddle:
				# Лужа выдаёт и крадущегося
				Game.make_noise(global_position, PUDDLE_SNEAK_NOISE_RADIUS, 0.4)
				Game.play_sound("splash", Vector2.INF, -12.0, 0.15)
			else:
				Game.play_sound("step", Vector2.INF, -22.0, 0.15)
			_step_timer = STEP_INTERVAL * 1.8
	else:
		_step_timer = 0.0  # первый шаг после остановки слышно сразу


## Упёрлись в закрытую дверь — толкаем её. Крадучись дверь открывается без шума.
func _push_doors(input_dir: Vector2, sneaking: bool) -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var door := collision.get_collider() as Door
		# Толкаем, только если идём в дверь, а не скользим вдоль стены рядом с ней
		if door and input_dir.dot(-collision.get_normal()) > 0.5:
			door.push(self, sneaking)


## E / ПКМ: вылезти из укрытия; иначе — ближайшее рядом укрытие или дверь;
## если рядом ничего нет — подобрать или бросить оружие.
func _interact() -> void:
	if is_hidden:
		_leave_hiding()
		return
	var target := _nearest_interactable()
	if target is HideSpot:
		_enter_hiding(target)
	elif target is LevelExit:
		target.use(self)
	elif target is Door:
		if target.is_open:
			target.close()
		else:
			target.push(self, Input.is_action_pressed("sneak"))
	elif not combat_enabled:
		return
	elif weapon == "":
		_try_pickup()
	else:
		_throw_weapon()


## Ближайшее укрытие, дверь или переход на другую карту, до которых можно дотянуться. null — ничего рядом.
func _nearest_interactable() -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for spot: HideSpot in get_tree().get_nodes_in_group("hide_spots"):
		var distance := spot.distance_to_point(global_position)
		if distance <= HideSpot.INTERACT_GAP and distance < best_distance and Game.line_of_sight(global_position,spot.global_position):
			best = spot
			best_distance = distance
	for exit: LevelExit in get_tree().get_nodes_in_group("level_exits"):
		var distance := exit.distance_to_point(global_position)
		if exit.enabled and distance <= LevelExit.REACH and distance < best_distance:
			best = exit
			best_distance = distance
	for door: Door in get_tree().get_nodes_in_group("doors"):
		var distance := door.distance_to_point(global_position)
		if distance <= DOOR_REACH and distance < best_distance and _can_reach_door(door):
			best = door
			best_distance = distance
	return best


func _can_reach_door(door: Door) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, door.global_position, 1)
	query.exclude = [door.get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _enter_hiding(spot: HideSpot) -> void:
	# Сначала спрашиваем врагов: видел ли кто-то, как мы прячемся?
	# (пока is_hidden == false, они ещё могут нас видеть)
	# Передаём место, где стоим: туда хозяин и пойдёт вытаскивать
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("notice_hiding"):
			enemy.notice_hiding(global_position)
	is_hidden = true
	_hide_spot = spot
	_hide_return = global_position
	spot.enter(global_position)
	_flashlight.hide()  # в укрытии фонарик выключаем, чтобы не выдать себя
	global_position = spot.global_position
	velocity = Vector2.ZERO
	queue_redraw()


func _leave_hiding() -> void:
	is_hidden = false
	_flashlight.visible = flashlight_on  # фонарик загорается, только если был включён
	if _hide_spot:
		_hide_spot.leave()
	_hide_spot = null
	# Вылезаем туда же, откуда залезли: внутри кровати или машины стоять нельзя
	global_position = _hide_return
	queue_redraw()


## F: включить или выключить фонарик. Без него враги не замечают свет, но и видно меньше.
func toggle_flashlight() -> void:
	flashlight_on = not flashlight_on
	_flashlight.visible = flashlight_on
	Game.play_sound("flashlight", Vector2.INF, -6.0, 0.05)


## Направление взгляда героя (единичный вектор).
func facing() -> Vector2:
	return Vector2.RIGHT.rotated(rotation)


func _attack() -> void:
	var reach := FIST_REACH
	var kind := "fist"
	_attack_cooldown = FIST_COOLDOWN
	if weapon != "":
		var data: Dictionary = Weapons.DATA[weapon]
		reach = data.reach
		kind = "melee"
		_attack_cooldown = data.cooldown
	_swing_timer = SWING_TIME
	Game.play_sound("swing", Vector2.INF, -10.0, 0.15)

	# Проверяем всех врагов: близко ли, в секторе ли перед нами, не мешает ли стена
	for enemy: EnemyBase in get_tree().get_nodes_in_group("enemies"):
		if not enemy.can_be_hit():
			continue
		var to_enemy := enemy.global_position - global_position
		if to_enemy.length() > reach + 7.0:  # 7 — примерный радиус врага
			continue
		# Лежащего врага прямо под ногами бьём при любом угле
		var in_front := absf(facing().angle_to(to_enemy)) <= deg_to_rad(HIT_ANGLE)
		if not in_front and to_enemy.length() > 10.0:
			continue
		if not Game.line_of_sight(global_position, enemy.global_position):
			continue
		enemy.take_hit(kind, to_enemy.normalized())


func nearby_weapon() -> WeaponItem:
	var nearest: WeaponItem = null
	var best := PICKUP_RADIUS
	for item: WeaponItem in get_tree().get_nodes_in_group("weapon_items"):
		if item.flying:
			continue
		var distance := item.global_position.distance_to(global_position)
		if distance <= best and Game.line_of_sight(global_position,item.global_position):
			best = distance
			nearest = item
	return nearest

func _try_pickup() -> void:
	var nearest := nearby_weapon()
	if nearest:
		weapon = nearest.weapon_name
		nearest.queue_free()
		Game.play_sound("land", Vector2.INF, -16.0)


func _throw_weapon() -> void:
	var item := WEAPON_ITEM_SCENE.instantiate() as WeaponItem
	item.weapon_name = weapon
	# Брошенный предмет кладём туда же, где лежит всё оружие уровня
	var parent := get_tree().get_first_node_in_group("weapons_root")
	parent.add_child(item)
	item.global_position = global_position + facing() * 8.0
	item.throw(facing())
	weapon = ""
	Game.play_sound("swing", Vector2.INF, -4.0, 0.1)


## Смерть героя. Её вызывают враги. from_dir — откуда пришёл удар (для крови).
func die(from_dir := Vector2.ZERO) -> void:
	if is_dead:
		return
	if is_hidden:
		_leave_hiding()  # вытащили из укрытия
	is_dead = true
	velocity = Vector2.ZERO
	Game.spawn_blood(global_position, from_dir, 1.3)
	Game.shake(6.0)
	Game.glitch(0.8, 0.8)
	Game.play_sound("death")
	_flashlight.hide()
	queue_redraw()
	died.emit()


## Поверх спрайта кодом рисуются оружие и след удара. Взгляд — вправо (+X), поворот делает look_at.
func _draw() -> void:
	if is_hidden or is_dead:
		return  # в укрытии видны только глаза; лежащего показывает спрайт

	# Взмах: рука (или оружие) проходит дугу от -70° до +70°
	var swing_progress := 1.0 - clampf(_swing_timer / SWING_TIME, 0.0, 1.0)
	var arm_angle := 0.0
	if _swing_timer > 0.0:
		arm_angle = lerpf(-1.2, 1.2, swing_progress)

	if weapon != "":
		var data: Dictionary = Weapons.DATA[weapon]
		var tip := Vector2(4.0 + data.length, 0).rotated(arm_angle)
		draw_line(Vector2(3, 0).rotated(arm_angle), tip, data.color, 2.0)
	elif _swing_timer > 0.0:
		draw_circle(Vector2(9, 0).rotated(arm_angle), 2.0, HEAD_COLOR)  # кулак


	# Белый след удара
	if _swing_timer > 0.0:
		var reach := FIST_REACH
		if weapon != "":
			reach = Weapons.DATA[weapon].reach
		draw_arc(Vector2.ZERO, reach, -1.1, 1.1, 12, Color(1, 1, 1, 0.5 * (1.0 - swing_progress)), 2.0)
