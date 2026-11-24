class_name LightTextures
## Помощник для 2D-света: рисует текстуры света кодом (картинки не нужны)
## и создаёт готовые источники света PointLight2D.
##
## Текстура света — это картинка-«маска»: где она светлее, там светит сильнее.
## Круглая (radial) — для ламп и свечения, конус (cone) — для фонариков.

const SIZE := 256  # размер текстуры в пикселях
const RADIAL_FALLOFF := 1.8  # как плавно гаснет круглое пятно к краю (больше — мягче край)
const CONE_SOFT_DEG := 16.0  # ширина размытого края у конуса фонарика, в градусах

## Тени. У каждого объекта своя обводка — замкнутый контур LightOccluder2D
## (обход по часовой стрелке, как видно на экране). Два режима:
##   • СТЕНА (CLOSED_CULL): обводка закрывает стену целиком — свет на неё не попадает,
##     тень идёт строго от её краёв;
##   • ПРЕДМЕТ на локации (OBJECT_CULL): сторона контура, повёрнутая к источнику, отсекается —
##     предмет освещён со стороны лампы, а за ним тень по его обводке.
##     Режим подобран замером: при нашем обходе ближнюю сторону отсекает CULL_COUNTER_CLOCKWISE.
const CLOSED_CULL := OccluderPolygon2D.CULL_DISABLED
const OBJECT_CULL := OccluderPolygon2D.CULL_COUNTER_CLOCKWISE
const SHADOW_FILTER := Light2D.SHADOW_FILTER_PCF13  # мягкий край тени (13 выборок)
const SHADOW_SMOOTH := 6.0   # насколько размыт край тени (0 — резкий)
## Слои обводок (какие источники их «видят»):
##   1 — стены и двери, 2 — мебель (с ней сталкиваются), 4 — сквозные укрытия (шкаф, ванна:
##   через них можно пройти, поэтому свет самих персонажей их не замечает — иначе фонарик
##   гас бы, пока Сэм идёт сквозь шкаф)
const SHADOW_LAYER_WALLS := 1
const SHADOW_LAYER_FURNITURE := 2
const SHADOW_LAYER_WALK_THROUGH := 4
## Маска для света, который носят персонажи (фонарики, свечение, «взгляд» хозяина)
const CHARACTER_SHADOW_MASK := SHADOW_LAYER_WALLS | SHADOW_LAYER_FURNITURE

# Сгенерированные текстуры храним, чтобы не рисовать заново для каждой лампы
static var _cache := {}
static var _unshaded: CanvasItemMaterial


## Круглое пятно света, яркое в центре и плавно гаснущее к краю.
static func radial() -> Texture2D:
	if _cache.has("radial"):
		return _cache["radial"]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var center := SIZE / 2.0
	for y in SIZE:
		for x in SIZE:
			var d := Vector2(x + 0.5 - center, y + 0.5 - center).length() / center
			var a := pow(clampf(1.0 - d, 0.0, 1.0), RADIAL_FALLOFF)
			img.set_pixel(x, y, Color(a, a, a, a))
	var tex := ImageTexture.create_from_image(img)
	_cache["radial"] = tex
	return tex


## Конус света, направленный вправо (+X). half_angle_deg — половина ширины конуса.
static func cone(half_angle_deg: float) -> Texture2D:
	var key := "cone_%d" % half_angle_deg
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var center := SIZE / 2.0
	var half := deg_to_rad(half_angle_deg)
	var soft := deg_to_rad(CONE_SOFT_DEG)  # мягкость краёв конуса
	for y in SIZE:
		for x in SIZE:
			var v := Vector2(x + 0.5 - center, y + 0.5 - center)
			var d := v.length() / center
			var angle := absf(v.angle())
			var in_cone := clampf((half + soft - angle) / (2.0 * soft), 0.0, 1.0)
			var falloff := pow(clampf(1.0 - d, 0.0, 1.0), 1.2)
			var glow := clampf(1.0 - d * 8.0, 0.0, 1.0) * 0.6  # небольшое пятно у самого фонаря
			var a := maxf(falloff * in_cone, glow)
			img.set_pixel(x, y, Color(a, a, a, a))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Создать источник света. light_range — радиус в пикселях игры.
static func make_light(texture: Texture2D, light_range: float, color: Color,
		energy := 1.0, shadows := true) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = texture
	light.texture_scale = light_range / (SIZE / 2.0)
	light.color = color
	light.energy = energy
	light.shadow_enabled = shadows
	light.shadow_filter = SHADOW_FILTER
	light.shadow_filter_smooth = SHADOW_SMOOTH
	# Тень дают все обводки: стены, двери, мебель, укрытия
	light.shadow_item_cull_mask = SHADOW_LAYER_WALLS | SHADOW_LAYER_FURNITURE | SHADOW_LAYER_WALK_THROUGH
	return light


## Обводка-прямоугольник size с центром в center (обход по часовой стрелке).
static func rect_points(size: Vector2, center := Vector2.ZERO) -> PackedVector2Array:
	var h := size / 2.0
	return PackedVector2Array([center - h, center + Vector2(h.x, -h.y), center + h, center + Vector2(-h.x, h.y)])


## Обводка объекта для теней: замкнутый контур points (обход по часовой стрелке).
## cull — OBJECT_CULL для предмета (освещён со стороны лампы) или CLOSED_CULL для стены.
static func make_occluder(points: PackedVector2Array, layer := SHADOW_LAYER_WALLS,
		cull := OBJECT_CULL) -> LightOccluder2D:
	var polygon := OccluderPolygon2D.new()
	polygon.polygon = points
	polygon.closed = true
	polygon.cull_mode = cull
	var occluder := LightOccluder2D.new()
	occluder.occluder = polygon
	occluder.occluder_light_mask = layer
	return occluder


## Материал «без освещения»: предмет с ним виден даже в полной темноте
## (светящиеся вещи — ключи, круги шума, значки над головой).
static func unshaded() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded
