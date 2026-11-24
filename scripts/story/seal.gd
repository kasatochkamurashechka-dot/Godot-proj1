extends Node2D

func _draw() -> void:
	draw_rect(Rect2(-17,-5,34,10), Color("#4c393d"))
	var ink := Color("#e0ba82")
	for i in range(4):
		var x := -13 + 7*i
		draw_line(Vector2(x,-3),Vector2(x,3),ink)
		draw_line(Vector2(x,1),Vector2(x+4,-3+i%2),ink)
		if i % 2 == 0:
			draw_line(Vector2(x,-3),Vector2(x+4,1),ink)
