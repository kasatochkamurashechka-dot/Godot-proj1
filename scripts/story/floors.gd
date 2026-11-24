extends RefCounted

# The two floors share one footprint per floor across every loop.
static func build(level, area: String, ruined: bool) -> void:
	var room = level.room
	if area == "cellar":
		# A pump gallery joins the existing east corridor at its outer wall.
		for x in range(59, 88):
			for y in range(12, 24):
				var edge := x == 87 or y == 12 or y == 23 or (x == 59 and y > 15)
				var tile := 1 if edge else (9 if y == 17 else 8)
				room.set_cell(Vector2i(x,y),0,Vector2i(tile,0))
		level.prop(Furniture.Kind.BOILER,1336,330,48,42)
		level.prop(Furniture.Kind.STAIRS,1360,227,40,28)
		level.sign_at("НАСОСНАЯ   /   -1",1220,218)
		level.prop(Furniture.Kind.PIPES,1150,315,118,12)
		level.lamp(1220,206,3,true)
		return
	for y in range(23):
		for x in range(65):
			var tile := 0
			if area == "parking":
				tile = 7 if y == 4 else 3
			elif y >= 11 and y <= 15:
				tile = 2
			var wall := x == 0 or y == 0 or x == 64 or y == 22
			if area != "parking":
				wall = wall or (y < 10 and x in [16,32,48])
				wall = wall or (y == 10 and x % 16 not in [7,8])
			room.set_cell(Vector2i(x,y),0,Vector2i(1 if wall else tile,0))
	if area == "parking":
		for x in [144,480,650]:
			var car = level.prop(Furniture.Kind.CAR,x,192,34,64)
			car.color = Color("#ed792d") if x == 144 else Color("#457078")
		level.prop(Furniture.Kind.VENDING,840,100,28,24)
		level.sign_at("МОТЕЛЬ  •  3:33",810,75)
		level.sign_at("ТРАССА  66",425,55)
		level.sign_at("Ресепшен   →",264,205)
		return
	for i in range(4):
		var door := Door.new()
		door.length = 2
		door.position = Vector2(128+i*256,168)
		door.locked = area == "lobby" and i == 1 and ruined
		level.props.add_child(door)
		level.lamp(100+i*256,22,3 if ruined else 2,ruined)
	if ruined:
		level.prop(Furniture.Kind.CRATES,350,214,92,24)
		level.prop(Furniture.Kind.SHELF,630,256,20,90)
		level.prop(Furniture.Kind.CRATES,920,290,56,36)
	if area == "upper":
		for i in range(4):
			level.prop(Furniture.Kind.BED,62+i*256,65,36,52)
			level.prop(Furniture.Kind.DESK,194+i*256,53,36,22)
			level.sign_at(str(203+i),118+i*256,149)
		level.prop(Furniture.Kind.STAIRS,72,306,55,40)
		level.prop(Furniture.Kind.STAIRS,963,306,55,40)
		if ruined:
			level.prop(Furniture.Kind.SHELF,580,90,60,16)
			level.prop(Furniture.Kind.CRATES,736,105,32,24)
	else:
		level.sign_at("РЕСЕПШЕН   •   3:33",50,45)
		level.sign_at("Ресепшен ↑     Ресторан →     Персонал →",175,231)
		level.sign_at("← Парковка     Котельная →",710,306)
		level.prop(Furniture.Kind.COUNTER,136,85,100,18)
		level.sign_at("ЗАКУСОЧНАЯ",325,45)
		for x in [324,446]:
			level.prop(Furniture.Kind.DESK,x,88,44,28)
		level.sign_at("ПЕРСОНАЛ",605,45)
		level.prop(Furniture.Kind.DESK,650,82,54,20)
		level.sign_at("КОТЕЛЬНАЯ",844,45)
		level.prop(Furniture.Kind.BOILER,955,70,54,46)
		level.prop(Furniture.Kind.STAIRS,912,115,50,32)
		level.prop(Furniture.Kind.STAIRS,78,306,55,40)
		level.hide_at(HideSpot.Kind.WARDROBE,250,227)
		level.hide_at(HideSpot.Kind.BATH,570,115)
		level.prop(Furniture.Kind.DUMPSTER,810,268,32,26)
		level.hide_at(HideSpot.Kind.DUMPSTER,810,268)
