extends Node

enum Beat { ARRIVAL, MAID, BED, WOUNDED, FIGHT, GUARD, CHASE, CAR, KEYS, DRIVE, RETURN, FREEZER, AMBUSH, NOTES, DOOR, END }
const GOALS := [
	"Дойти до стойки регистрации", "Подняться на второй этаж. Найти горничную",
	"Лечь спать в номере 204", "Проверить шум в соседнем номере 205",
	"Отбиться от постояльца", "Попросить помощи у сторожа в холле галереи",
	"Уйти через аварийный спуск", "Добраться до оранжевой машины",
	"Забрать ключи в комнате «Персонал»", "Вернуться к машине",
	"Прорваться через холл к лестнице в подвал", "Пройти насосную и осмотреть морозильник",
	"Найти ящики с меткой 205 в западном тупике", "Прочесть журнал в каморке к югу от ящиков",
	"Осмотреть дверь за колоннами", ""
]
var beat := Beat.ARRIVAL
var area := "parking"
var spawn := Vector2(188, 208)
var stair_arrival := false
var light_on := false
var checkpoint: Dictionary = {}

func remember(pos: Vector2) -> void:
	checkpoint = {"area": area, "beat": beat, "pos": pos, "light": light_on}

func restore() -> void:
	area = checkpoint.area
	beat = checkpoint.beat
	spawn = checkpoint.pos
	light_on = checkpoint.light

func reset() -> void:
	area = "parking"
	beat = Beat.ARRIVAL
	spawn = Vector2(188, 208)
	light_on = false
	checkpoint.clear()
