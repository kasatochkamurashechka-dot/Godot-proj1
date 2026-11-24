@tool  # в редакторе видна жёлтая рамка зоны перехода
class_name LevelExit
extends Node2D
## Переход на другую карту: лестница из котельной в подвал, люк из подвала в контору и обратно.
## Подойди и нажми E / ПКМ — загрузится карта target_scene, и герой появится
## в её точке target_spawn (узел SpawnPoints/<имя> в той сцене).
## С собой герой уносит оружие, ключи и включённый или выключенный фонарик (см. Game.travel).
##
## Как поставить: перетащи scenes/props/level_exit.tscn в сцену (лучше в Props/Exits),
## положи поверх лестницы или люка и задай размер зоны (size), карту и точку появления.
## Сам переход ничего не рисует: лестницу рисует мебель, люк — декор.

## Карта, куда ведёт переход
@export_file("*.tscn") var target_scene := ""
## Имя точки появления в той карте (узел SpawnPoints/<имя>)
@export var target_spawn := ""
## Подсказка, когда герой рядом (ключ из translations/texts.csv)
@export var hint_key := "HINT_GO_DOWN"
## Размер зоны в пикселях
@export var size := Vector2(32, 32):
	set(value):
		size = value
		queue_redraw()
## Работает ли переход. В петлях, где путь закрыт, можно снять галочку
@export var enabled := true

const REACH := 22.0  # с какого расстояния от края зоны можно пройти


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("level_exits")  # по этой группе переходы находит герой


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not enabled:
		return
	# Герой рядом — напоминаем, что тут можно пройти
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and not player.is_dead and not player.is_hidden \
			and distance_to_point(player.global_position) <= REACH:
		Game.show_hint(hint_key, 0.15)


## Расстояние от точки до края зоны (0 — внутри).
func distance_to_point(point: Vector2) -> float:
	var local := to_local(point)
	return local.clamp(-size / 2.0, size / 2.0).distance_to(local)


## Герой нажал E рядом — переходим.
func use(player: Player) -> void:
	if enabled and target_scene != "":
		Game.travel(target_scene, target_spawn, player)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(-size / 2.0, size), Color(1, 0.9, 0.3, 0.7), false, 1.0)
		draw_string(ThemeDB.fallback_font, -size / 2.0 + Vector2(1, 9), "→", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color(1, 0.9, 0.3))
