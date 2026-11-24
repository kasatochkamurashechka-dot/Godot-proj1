class_name WeaponItem
extends CharacterBody2D
## Оружие как предмет в мире: либо лежит на полу (можно подобрать),
## либо летит после броска (сбивает врага с ног).

const THROW_SPEED := 420.0   # начальная скорость броска
const AIR_FRICTION := 500.0  # как быстро замедляется в полёте
const SPIN_SPEED := 20.0     # скорость вращения в полёте, радиан/сек

@export var weapon_name := "crowbar"  # ключ из Weapons.DATA

var flying := false
var _fly_velocity := Vector2.ZERO


func _ready() -> void:
	material = LightTextures.unshaded()  # светится — виден и в темноте


## Бросить предмет в направлении dir.
func throw(dir: Vector2) -> void:
	flying = true
	_fly_velocity = dir.normalized() * THROW_SPEED
	collision_mask = 1 | 4  # в полёте сталкивается со стенами (слой 1) и врагами (слой 3 = 4)


func _physics_process(delta: float) -> void:
	if not flying:
		return

	rotation += SPIN_SPEED * delta
	queue_redraw()  # тень должна падать в одну сторону, пока предмет крутится
	var collision := move_and_collide(_fly_velocity * delta)
	if collision:
		var other := collision.get_collider()
		if other is EnemyBase and other.can_be_hit():
			other.take_hit("throw", _fly_velocity.normalized())
		_land()
		return

	_fly_velocity = _fly_velocity.move_toward(Vector2.ZERO, AIR_FRICTION * delta)
	if _fly_velocity.length() < 40.0:
		_land()


## Предмет упал на пол — теперь его снова можно подобрать.
## Падение шумное: хозяин мотеля его услышит и придёт проверить.
func _land() -> void:
	flying = false
	collision_mask = 0
	queue_redraw()
	Game.make_noise(global_position, Weapons.THROW_NOISE_RADIUS)
	Game.play_sound("land", global_position)


func _draw() -> void:
	var data: Dictionary = Weapons.DATA[weapon_name]
	var half: float = data.length / 2.0
	# Тень: в полёте предмет выше над полом, и тень дальше
	var shadow := Depth.offset(self) * (2.0 if flying else 0.7)
	draw_line(Vector2(-half, 0) + shadow, Vector2(half, 0) + shadow, Depth.COLOR, 2.0)
	draw_line(Vector2(-half, 0), Vector2(half, 0), data.color, 2.0)
	# Лёгкое свечение, чтобы оружие было заметно на полу
	if not flying:
		draw_circle(Vector2.ZERO, half + 2.0, Color(1, 1, 1, 0.08))
