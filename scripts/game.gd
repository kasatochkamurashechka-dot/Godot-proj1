extends Node
## Глобальный модуль Game (автозагрузка, autoload): доступен из любого скрипта как Game.xxx.
## Здесь собраны эффекты «сочности» и общие помощники.
## Подключён в project.godot, раздел [autoload].

## Сигнал «где-то прозвучал шум». Его слушают враги, которые умеют слышать (хозяин мотеля).
## pos — где шумели, radius — на каком расстоянии слышно.
signal noise_made(pos: Vector2, radius: float)

## Язык игры: "ru" — русский, "en" — английский.
## Все тексты лежат в translations/texts.csv (ключ, английский, русский).
## Позже переключатель языка появится в меню настроек.
const LANGUAGE := "ru"

## Звуки игры. Файлы создаёт tools/generate_sounds.py.
## Если у звука несколько вариантов — каждый раз берётся случайный (шаги не звучат одинаково).
const SOUNDS := {
	"step": ["res://assets/sounds/step_1.wav", "res://assets/sounds/step_2.wav", "res://assets/sounds/step_3.wav"],
	"swing": ["res://assets/sounds/swing.wav"],
	"punch": ["res://assets/sounds/punch.wav"],
	"hit_heavy": ["res://assets/sounds/hit_heavy.wav"],
	"gore": ["res://assets/sounds/gore.wav"],
	"land": ["res://assets/sounds/land.wav"],
	"wardrobe": ["res://assets/sounds/wardrobe.wav"],
	"death": ["res://assets/sounds/death.wav"],
	"growl": ["res://assets/sounds/growl.wav"],
	"transform": ["res://assets/sounds/transform.wav"],
	"creature_hit": ["res://assets/sounds/creature_hit.wav"],
	"owner_step": ["res://assets/sounds/owner_step.wav"],
	"spotted": ["res://assets/sounds/spotted.wav"],
	"key": ["res://assets/sounds/key.wav"],
	"escape": ["res://assets/sounds/escape.wav"],
	"neon_hum": ["res://assets/sounds/neon_hum.wav"],
	"ambient_stealth": ["res://assets/sounds/ambient_stealth.wav"],
	"ambient_combat": ["res://assets/sounds/ambient_combat.wav"],
	"door": ["res://assets/sounds/door.wav"],
	"door_locked": ["res://assets/sounds/door_locked.wav"],
	"rustle": ["res://assets/sounds/rustle.wav"],
	"bin_lid": ["res://assets/sounds/bin_lid.wav"],
	"flashlight": ["res://assets/sounds/flashlight.wav"],
	"splash": ["res://assets/sounds/splash.wav"],
}
## Эти звуки играют по кругу (фон и гул ламп)
const LOOPED := ["neon_hum", "ambient_stealth", "ambient_combat"]

var _hitstop_active := false
## Что герой уносит с собой при переходе на другую карту (см. travel / apply_arrival)
var _arrival := {}
var _streams := {}  # имя звука -> массив загруженных AudioStream


func _ready() -> void:
	TranslationServer.set_locale(LANGUAGE)
	# Звуки должны доигрывать и на паузе (например, аккорд побега)
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound_name in SOUNDS:
		var list: Array[AudioStream] = []
		for path in SOUNDS[sound_name]:
			var stream := load(path) as AudioStreamWAV
			if sound_name in LOOPED:
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				stream.loop_begin = 0
				stream.loop_end = int(stream.get_length() * stream.mix_rate)
			list.append(stream)
		_streams[sound_name] = list


## Получить звук по имени (случайный вариант, если их несколько).
func get_sound(sound_name: String) -> AudioStream:
	return _streams[sound_name].pick_random()


## Проиграть звук.
##   pos — где звучит. Если указана, звук «позиционный»: тише вдали и слышен с нужной стороны.
##         Vector2.INF (по умолчанию) — звук без места, просто играет (интерфейс, шаги героя).
##   volume_db — громкость в децибелах (0 — как есть, -6 — примерно вдвое тише).
##   pitch_spread — случайный разброс высоты, чтобы повторы звучали живее.
##   max_distance — дальше этого расстояния позиционный звук не слышно.
func play_sound(sound_name: String, pos := Vector2.INF, volume_db := 0.0,
		pitch_spread := 0.08, max_distance := 450.0) -> void:
	var stream := get_sound(sound_name)
	var player  # AudioStreamPlayer или AudioStreamPlayer2D — у обоих есть play() и finished
	if pos == Vector2.INF:
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = volume_db
		p.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
		player = p
	else:
		var p2 := AudioStreamPlayer2D.new()
		p2.stream = stream
		p2.volume_db = volume_db
		p2.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
		p2.max_distance = max_distance
		p2.position = pos
		player = p2
	add_child(player)
	player.finished.connect(player.queue_free)  # доиграл — удаляем
	player.play()


## Звук врага (шаги, рык, дверь): играет в точке pos, а если герой его слышит
## (ближе max_distance) — показывает красный кружок звука. Кружки рисуются поверх темноты,
## поэтому врага можно найти по звуку, даже не видя его.
func enemy_sound(sound_name: String, pos: Vector2, volume_db := 0.0,
		max_distance := 300.0, ring_radius := 12.0) -> void:
	play_sound(sound_name, pos, volume_db, 0.1, max_distance)
	var listener := get_tree().get_first_node_in_group("player") as Node2D
	var parent := get_tree().get_first_node_in_group("sound_marks")
	if listener == null or parent == null:
		return
	var distance := listener.global_position.distance_to(pos)
	if distance > max_distance:
		return
	var ring := NoiseRing.new()
	ring.max_radius = ring_radius
	ring.color = Color(1.0, 0.35, 0.3)
	ring.strength = 2.2 * (1.0 - 0.7 * distance / max_distance)  # дальше — бледнее
	parent.add_child(ring)
	ring.global_position = pos


## Перейти на другую карту (лестница, люк). spawn_name — точка появления
## (узел SpawnPoints/<имя> в новой сцене). Оружие, ключи и фонарик героя переносятся.
func travel(scene_path: String, spawn_name: String, player: Player) -> void:
	_arrival = {
		"spawn": spawn_name,
		"weapon": player.weapon,
		"has_key": player.has_key,
		"flashlight_on": player.flashlight_on,
	}
	play_sound("door", Vector2.INF, -8.0)
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(scene_path)


## Вызывает уровень (main.gd) при запуске: если герой пришёл с другой карты —
## ставим его в точку появления и возвращаем ему то, что он нёс.
func apply_arrival(level: Node, player: Player) -> void:
	if _arrival.is_empty():
		return
	var spawn := level.get_node_or_null("SpawnPoints/" + str(_arrival.spawn)) as Node2D
	if spawn:
		player.global_position = spawn.global_position
		player.rotation = spawn.rotation
	else:
		push_warning("Нет точки появления SpawnPoints/" + str(_arrival.spawn))
	player.weapon = _arrival.weapon
	player.has_key = _arrival.has_key
	if player.flashlight_on != _arrival.flashlight_on:
		player.toggle_flashlight()
	_arrival = {}
	glitch(0.3, 0.4)  # короткие помехи — «сменили место»


## Стоп-кадр: на долю секунды почти останавливаем время, чтобы удар ощущался весомым.
func hitstop(duration := 0.06) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.05
	# Таймер с ignore_time_scale = true идёт по реальному времени, а не по замедленному
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


## Встряхнуть текущую камеру.
func shake(strength: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("add_shake"):
		camera.add_shake(strength)


## Глитч экрана (VHS-помехи): amount — сила 0..1, duration — за сколько секунд затухнет.
func glitch(amount: float, duration := 0.5) -> void:
	var fx := get_tree().get_first_node_in_group("postfx")
	if fx:
		fx.glitch(amount, duration)


## Оставить лужу крови в точке pos. dir — направление удара (брызги летят туда).
func spawn_blood(pos: Vector2, dir: Vector2, amount := 1.0) -> void:
	var parent := get_tree().get_first_node_in_group("decals")
	if parent == null:
		return
	var splat := BloodSplat.new()
	splat.direction = dir
	splat.amount = amount
	parent.add_child(splat)
	splat.global_position = pos


## Нашуметь: оповестить врагов и показать расходящийся круг звука.
func make_noise(pos: Vector2, radius: float, visible_strength := 1.0) -> void:
	noise_made.emit(pos, radius)
	var parent := get_tree().get_first_node_in_group("decals")
	if parent == null:
		return
	var ring := NoiseRing.new()
	ring.max_radius = radius
	ring.strength = visible_strength
	parent.add_child(ring)
	ring.global_position = pos


## Показать короткую подсказку посередине экрана (например, «ЗАПЕРТО»).
## text_key — ключ из translations/texts.csv. Подсказку рисует уровень (main.gd).
func show_hint(text_key: String, seconds := 1.5) -> void:
	get_tree().call_group("level", "show_hint", text_key, seconds)


## Есть ли прямая видимость между точками (не мешают ли стены).
func line_of_sight(from: Vector2, to: Vector2) -> bool:
	var space := get_viewport().world_2d.direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)  # 1 — слой стен
	return space.intersect_ray(query).is_empty()
