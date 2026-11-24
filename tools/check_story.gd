extends SceneTree
## Run after editor import: godot --headless --script res://tools/check_story.gd
## Validate transitions via the interaction input and check navigable approaches.
var level
var run
var failed := false

func _initialize() -> void:
	check.call_deferred()

func fail(message: String) -> void:
	failed = true
	push_error(message)
	quit(1)

func settle() -> void:
	for i in 5:
		await physics_frame
	level = current_scene

func enter() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	key.keycode = KEY_F
	key.pressed = true
	root.push_input(key)
	key.pressed = false
	root.push_input(key)

func visit(id: String) -> void:
	if failed:
		return
	var point: Dictionary
	for item in level.points:
		if item.id == id:
			point = item
	if point.is_empty():
		fail("Missing event " + id)
		return
	var start: Vector2 = level.player.position
	var reachable := false
	for offset in [Vector2.ZERO,Vector2(0,16),Vector2(16,0),Vector2(-16,0),Vector2(0,-16),Vector2(0,28)]:
		var dest: Vector2 = point.pos + offset
		if not level.room.find_path(start,dest).is_empty() and has_sight(dest,point.pos):
			level.player.position = dest
			reachable = true
			break
	if not reachable:
		print("Cells ",level.room.local_to_map(start)," -> ",level.room.local_to_map(point.pos)," walkable ",level.room.is_walkable(level.room.local_to_map(start))," / ",level.room.is_walkable(level.room.local_to_map(point.pos)), " bounds ",level.room.get_used_rect())
		fail("No approach to %s from %s" % [id,start])
		return
	await settle()
	if level.target.get("id","") != id:
		fail("Wrong interaction at "+id)
		return
	enter()
	await create_timer(0.32).timeout
	await settle()
	await drain()
	print("Passed ",id," / beat ",run.beat)

func has_sight(from: Vector2,to: Vector2) -> bool:
	return root.get_node("Game").line_of_sight(from,to)

func drain() -> void:
	while level.dialog.visible:
		enter()
		await settle()

	if run.stair_arrival:
		await create_timer(0.4).timeout
		await settle()

func check() -> void:
	run = root.get_node("Run")
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await settle()
	await drain()
	await create_timer(1.7).timeout
	Input.action_press("move_right")
	var parked: Vector2 = level.player.position
	for i in 20:
		await physics_frame
	Input.action_release("move_right")
	if level.player.position.x < parked.x + 12:
		fail("Player cannot walk from car")
		return
	for id in ["entrance","visitor","desk","up","maid","bed","guest"]:
		await visit(id)
		if failed: return
	level.player.die()
	await create_timer(1.2).timeout
	await settle()
	if run.beat != run.Beat.FIGHT or level.player.is_dead:
		fail("Fight checkpoint")
		return
	level.opponent.take_hit("melee",Vector2.RIGHT)
	await settle()
	await drain()
	for id in ["guard","escape","car"]:
		await visit(id)
		if failed: return
	await create_timer(2.0).timeout
	await settle()
	await drain()
	await visit("down")
	if failed: return
	# Simulate an observed entrance, then break pursuit inside the office.
	var hunter = level.innkeeper
	hunter.set_physics_process(false)
	hunter.state = hunter.State.CHASE
	level.player.position = Vector2(655,104)
	await settle()
	if level.available("keys") or level.target.get("id","") == "keys":
		fail("Keys offered while pursued")
		return
	hunter.state = hunter.State.PATROL
	await settle()
	if level.available("keys"):
		fail("Must leave and re-enter unseen")
		return
	level.player.position = Vector2(638,201)
	await settle()
	for id in ["keys","outside","car"]:
		await visit(id)
		if failed: return
	await create_timer(4.5).timeout
	await settle()
	await drain()
	for id in ["entrance","basement","freezer","crates","journal"]:
		await visit(id)
		if failed: return
	await visit("end")
	if failed: return
	if run.beat != run.Beat.END or level.clear_label.visible:
		fail("Expected final fade without credits")
		return
	print("PASS: intro, visitor, two loops, unseen entry, altar and final fade")
	# The game's own fade calls quit.
