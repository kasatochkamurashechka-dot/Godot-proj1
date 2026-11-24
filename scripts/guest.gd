class_name Guest
extends EnemyBase
## Постоялец — погибший гость мотеля, застрявший в петле.
## Видит героя во все стороны (если нет стен), идёт к нему и бьёт с замахом.
## Кулак сбивает с ног, оружие убивает сразу, лежачего добивает любой удар.

enum State { IDLE, CHASE, WINDUP, RECOVER }

const SPEED := 52.0          # медленнее героя (90)
const SIGHT_RANGE := 260.0   # дальность зрения
const ATTACK_RANGE := 18.0   # с какого расстояния начинает замах
const STRIKE_REACH := 22.0   # дальность самого удара
const WINDUP_TIME := 0.35    # замах — окно, чтобы ударить первым
const RECOVER_TIME := 0.45   # пауза после удара
const DOWNED_TIME := 2.0     # сколько лежит после удара кулаком

# Цвета-заглушки: грязно-белый костюм, серое лицо
const BODY_COLOR := Color(0.82, 0.8, 0.72)
const HEAD_COLOR := Color(0.55, 0.6, 0.55)
const WINDUP_COLOR := Color(1.0, 0.25, 0.35)
const CORPSE_COLOR := Color(0.5, 0.48, 0.45)

var state := State.IDLE
var _timer := 0.0


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if is_downed:
		process_downed(delta)
		return

	_timer -= delta
	match state:
		State.IDLE, State.CHASE:
			_think()
		State.WINDUP:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				_strike()
		State.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
			if _timer <= 0.0:
				state = State.CHASE
	move_and_open_doors()
	play_footsteps(delta, "owner_step", -10.0)


## Услышал шум — идёт проверить (если ещё не гонится за героем, которого видит).
func hear(pos: Vector2) -> void:
	if state == State.IDLE or (state == State.CHASE and not can_see_player(SIGHT_RANGE)):
		last_seen = pos
		has_target = true


## Решаем, что делать: замахнуться, идти к герою или стоять.
func _think() -> void:
	var sees := look_for_player(SIGHT_RANGE)
	if sees and distance_to_player() <= ATTACK_RANGE:
		rotation = (player.global_position - global_position).angle()
		state = State.WINDUP
		_timer = WINDUP_TIME
		velocity = Vector2.ZERO
		Game.enemy_sound("growl", global_position, -4.0, 400.0, 22.0)
	elif has_target:
		state = State.CHASE
		move_to_last_seen(SPEED)
	else:
		state = State.IDLE
		velocity = Vector2.ZERO


func _strike() -> void:
	# Небольшой рывок вперёд при ударе
	velocity = Vector2.RIGHT.rotated(rotation) * 120.0
	try_strike_player(STRIKE_REACH)
	state = State.RECOVER
	_timer = RECOVER_TIME


func take_hit(kind: String, dir: Vector2) -> void:
	if is_dead:
		return
	if kind == "melee" or is_downed:
		if has_meta("story_knockout"):
			knock_down(dir, DOWNED_TIME)
			return
		kill(dir)
	else:  # кулак или брошенный предмет — сбивают с ног
		state = State.IDLE
		knock_down(dir, DOWNED_TIME)


func on_got_up() -> void:
	state = State.CHASE


func _draw() -> void:
	if has_node("StoryFigure"):
		return
	draw_circle(Depth.offset(self), 7.5, Depth.COLOR)  # тень
	if is_dead or is_downed:
		# Лежит: вытянутое тело головой по направлению удара
		var color := CORPSE_COLOR if is_dead else BODY_COLOR
		draw_rect(Rect2(-8, -4, 14, 8), color)
		draw_circle(Vector2(8, 0), 3.5, HEAD_COLOR)
		return
	var body := WINDUP_COLOR if state == State.WINDUP else BODY_COLOR
	draw_circle(Vector2.ZERO, 7.0, body)
	draw_circle(Vector2(1, 0), 3.5, HEAD_COLOR)
	if state == State.WINDUP:
		draw_circle(Vector2(4, -7), 2.5, HEAD_COLOR)  # занесённая рука
