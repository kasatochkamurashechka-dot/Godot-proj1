class_name Weapons
## Характеристики оружия ближнего боя. Новое оружие добавляется сюда одной строкой.
##   title    — ключ названия для подписи в углу (сам текст — в translations/texts.csv)
##   reach    — дальность удара, пикселей
##   cooldown — пауза между ударами, секунд
##   length   — длина палки на картинке-заглушке
##   color    — цвет на картинке-заглушке

## Подпись, когда оружия в руках нет
const FISTS_TITLE := "WEAPON_FISTS"

const DATA := {
	"crowbar": {"title": "WEAPON_CROWBAR", "reach": 24.0, "cooldown": 0.35, "length": 11.0, "color": Color(0.7, 0.75, 0.85)},
	"bat": {"title": "WEAPON_BAT", "reach": 28.0, "cooldown": 0.45, "length": 14.0, "color": Color(0.85, 0.6, 0.35)},
	# Бутылка — в первую очередь чтобы бросать и отвлекать шумом, но ударить ею тоже можно
	"bottle": {"title": "WEAPON_BOTTLE", "reach": 18.0, "cooldown": 0.3, "length": 6.0, "color": Color(0.3, 0.8, 0.45)},
}

## Как громко падает брошенный предмет (радиус шума в пикселях)
const THROW_NOISE_RADIUS := 170.0


## Ключ названия оружия для экрана (Label сам переведёт его). Пустая строка — кулаки.
static func title_of(weapon_name: String) -> String:
	if weapon_name == "":
		return FISTS_TITLE
	return DATA[weapon_name].title
