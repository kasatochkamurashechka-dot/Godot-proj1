extends Sprite2D

var actor: Node2D
var stroll := Vector2.ZERO
var origin: Vector2
var angle := PI / 2
var elapsed := 0.0
var wounded := false

func dress(sheet: String) -> void:
	texture = load("res://assets/story/%s.png" % sheet)
	hframes = 8
	vframes = 4
	offset = Vector2(0,-7)

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
			# The transformed guard uses the prototype's animated creature.
			hide()
	elif stroll != Vector2.ZERO:
		var phase := elapsed * 0.55
		position = origin + stroll * sin(phase)
		angle = stroll.angle() if cos(phase) > 0 else stroll.angle()+PI
	elif wounded:
		rotation = -1.25
		modulate = Color(0.7,0.38,0.35)
	frame = posmod(roundi((PI/2-angle)*32/TAU),32)
