shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float grade_strength : hint_range(0.0, 1.0) = 0.82;
uniform float saturation : hint_range(0.0, 1.2) = 0.9;
uniform float contrast : hint_range(0.6, 1.2) = 0.95;
uniform vec3 lift_color = vec3(0.028, 0.032, 0.036);
uniform float lift_strength : hint_range(0.0, 0.2) = 0.045;
uniform vec3 shadow_tint = vec3(0.86, 0.97, 0.95);
uniform float shadow_tint_strength : hint_range(0.0, 0.3) = 0.12;
uniform vec3 edge_tint = vec3(0.72, 0.86, 0.9);
uniform float edge_tint_strength : hint_range(0.0, 0.2) = 0.045;
uniform float caustic_strength : hint_range(0.0, 0.08) = 0.014;
uniform float caustic_speed : hint_range(0.0, 2.0) = 0.16;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 src = texture(screen_tex, uv).rgb;
	float luma = dot(src, vec3(0.299, 0.587, 0.114));

	vec3 desaturated = mix(vec3(luma), src, saturation);
	vec3 graded = mix(src, desaturated, grade_strength);
	graded = mix(vec3(0.5), graded, contrast);

	float shadow_mask = 1.0 - smoothstep(0.14, 0.58, luma);
	vec3 shadow_target = graded * shadow_tint;
	graded = mix(graded, shadow_target, shadow_mask * shadow_tint_strength);
	graded = mix(graded, max(graded, lift_color), lift_strength);

	vec2 centered = uv - vec2(0.5);
	float edge_mask = smoothstep(0.18, 0.8, length(centered));
	graded = mix(graded, graded * edge_tint, edge_mask * edge_tint_strength);

	float wave_a = sin((uv.x * 11.0 + uv.y * 3.6) + TIME * caustic_speed);
	float wave_b = sin((uv.x * 17.0 - uv.y * 6.5) - TIME * caustic_speed * 1.35);
	float caustic_pattern = wave_a * 0.6 + wave_b * 0.4;
	float caustic = smoothstep(0.62, 0.95, caustic_pattern);
	float caustic_mask = smoothstep(0.35, 0.82, luma);
	graded += vec3(0.012, 0.018, 0.02) * caustic * caustic_mask * caustic_strength * 24.0;

	COLOR = vec4(clamp(graded, vec3(0.0), vec3(1.0)), 1.0);
}
