extends Node2D

func _draw() -> void:
	draw_rect(Rect2(-68,-62,136,55),Color("#5e4942"))
	for x in range(-66,64,11):
		draw_line(Vector2(x,-50),Vector2(x,-13),Color("#7a6356"))
	for x in [-50,26]:
		draw_rect(Rect2(x,-43,24,23),Color("#a8bfb5"))
		draw_rect(Rect2(x+2,-41,20,18),Color("#294251"))
	draw_rect(Rect2(-18,-49,36,45),Color("#e0ba8b"))
	draw_rect(Rect2(-15,-46,30,41),Color("#343540"))
	draw_rect(Rect2(-11,-43,22,21),Color("#637b7e"))
	draw_circle(Vector2(10,-15),2,Color.WHEAT)
	draw_rect(Rect2(-26,-5,52,6),Color("#837974"))
	draw_rect(Rect2(-30,1,60,5),Color("#b7a79a"))
	draw_rect(Rect2(-72,-64,144,12),Color("#782f37"))
	draw_line(Vector2(-72,-55),Vector2(72,-55),Color("#f88b70"),2)
	draw_string(ThemeDB.fallback_font,Vector2(-67,-55),"M O T E L    •    3 : 3 3",HORIZONTAL_ALIGNMENT_CENTER,134,9,Color.WHEAT)
