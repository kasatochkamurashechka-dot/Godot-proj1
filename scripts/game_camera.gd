extends Camera2D
## Камера в стиле HM: следует за героем и смещается в сторону курсора,
## чтобы было видно, что впереди. Умеет трястись (add_shake).

const LOOK_AHEAD := 0.4     # насколько сильно камера тянется к курсору (0 — совсем не тянется)
const MAX_LOOK := 120.0     # максимальное смещение к курсору, в пикселях
const FOLLOW_SPEED := 8.0   # плавность смещения (больше — резче)
const SHAKE_DECAY := 40.0   # как быстро затухает тряска

var _look_offset := Vector2.ZERO
var _shake := 0.0


func _process(delta: float) -> void:
	# Берём позицию мыши относительно центра экрана, а не мировую позицию.
	# Иначе камера, сдвигаясь, сдвигала бы и «мировую мышь» и уезжала бы сама по себе.
	var screen_center := get_viewport_rect().size / 2.0
	var mouse_from_center := get_viewport().get_mouse_position() - screen_center
	var target := (mouse_from_center * LOOK_AHEAD).limit_length(MAX_LOOK)

	# Плавное приближение к цели (не зависит от частоты кадров)
	_look_offset = _look_offset.lerp(target, 1.0 - exp(-FOLLOW_SPEED * delta))

	var shake_offset := Vector2.ZERO
	if _shake > 0.0:
		shake_offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		_shake = move_toward(_shake, 0.0, SHAKE_DECAY * delta)

	offset = _look_offset + shake_offset


## Встряхнуть камеру. strength — сила тряски в пикселях.
func add_shake(strength: float) -> void:
	_shake = max(_shake, strength)
