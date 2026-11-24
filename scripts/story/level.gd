extends "res://scripts/main.gd"

const Layout := preload("res://scripts/story/floors.gd")
const Figure := preload("res://scripts/story/figure.gd")
const Dialogue := preload("res://scripts/story/dialogue.gd")
const B := preload("res://scripts/story/run.gd").Beat
const BASE := "res://scenes/story/motel_333.tscn"
const CELLAR := "res://scenes/story/cellar.tscn"

var points: Array[Dictionary] = []
var dialog := Dialogue.new()
var prompt := Label.new()
var nearby: Node2D
var target: Dictionary
var opponent: EnemyBase
var sleeper: Guest
var busy := false
var innkeeper: MotelOwner
var was_in_staff := false
var unseen_entry := false
var curtain := ColorRect.new()

func _ready() -> void:
	var ruined := Run.beat >= B.WOUNDED
	darkness = Color("#555069") if ruined else Color("#f2e5d0")
	if Run.beat >= B.KEYS:
		darkness = Color("#494158")
	use_vision = ruined
	ambient = "ambient_stealth" if ruined else "ambient_combat"
	if Run.area == "cellar":
		var old_exits := get_node("Props/Exits")
		props.remove_child(old_exits)
		old_exits.free()
	Layout.build(self,Run.area,ruined)
	super()
	player.position = Run.spawn
	player.combat_enabled = Run.beat == B.FIGHT
	player.light_enabled = Run.beat >= B.FIGHT
	if player.flashlight_on != (player.light_enabled and Run.light_on):
		player.toggle_flashlight()
	player.weapon = "crowbar" if Run.beat == B.FIGHT else ""
	weapon_label.hide()
	$UI/Hint.position = Vector2(10,6)
	$UI/Hint.modulate = Color.WHITE
	$UI/Hint.add_theme_constant_override("outline_size",4)
	$UI/Hint.text = Run.GOALS[Run.beat]
	$UI.add_child(prompt)
	prompt.position = Vector2(12,325)
	prompt.add_theme_font_size_override("font_size",13)
	prompt.add_theme_constant_override("outline_size",4)
	$UI.add_child(curtain)
	curtain.size = Vector2(640,360)
	curtain.color = Color.BLACK
	curtain.hide()
	$UI.add_child(dialog)
	populate()
	if Run.checkpoint.is_empty():
		Run.remember(player.position)
		curtain.show()
		var road := preload("res://scripts/story/tunnel.gd").new()
		curtain.add_child(road)
		busy = true
		say(["Сэм|В детстве Лиза просила меня сигналить в туннелях. Ей нравилось, как эхо едет за нами.",
			"Сэм|Во вторник она позвонила из мотеля. Я сказал, что перезвоню после смены. С тех пор трубку никто не берёт.",
			"Сэм|Три штата за спиной. На её открытке те же три цифры, что на вывеске. Только бы сестра ещё была здесь."],
			func(): road.queue_free(); curtain.hide(); arrive())
	elif Run.stair_arrival:
		Run.stair_arrival = false
		curtain.show()
		var fade := create_tween()
		fade.tween_property(curtain,"modulate:a",0.0,0.24)
		await fade.finished
		curtain.hide()
		curtain.modulate.a = 1

func arrive() -> void:
	busy = true
	player.hide()
	player.set_physics_process(false)
	var car := props.get_child(0) as Furniture
	var space := car.position
	car.position.y += 100
	var parking := create_tween()
	parking.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	parking.tween_property(car,"position",space,1.5)
	await parking.finished
	player.show()
	player.set_physics_process(true)
	busy = false

func prop(kind: int,x: float,y: float,w: float,h: float) -> Furniture:
	var object := Furniture.new()
	object.kind = kind
	object.size = Vector2(w,h)
	_add_prop(object,Vector2(x,y))
	return object

func lamp(x: int,y: int,color: int,flicker: bool) -> void:
	var object := Lamp.new()
	object.color_index = color
	object.flicker = flicker
	_add_prop(object,Vector2(x,y))

func hide_at(kind: int,x: int,y: int) -> void:
	var spot := HideSpot.new()
	spot.kind = kind
	spot.size = Vector2(32,26)
	_add_prop(spot,Vector2(x,y))

func sign_at(words: String,x: int,y: int) -> void:
	var inlay := preload("res://scripts/story/inlay.gd").new()
	inlay.inscription = words
	_add_prop(inlay,Vector2(x,y))

func mark(id: String,title: String,x: int,y: int) -> void:
	var pos := Vector2(x,y)
	points.append({"id":id,"title":title,"pos":pos})

func figure(sheet: String,pos: Vector2,walk := Vector2.ZERO):
	var sprite := Figure.new()
	sprite.dress(sheet)
	sprite.origin = pos
	sprite.stroll = walk
	_add_prop(sprite,pos)
	return sprite

func foe(scene: PackedScene,pos: Vector2,sheet: String) -> EnemyBase:
	var enemy := scene.instantiate() as EnemyBase
	enemy.position = pos
	enemies.add_child(enemy)
	var skin := Figure.new()
	skin.name = "StoryFigure"
	skin.dress(sheet)
	skin.actor = enemy
	enemy.add_child(skin)
	return enemy

func populate() -> void:
	match Run.area:
		"parking":
			mark("entrance","Вход в мотель",870,150)
			mark("car","Машина Сэма",182,202)
			if Run.beat == B.ARRIVAL:
				figure("Постоялец_1",Vector2(530,222),Vector2(60,0))
				figure("Постоялец_2",Vector2(720,172),Vector2(0,28))
			if Run.beat == B.CAR:
				sign_at("Аварийный спуск",245,315)
		"lobby":
			mark("outside","Парковка",65,225)
			sign_at("↑  2 ЭТАЖ",65,330)
			mark("up","На второй этаж",114,298)
			mark("basement","В подвал",872,117)
			if Run.beat <= B.BED:
				figure("Хозяин",Vector2(137,64))
			if Run.beat == B.ARRIVAL:
				mark("desk","Позвонить в звонок",136,104)
			if Run.beat <= B.BED:
				mark("visitor","Поговорить с посетителем",320,137)
				for i in range(3):
					figure("Постоялец_%d" % (i+3),Vector2(320+80*i,137),Vector2.ZERO if i == 0 else Vector2(19,0))
			if Run.beat in [B.KEYS,B.DRIVE]:
				if Run.beat == B.KEYS:
					mark("keys","Журнал смены и ключница",655,104)
				innkeeper = foe(OWNER_SCENE,Vector2(815,205),"Хозяин_мрачный") as MotelOwner
				innkeeper.patrol_points.assign([Vector2(875,93),Vector2(650,125),Vector2(420,245),Vector2(128,125),Vector2(815,205)])
			if Run.beat == B.RETURN:
				foe(WATCHMAN_SCENE,Vector2(520,290),"Сторож")
				foe(GUEST_SCENE,Vector2(580,200),"Постоялец_3_мрачный")
				foe(GUEST_SCENE,Vector2(900,205),"Постоялец_4_мрачный")
		"upper":
			sign_at("↓  ХОЛЛ",55,330)
			sign_at("АВАРИЙНЫЙ СПУСК",897,330)
			mark("down","На первый этаж",114,298)
			mark("escape","Аварийный спуск",923,305)
			if Run.beat in [B.MAID,B.BED]:
				figure("Горничная",Vector2(282,195))
				mark("maid","Горничная",282,195)
				mark("bed","Кровать • 204",345,72)
			if Run.beat in [B.WOUNDED,B.FIGHT,B.GUARD,B.CHASE]:
				figure("Раненый",Vector2(605,65)).wounded = true
			if Run.beat == B.WOUNDED:
				var tool := WEAPON_ITEM_SCENE.instantiate() as WeaponItem
				tool.weapon_name = "crowbar"
				tool.position = Vector2(617,82)
				weapons.add_child(tool)
				mark("guest","Раненый гость",605,65)
			if Run.beat == B.FIGHT:
				opponent = foe(GUEST_SCENE,Vector2(640,151),"Постоялец_1_мрачный")
				opponent.set_meta("story_knockout",true)
			if Run.beat == B.GUARD:
				figure("Сторож",Vector2(720,220))
				mark("guard","Позвать сторожа",720,220)
			if Run.beat == B.CHASE:
				var guard := foe(WATCHMAN_SCENE,Vector2(700,220),"Сторож") as Watchman
				guard._start_transform()
		"cellar":
			sign_at("ХОЛОДИЛЬНАЯ   →",628,237)
			sign_at("←   СКЛАД",220,264)
			sign_at("ЖУРНАЛ СМЕНЫ",100,520)
			var seal := preload("res://scripts/story/seal.gd").new()
			_add_prop(seal,Vector2(496,706))
			if Run.beat == B.FREEZER:
				sleeper = foe(GUEST_SCENE,Vector2(855,88),"Постоялец_2_мрачный") as Guest
				sleeper.set_physics_process(false)
				sleeper.get_node("StoryFigure").rotation = PI/2
				Game.noise_made.connect(wake_from_noise)
				mark("freezer","Бирка морозильника",813,98)
			if Run.beat == B.AMBUSH:
				mark("crates","Ящик • 205",120,397)
			if Run.beat == B.NOTES:
				mark("journal","Связка ключей и журнал",152,563)
				spawn_ambush()
			if Run.beat == B.DOOR:
				mark("end","Дверь вниз",496,688)

func wake_from_noise(pos: Vector2,radius: float) -> void:
	if is_instance_valid(sleeper) and sleeper.position.distance_to(pos) <= radius:
		wake()

func wake() -> void:
	if sleeper and not sleeper.is_physics_processing():
		sleeper.set_physics_process(true)
		sleeper.hear(player.position)
		Game.enemy_sound("growl",sleeper.position)

func _process(_delta: float) -> void:
	_hint_timer -= _delta
	if _hint_timer <= 0:
		_hint_label.hide()
	if busy or dialog.visible or player.is_dead:
		prompt.hide()
		return
	if sleeper and sleeper.is_lit_by_flashlight():
		wake()
	if Run.beat == B.FIGHT and opponent and (opponent.is_dead or opponent.is_downed):
		player.combat_enabled = false
		opponent.set_physics_process(false)
		say(["Сэм|Это тот парень с парковки… Пока лежит, надо уходить."],func(): jump(B.GUARD,"upper",player.position))
		return
	target = {}
	update_staff_entry()
	var best := 60.0
	for point in points:
		if not available(point.id):
			continue
		var dist := player.position.distance_to(point.pos)
		if dist < best and Game.line_of_sight(player.position,point.pos):
			target = point
			best = dist
	nearby = player._nearest_interactable()
	var action := str(target.get("title",""))
	if player.is_hidden:
		action = "Выйти из укрытия"
	elif action.is_empty() and nearby is HideSpot:
		action = "Спрятаться"
	elif action.is_empty() and not nearby and player.combat_enabled and player.weapon == "" and player.nearby_weapon():
		action = "Поднять оружие"
	elif action.is_empty() and nearby is Door and (not nearby.locked or nearby.is_open):
		action = "Закрыть дверь" if nearby.is_open else "Открыть дверь"
	prompt.visible = not action.is_empty()
	prompt.text = "F  •  "+action

func update_staff_entry() -> void:
	if not innkeeper or Run.beat != B.KEYS:
		return
	var inside := Rect2(528,16,240,144).has_point(player.position)
	var seen := innkeeper.state == MotelOwner.State.CHASE or innkeeper._sees_player()
	if inside and not was_in_staff:
		unseen_entry = not seen
	if not inside or seen:
		unseen_entry = false
	was_in_staff = inside
	$UI/Hint.text = "Он видел тебя. Уйди и вернись незаметно." if inside and not unseen_entry else Run.GOALS[Run.beat]

func available(id: String) -> bool:
	match id:
		"keys": return unseen_entry and innkeeper and innkeeper.state != MotelOwner.State.CHASE and not innkeeper._sees_player()
		"basement": return Run.beat == B.RETURN
		"up": return Run.beat != B.ARRIVAL
		"bed": return Run.beat == B.BED
		"escape": return Run.beat == B.CHASE
		"down": return Run.beat not in [B.FIGHT,B.GUARD,B.CHASE]
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if dialog.visible:
		dialog.advance()
	elif not busy and not player.is_dead and not player.is_hidden and not target.is_empty() and available(target.id):
		use_point(target.id)
	elif not busy and not player.is_dead and prompt.visible and (player.is_hidden or nearby or (player.combat_enabled and player.weapon == "" and player.nearby_weapon())):
		player._interact()

func say(lines: Array,after := Callable()) -> void:
	dialog.begin(lines,after if after.is_valid() else func(): pass)

func jump(beat: int,area: String,pos: Vector2,save := true) -> void:
	busy = true
	if area != Run.area and ("upper" in [area,Run.area] or area == "cellar"):
		Run.stair_arrival = true
		get_tree().paused = true
		curtain.modulate.a = 0.0
		curtain.show()
		var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fade.tween_property(curtain,"modulate:a",1.0,0.22)
		await fade.finished
		get_tree().paused = false
	Run.light_on = player.flashlight_on
	if beat == B.FIGHT:
		Run.light_on = true
	Run.beat = beat
	Run.area = area
	Run.spawn = pos
	if save:
		Run.remember(pos)
	get_tree().change_scene_to_file.call_deferred(CELLAR if area == "cellar" else BASE)

func use_point(id: String) -> void:
	match id:
		"entrance":
			jump(Run.beat,"lobby",Vector2(91,225))
		"outside":
			jump(Run.beat,"parking",Vector2(846,159))
		"up":
			if Run.beat == B.ARRIVAL:
				say(["Сэм|Сначала надо заселиться. Где тут звонок?"])
			else:
				jump(Run.beat,"upper",Vector2(132,266))
		"down":
			if Run.beat in [B.FIGHT,B.GUARD,B.CHASE]:
				say(["Сэм|На лестнице обвал. Остаётся аварийный спуск."])
			else:
				jump(Run.beat,"lobby",Vector2(112,275))
		"desk":
			say(["Хозяин|Доброй ночи, Сэм. Надолго к нам?","Сэм|Мы знакомы? Я ищу сестру. Лиза, вот фотография. Она звонила отсюда.","Хозяин|Все остаются.","Хозяин|Ключи от машины оставьте мне. Переставлю поближе. Ваш номер — 204, второй этаж.","Сэм|Часы за стойкой стоят. Три тридцать три."],func(): jump(B.MAID,"lobby",player.position))
		"visitor":
			say(["Посетитель|Если услышите свой голос из номера, не отвечайте.","Сэм|А если оттуда позовёт моя сестра?","Посетитель|Если услышите свой голос из номера, не отвечайте."])
		"maid":
			say(["Сэм|Извините, где двести четвёртый?","Горничная|Свежее бельё. Чистые полотенца.","Сэм|Вы меня слышите?","Горничная|Свежее бельё. Чистые полотенца."],func(): jump(B.BED,"upper",player.position))
		"bed":
			if Run.beat == B.BED:
				curtain.show()
				say(["3:33|Щёлкнул выключатель. За стеной что-то упало.","Сэм|Этот звук… Из соседнего, двести пятого."],func(): jump(B.WOUNDED,"upper",Vector2(346,100)))
			else:
				say(["Сэм|Та горничная в галерее хотела мне что-то сказать."])
		"guest":
			say(["Гость|Прикрой дверь. Тихо. У неё язычок щёлкает.",
				"Сэм|Я прижму полотенце. Держите вот здесь. Как вас зовут?",
				"Гость|Фрэнк. В кармане снимок, только не заляпай…",
				"Сэм|Оставьте его себе, Фрэнк. Вы видели эту девушку? Это моя сестра.",
				"Гость|Она стучала вчера. Или две недели назад. Я не открыл. У неё был голос моей жены.",
				"Сэм|Куда она пошла?",
				"Гость|К лестнице. Я слушал шаги, пока они не стали слышны под кроватью. Часы опять стояли.",
				"Сэм|Я вернусь за вами. Фрэнк? Сожмите мою руку.",
				"Гость|Фонарь возьми. Пальцем стекло прикрой. Там, внизу… видят свет.",
				"Сэм|Фрэнк?.. Чёрт. Кто там за дверью?"],func(): jump(B.FIGHT,"upper",Vector2(621,115)))
		"guard":
			say(["Сэм|Сэр! Там человек ранен, вызовите…","Сэм|Что с вашим лицом?!"],func(): jump(B.CHASE,"upper",Vector2(748,228)))
		"escape":
			if Run.beat == B.CHASE:
				jump(B.CAR,"parking",Vector2(246,285))
			else:
				say(["Сэм|Аварийный спуск. На парковку отсюда рукой подать."])
		"car":
			if Run.beat == B.CAR:
				say(["Сэм|Ключи… Я же отдал их хозяину."],parking_death)
			elif Run.beat == B.DRIVE:
				tunnel()
			else:
				say(["Сэм|Моя машина. Оранжевую даже в темноте ни с чем не спутать."])
		"keys":
			say(["Записка|Из табеля вычеркнуть горничную. Личные вещи переданы семье в 1971 году.","Сэм|Но я же говорил с ней вчера… Вот и ключи. Оранжевый брелок."],func(): jump(B.DRIVE,"lobby",player.position))
		"basement":
			if Run.beat == B.RETURN:
				jump(B.FREEZER,"cellar",Vector2(2328,1160))
			else:
				say(["Сэм|Тяжёлая дверь котельной. Пока мне сюда незачем."])
		"freezer":
			say(["Записка|Вещи гостя из 205-го сложены в ящик в западном тупике. Если он проснётся, выключите фонарь."],func(): advance_here(B.AMBUSH,"crates","Ящик • 205",120,397))
		"crates":
			say(["Сэм|Внутри чужие чемоданы. За ящиками кто-то шевелится…"],ambush)
		"journal":
			say(["Записка|За каждое имя в книге — ещё одна ночь хозяину. Сторож продержался дольше всех. Ему оставили форму.","Сэм|Ключи только от номеров. А внизу кто-то дышит."],func(): advance_here(B.DOOR,"end","Дверь вниз",496,688))
		"end":
			Game.play_sound("breath", Vector2.INF, -10.0)
			say(["Сэм|Ва та фа..."],finish)

func advance_here(beat: int,id: String,title: String,x: int,y: int) -> void:
	points.clear()
	target = {}
	Run.beat = beat
	Run.light_on = player.flashlight_on
	Run.remember(player.position)
	$UI/Hint.text = Run.GOALS[beat]
	mark(id,title,x,y)

func ambush() -> void:
	advance_here(B.NOTES,"journal","Журнал смены",152,563)
	spawn_ambush()

func spawn_ambush() -> void:
	foe(GUEST_SCENE,Vector2(62,410),"Постоялец_3_мрачный")
	foe(GUEST_SCENE,Vector2(175,353),"Постоялец_5_мрачный")

func parking_death() -> void:
	busy = true
	var guard := foe(WATCHMAN_SCENE,player.position+Vector2(78,12),"Сторож") as Watchman
	guard._become_creature()
	guard.set_physics_process(false)
	player.set_physics_process(false)
	var approach := create_tween()
	approach.tween_property(guard,"position",player.position+Vector2(8,0),0.55)
	await approach.finished
	player.die()
	await get_tree().create_timer(1.1).timeout
	curtain.show()
	say(["3:33|Номер 204. Пружины кровати снова скрипят.","Сэм|Меня тошнит. Машина, сторож… Ключи должны быть у персонала."],func(): jump(B.KEYS,"upper",Vector2(346,100)))

func tunnel() -> void:
	busy = true
	curtain.show()
	Game.play_sound("escape")
	var road := preload("res://scripts/story/tunnel.gd").new()
	curtain.add_child(road)
	await get_tree().create_timer(4.3).timeout
	say(["Сэм|Опять эта вывеска. Я ведь ехал прямо… Значит, гость был прав. Надо спуститься под мотель."],func(): jump(B.RETURN,"parking",Vector2(188,211)))

func finish() -> void:
	busy = true
	Run.beat = B.END
	for audio_class in ["AudioStreamPlayer","AudioStreamPlayer2D"]:
		for audio in get_tree().root.find_children("*",audio_class,true,false):
			audio.stop()
	get_tree().paused = true
	curtain.modulate.a = 0.0
	curtain.show()
	var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(curtain,"modulate:a",1.0,0.35)
	await fade.finished
	get_tree().quit()

func _on_player_died() -> void:
	if busy:
		return
	busy = true
	death_label.text = "3:33"
	death_label.show()
	await get_tree().create_timer(1.0).timeout
	Run.restore()
	get_tree().change_scene_to_file.call_deferred(CELLAR if Run.area == "cellar" else BASE)
