extends Node2D
var inscription: String

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(inscription,HORIZONTAL_ALIGNMENT_LEFT,-1,9).x
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.83))
	var plate := Rect2(-4,-1,width+8,15)
	draw_rect(plate,Color("#524a45"))
	draw_line(plate.position,Vector2(plate.end.x,plate.position.y),Color("#292527"))
	draw_line(Vector2(plate.position.x,plate.end.y),plate.end,Color("#9b8980"))
	draw_string(font,Vector2(0,10),inscription,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("#c3b49c"))
	draw_string(font,Vector2(0,9),inscription,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("#211e21"))
