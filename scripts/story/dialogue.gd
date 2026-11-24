extends Panel

var line := Label.new()
var speaker := Label.new()
var voice := AudioStreamPlayer.new()
var lines: Array
var finished: Callable
var shown := 0.0
var last_pulse := 0

func _ready() -> void:
	position = Vector2(30,241)
	size = Vector2(580,104)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#18151ff5")
	box.border_color = Color("#d68d54")
	box.border_width_left = 3
	add_theme_stylebox_override("panel", box)
	add_child(speaker)
	speaker.position = Vector2(17,5)
	speaker.modulate = Color("#f4bb83")
	speaker.add_theme_font_size_override("font_size",13)
	add_child(line)
	line.position = Vector2(17,26)
	line.size = Vector2(546,50)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size",15)
	var next := Label.new()
	next.text = "Enter  ›"
	next.position = Vector2(510,76)
	next.add_theme_font_size_override("font_size",12)
	add_child(next)
	add_child(voice)
	voice.stream = preload("res://assets/story/voice.wav")
	hide()

func begin(script: Array, callback: Callable) -> void:
	lines = script.duplicate()
	finished = callback
	get_tree().paused = true
	show()
	next_line()

func advance() -> void:
	if line.visible_characters < line.text.length():
		line.visible_characters = line.text.length()
		shown = line.text.length()
	elif lines.is_empty():
		hide()
		get_tree().paused = false
		finished.call()
	else:
		next_line()

func next_line() -> void:
	var parts := str(lines.pop_front()).split("|",true,1)
	speaker.text = parts[0]
	line.text = parts[1]
	line.visible_characters = 0
	shown = 0
	last_pulse = -1
	voice.pitch_scale = {"Хозяин":0.65,"Горничная":1.6,"Гость":0.8}.get(speaker.text,1.12)

func _process(delta: float) -> void:
	if visible and shown < line.text.length():
		shown += delta*40
		line.visible_characters = mini(int(shown),line.text.length())
		var pulse := floori(shown/3)
		if pulse != last_pulse and speaker.text not in ["Записка","3:33"]:
			voice.play()
		last_pulse = pulse
