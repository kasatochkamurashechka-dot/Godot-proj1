extends Node2D

var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(300,158),Vector2(340,158),Vector2(615,360),Vector2(25,360)]),Color("#25232e"))
	for i in range(7):
		var t := fmod(i/7.0+elapsed*0.48,1.0)
		var y := 158+202*t*t
		draw_rect(Rect2(320-t*3,y,1+5*t,1+13*t),Color("#c6ab7c"))
		for side in [-1,1]:
			draw_circle(Vector2(320+side*(24+300*t*t),154-160*t*t),1+4*t,Color("#e8a155"))
