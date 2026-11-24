// Пост-эффект «старая VHS-кассета». Накладывается на весь экран
// (ColorRect на отдельном CanvasLayer поверх игры, но под интерфейсом).
// Параметры (uniform) можно крутить в редакторе: PostFX → Screen → Material.

shader_type canvas_item;

// Снимок экрана под этим слоем — его мы и обрабатываем
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

uniform float aberration = 0.8;          // расслоение цветов (в пикселях), сильнее к краям
uniform float scanline_strength = 0.10;  // полосы развёртки
uniform float noise_strength = 0.05;     // шум плёнки
uniform float vignette_strength = 0.5;   // затемнение углов
uniform float pulse_strength = 0.03;     // медленное «дыхание» яркости
uniform float jitter = 0.5;              // дрожание строк, как у плёнки (в пикселях)
uniform float glitch = 0.0;              // 0..1 — сила глитча, меняется из кода (post_fx.gd)

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	float t = TIME;

	// Глитч: горизонтальные полосы экрана резко сдвигаются вбок
	if (glitch > 0.0) {
		float band = floor(uv.y * 36.0);
		float r = rand(vec2(band, floor(t * 24.0)));
		if (r < glitch * 0.6) {
			uv.x += (rand(vec2(band, t)) - 0.5) * 0.1 * glitch;
		}
	}

	// Дрожание строк
	float row = floor(uv.y / px.y);
	uv.x += (rand(vec2(row, floor(t * 12.0))) - 0.5) * px.x * jitter;

	// Расслоение цветов: красный и синий каналы чуть разъезжаются
	float edge = length(uv - 0.5) * 2.0;
	float shift = (aberration + glitch * 6.0) * px.x * (0.4 + edge);
	vec3 col;
	col.r = texture(screen_texture, uv + vec2(shift, 0.0)).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - vec2(shift, 0.0)).b;

	// Полосы развёртки: каждая вторая строка чуть темнее
	col *= 1.0 - scanline_strength * (sin((row + 0.5) * 3.14159) * 0.5 + 0.5);

	// Шум плёнки
	col += (rand(uv * 113.0 + t) - 0.5) * noise_strength;

	// Медленное «дыхание» яркости
	col *= 1.0 + sin(t * 2.0) * pulse_strength;

	// Виньетка: углы темнее
	col *= 1.0 - vignette_strength * smoothstep(0.5, 1.4, edge);

	COLOR = vec4(col, 1.0);
}
