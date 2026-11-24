extends Sprite2D

var actor: Node2D
var stroll := Vector2.ZERO
var origin: Vector2
var angle := PI / 2
var elapsed := 0.0
var wounded := false
var path := PackedVector2Array()
var direction := 1
var pause := 0.0

func dress(sheet: String) -> void:
	texture = load("res://assets/story/%s.png" % sheet)
	hframes = 8
	vframes = 4
	offset = Vector2(0,-15)

func _process(delta: float) -> void:
	elapsed += delta
	if actor:
		angle = actor.rotation
		global_rotation = 0
		if actor is Guest and not actor.is_physics_processing():
			global_rotation = PI/2
		if actor is EnemyBase and (actor.is_dead or actor.is_downed):
			global_rotation = PI/2
		if actor is Watchman and actor.is_creature:
			scale = Vector2(1.25,1.04+0.035*sin(elapsed*8.0))
			modulate = Color("#c87070") if actor.state == Watchman.State.WINDUP else Color("#967080")
	elif stroll != Vector2.ZERO:
		pause -= delta
		if pause <= 0:
			if path.is_empty():
				var room := get_tree().get_first_node_in_group("room")
				path = room.find_path(position, origin + stroll * direction)
				direction *= -1
				pause = 0.7
			else:
				var step := position.direction_to(path[0])
				angle = step.angle()
				position = position.move_toward(path[0], delta * 20)
				if position.distance_to(path[0]) < 1:
					path.remove_at(0)
	elif wounded:
		rotation = -1.25
		modulate = Color(0.7,0.38,0.35)
	frame = posmod(roundi((PI/2-angle)*32/TAU),32)
