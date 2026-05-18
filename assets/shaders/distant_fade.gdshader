shader_type spatial;
render_mode blend_mix, unshaded, cull_front, depth_draw_never, fog_disabled;

uniform vec4 color : source_color = vec4(0.0, 0.013, 0.051, 0.8);
uniform float wave_amplitude : hint_range(0.0, 5.0) = 1.5;
uniform float wave_speed : hint_range(0.0, 2.0) = 0.35;
uniform float wave_frequency : hint_range(1.0, 20.0) = 5.0;

void vertex() {
	float angle = atan(VERTEX.x, VERTEX.z);

	// Two overlapping waves at different frequencies for organic underwater motion
	float wave = sin(angle * wave_frequency + TIME * wave_speed) * wave_amplitude;
	wave += sin(angle * wave_frequency * 0.6 + VERTEX.y * 0.08 + TIME * wave_speed * 1.4) * wave_amplitude * 0.45;

	vec2 dir = normalize(VERTEX.xz);
	VERTEX.x += dir.x * wave;
	VERTEX.z += dir.y * wave;
}

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
