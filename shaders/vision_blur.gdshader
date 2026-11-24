// Маска поля зрения: размываем её и умножаем на неё картинку игры.
// Размытие делает край зрения мягким. Маска рисуется в полном размере экрана,
// поэтому у края нет «лесенки» (ступенек), только плавный переход.
shader_type canvas_item;
render_mode blend_mul, unshaded;

// Радиус размытия в пикселях экрана (больше — мягче край зрения)
uniform float blur_radius = 4.0;

void fragment() {
	// Сетка 5x5 точек вокруг пикселя, ближние точки весят больше (как гауссово размытие)
	vec2 step_size = TEXTURE_PIXEL_SIZE * blur_radius * 0.5;
	vec3 sum = vec3(0.0);
	float total = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float weight = exp(-float(x * x + y * y) / 4.0);
			sum += texture(TEXTURE, UV + vec2(float(x), float(y)) * step_size).rgb * weight;
			total += weight;
		}
	}
	COLOR = vec4(sum / total, 1.0);
}
