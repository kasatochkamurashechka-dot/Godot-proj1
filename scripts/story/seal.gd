extends Node2D

func _draw() -> void:
	draw_rect(Rect2(-48,-70,96,72),Color("#30252f"))
	draw_arc(Vector2(0,-57),34,PI,TAU,32,Color("#846652"),7)
	draw_rect(Rect2(-34,-58,68,60),Color("#553f42"))
	for x in range(-32,33,8):
		draw_line(Vector2(x,-57),Vector2(x,0),Color("#342a31"),2)
	for y in [-48,-16]:
		draw_rect(Rect2(-36,y,72,5),Color("#877567"))
	draw_line(Vector2(0,-57),Vector2.ZERO,Color("#201d22"),3)
	draw_rect(Rect2(-26,-11,52,16),Color("#50434a"))
	draw_rect(Rect2(-32,-14,64,6),Color("#95827c"))
	for x in [-21,-14,17,24]:
		draw_rect(Rect2(x,-22,2,8),Color.WHEAT)
		draw_circle(Vector2(x+1,-23),2,Color.CORAL)
	var ink := Color("#e0ba82")
	for i in range(4):
		var x := -13 + 7*i
		draw_line(Vector2(x,-3),Vector2(x,3),ink)
		draw_line(Vector2(x,1),Vector2(x+4,-3+i%2),ink)
		if i % 2 == 0:
			draw_line(Vector2(x,-3),Vector2(x+4,1),ink)
