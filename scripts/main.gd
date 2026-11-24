extends Node2D
## Корень любого уровня (сцена scenes/level_base.tscn и унаследованные от неё).
## Готовит карту, подключает врагов и предметы, следит за целью уровня,
## показывает экраны смерти / зачистки / побега, перезапускает уровень по R.
##
## Уровни бывают двух видов:
##   • нарисованные в редакторе (мотель): тайлы, враги и предметы уже стоят в сцене;
##   • тестовые текстовые (map_name не пустой): всё создаётся по схеме из room.gd.

const GUEST_SCENE := preload("res://scenes/guest.tscn")
const WATCHMAN_SCENE := preload("res://scenes/watchman.tscn")
const OWNER_SCENE := preload("res://scenes/motel_owner.tscn")
const WEAPON_ITEM_SCENE := preload("res://scenes/weapon_item.tscn")

# Какое оружие стоит за каким символом карты
const WEAPON_SYMBOLS := {"c": "crowbar", "b": "bat", "v": "bottle"}

# Быстрое переключение уровней клавишами 1–4 (временная отладочная функция)
const DEBUG_LEVELS := {
	KEY_1: "res://scenes/tests/combat_test.tscn",
	KEY_2: "res://scenes/tests/stealth_test.tscn",
	KEY_3: "res://scenes/motel/motel.tscn",
	KEY_4: "res://scenes/basement/basement.tscn",
}

const PICKUP_DISTANCE := 10.0  # с какого расстояния подбираются ключи
const EXIT_DISTANCE := 12.0    # насколько близко подойти к выходу

## Тестовая текстовая схема из room.gd (MAPS). Пусто — карта нарисована в редакторе
@export var map_name := ""
## Насколько темно на уровне: цвет, на который умножается вся картинка
## (чем ближе к чёрному, тем темнее). По плану каждая петля темнее предыдущей.
@export var darkness := Color(0.3, 0.26, 0.38)
## Фоновый звук уровня (имя из Game.SOUNDS)
@export var ambient := "ambient_combat"
## Поле зрения героя: вдали и за стенами темно (см. scripts/vision.gd)
@export var use_vision := true

@onready var room: TileMapLayer = $Room
@onready var player: Player = $Player
@onready var enemies: Node2D = $Enemies
@onready var weapons: Node2D = $Weapons
@onready var props: Node2D = $Props
@onready var death_label: Label = $UI/DeathLabel
@onready var clear_label: Label = $UI/ClearLabel
@onready var weapon_label: Label = $UI/WeaponLabel
@onready var objective_label: Label = $UI/ObjectiveLabel
@onready var darkness_node: CanvasModulate = $Darkness

var _enemies_alive := 0
var _has_objective := false  # есть ли на карте ключи и выход
var _escaped := false
var _locked_hint_timer := 0.0
var _hint_label: Label     # короткие подсказки вроде «ЗАПЕРТО»
var _hint_timer := 0.0
var _music: AudioStreamPlayer


func _ready() -> void:
	Engine.time_scale = 1.0  # на случай рестарта посреди стоп-кадра
	add_to_group("level")    # чтобы Game.show_hint нашёл, где показать подсказку
	_make_hint_label()
	darkness_node.color = darkness
	_start_ambient()
	# Враги, уже расставленные в редакторе
	for enemy: EnemyBase in enemies.get_children():
		_connect_enemy(enemy)

	if map_name != "":
		_spawn_from_text_map()
	room.setup()  # поиск пути и тени — по готовым тайлам
	Game.apply_arrival(self, player)  # пришли с другой карты — встаём у лестницы или люка

	player.died.connect(_on_player_died)
	_make_overlays()
	# Цель «найти ключи и выйти» есть, только если на уровне лежат ключи
	_has_objective = not get_tree().get_nodes_in_group("keys").is_empty()
	objective_label.visible = _has_objective


## Тестовые карты: рисуем тайлы по тексту и создаём всё, что на схеме.
func _spawn_from_text_map() -> void:
	room.build(map_name)
	player.global_position = room.player_spawn
	var lamp_count := 0

	for spawn in room.spawns:
		var symbol: String = spawn[0]
		var pos: Vector2 = spawn[1]
		match symbol:
			"G":
				_add_enemy(GUEST_SCENE.instantiate(), pos)
			"W":
				_add_enemy(WATCHMAN_SCENE.instantiate(), pos)
			"O":
				var owner_enemy := OWNER_SCENE.instantiate() as MotelOwner
				owner_enemy.patrol_points = room.patrol_points
				_add_enemy(owner_enemy, pos)
			"H":
				_add_prop(HideSpot.new(), pos)
			"K":
				_add_prop(KeyItem.new(), pos)
			"X":
				_add_prop(ExitZone.new(), pos)
			"L", "l":
				var lamp := Lamp.new()
				lamp.color_index = lamp_count  # цвета ламп чередуются
				lamp.flicker = symbol == "l"
				lamp_count += 1
				_add_prop(lamp, pos)
			_:
				if WEAPON_SYMBOLS.has(symbol):
					var item := WEAPON_ITEM_SCENE.instantiate() as WeaponItem
					item.weapon_name = WEAPON_SYMBOLS[symbol]
					item.position = pos
					item.rotation = randf() * TAU  # лежит под случайным углом
					weapons.add_child(item)
				else:
					push_warning("Неизвестный символ на карте: " + symbol)


func _process(delta: float) -> void:
	# Подпись в углу: чем сейчас бьёт герой
	weapon_label.text = Weapons.title_of(player.weapon)

	_hint_timer -= delta
	if _hint_timer <= 0.0:
		_hint_label.hide()

	if _has_objective and not player.is_dead and not _escaped:
		_update_objective(delta)


## Ключи и выход: подобрать ключи, дойти до выхода.
func _update_objective(delta: float) -> void:
	for key: KeyItem in get_tree().get_nodes_in_group("keys"):
		if key.global_position.distance_to(player.global_position) <= PICKUP_DISTANCE:
			player.has_key = true
			key.queue_free()
			Game.play_sound("key")

	for exit: ExitZone in get_tree().get_nodes_in_group("exits"):
		if exit.global_position.distance_to(player.global_position) <= EXIT_DISTANCE:
			if player.has_key:
				_escape()
				return
			_locked_hint_timer = 2.0  # без ключей — подсказка на 2 секунды

	_locked_hint_timer -= delta
	# В надписи пишем ключ из translations/texts.csv — Label сам покажет перевод
	if _locked_hint_timer > 0.0:
		objective_label.text = "OBJ_NO_KEYS"
	elif player.has_key:
		objective_label.text = "OBJ_GET_TO_CAR"
	else:
		objective_label.text = "OBJ_FIND_KEYS"


func _escape() -> void:
	_escaped = true
	Game.play_sound("escape")
	objective_label.hide()
	clear_label.text = "UI_ESCAPED"
	clear_label.show()
	get_tree().paused = true  # останавливаем игру; R работает, т.к. Main обрабатывает ввод на паузе


## Слои поверх игры: поле зрения героя и кружки звуков врагов (видны и в темноте).
func _make_overlays() -> void:
	if use_vision:
		add_child(Vision.new())
	var marks := CanvasLayer.new()
	marks.layer = 3                    # над маской зрения (2), под VHS-эффектом (5)
	marks.follow_viewport_enabled = true  # двигается вместе с камерой, координаты — как в мире
	marks.add_to_group("sound_marks")
	add_child(marks)


## Надпись для подсказок: копия надписи цели, чуть ниже и другого цвета.
func _make_hint_label() -> void:
	_hint_label = objective_label.duplicate() as Label
	_hint_label.offset_top += 24.0
	_hint_label.offset_bottom += 24.0
	_hint_label.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
	_hint_label.hide()
	objective_label.get_parent().add_child(_hint_label)


## Показать подсказку на seconds секунд. Вызывается через Game.show_hint.
func show_hint(text_key: String, seconds: float) -> void:
	_hint_label.text = text_key  # Label сам переведёт ключ из texts.csv
	_hint_label.show()
	_hint_timer = seconds


func _start_ambient() -> void:
	_music = AudioStreamPlayer.new()
	_music.stream = Game.get_sound(ambient)
	_music.volume_db = -10.0
	add_child(_music)
	_music.play()


## Сцена закрывается (рестарт, смена карты, выход) — глушим зацикленный фон.
func _exit_tree() -> void:
	_music.stop()


func _add_enemy(enemy: EnemyBase, pos: Vector2) -> void:
	enemy.position = pos
	enemies.add_child(enemy)
	_connect_enemy(enemy)


## Следим за смертью врага (для надписи «этаж зачищен»).
func _connect_enemy(enemy: EnemyBase) -> void:
	enemy.died.connect(_on_enemy_died)
	if enemy.counts_for_clear:
		_enemies_alive += 1


## Предметы сами встают в свои группы (hide_spots, keys, exits, lamps) в _ready.
func _add_prop(prop: Node2D, pos: Vector2) -> void:
	prop.position = pos
	props.add_child(prop)


func _on_enemy_died() -> void:
	_enemies_alive -= 1
	if _enemies_alive <= 0 and not player.is_dead:
		clear_label.show()


func _on_player_died() -> void:
	clear_label.hide()
	objective_label.hide()
	death_label.show()


func _unhandled_input(event: InputEvent) -> void:
	# Рестарт в любой момент — как в HM, умирать и начинать заново надо быстро
	if event.is_action_pressed("restart"):
		get_tree().paused = false
		get_tree().reload_current_scene()
		return

	# Отладка: 1 — тест боя, 2 — тест стелса, 3 — мотель, 4 — подвал
	var key_event := event as InputEventKey
	if key_event and key_event.pressed and not key_event.echo:
		var level: String = DEBUG_LEVELS.get(key_event.physical_keycode, "")
		if level != "":
			get_tree().paused = false
			get_tree().change_scene_to_file(level)
