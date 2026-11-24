extends ColorRect
## Управляет пост-эффектом VHS (shaders/vhs.gdshader).
## Глитч вызывается через Game.glitch(...) и плавно затухает.

var _glitch := 0.0
var _decay := 1.0  # на сколько в секунду ослабевает глитч


## Вызвать глитч силой amount (0..1), который затухнет за duration секунд.
func glitch(amount: float, duration := 0.5) -> void:
	if amount >= _glitch:
		_glitch = amount
		_decay = amount / maxf(duration, 0.01)


func _process(delta: float) -> void:
	_glitch = move_toward(_glitch, 0.0, _decay * delta)
	(material as ShaderMaterial).set_shader_parameter("glitch", _glitch)
