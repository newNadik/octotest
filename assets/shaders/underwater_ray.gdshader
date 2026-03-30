shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 ray_color : source_color = vec4(0.52, 0.86, 0.95, 1.0);
uniform float intensity : hint_range(0.0, 4.0) = 1.35;
uniform float alpha_strength : hint_range(0.0, 1.0) = 0.34;
uniform float edge_softness : hint_range(0.5, 8.0) = 3.2;
uniform float stripe_density : hint_range(2.0, 64.0) = 18.0;
uniform float scroll_speed : hint_range(0.0, 2.0) = 0.2;
uniform float cone_tip_width : hint_range(0.03, 0.6) = 0.12;
uniform float cone_power : hint_range(0.5, 3.0) = 1.15;
uniform float camera_fade_start : hint_range(0.0, 20.0) = 1.5;
uniform float camera_fade_end : hint_range(0.1, 40.0) = 8.0;
instance uniform float camera_fade : hint_range(0.0, 1.0) = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = clamp(UV.y, 0.0, 1.0);
	float cone_width = mix(cone_tip_width, 1.0, pow(t, cone_power));
	float x = abs(UV.x * 2.0 - 1.0) / max(0.001, cone_width);
	float radial = pow(max(0.0, 1.0 - x), edge_softness);
	float vertical_fade = smoothstep(0.0, 0.09, t) * (1.0 - smoothstep(0.9, 1.0, t) * 0.2);
	float stripes = 0.83 + 0.17 * sin((t * stripe_density + UV.x * 2.5) * 6.283185 + TIME * scroll_speed);
	float camera_dist = distance(CAMERA_POSITION_WORLD, world_pos);
	float camera_dist_fade = smoothstep(camera_fade_start, camera_fade_end, camera_dist);
	float fade = clamp(camera_fade * camera_dist_fade, 0.0, 1.0);
	float alpha = radial * vertical_fade * stripes * alpha_strength * fade;

	ALBEDO = ray_color.rgb * intensity * (0.7 + 0.3 * stripes);
	EMISSION = vec3(0.0);
	ALPHA = alpha;
}
