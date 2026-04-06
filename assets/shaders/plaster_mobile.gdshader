shader_type spatial;
render_mode cull_back;

uniform vec3 upper_color : source_color = vec3(0.96, 0.97, 0.98);
uniform vec3 lower_color : source_color = vec3(0.18144298, 0.3341242, 0.430378);
uniform float global_floor_y = 0.0;
uniform float band_height = 1.5;
uniform float band_softness = 0.04;
uniform float roughness : hint_range(0.0, 1.0) = 0.58;

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float edge0 = global_floor_y + band_height - band_softness;
	float edge1 = global_floor_y + band_height + band_softness;
	float band_mask = 1.0 - smoothstep(edge0, edge1, world_y);

	ALBEDO = mix(upper_color, lower_color, band_mask);
	ROUGHNESS = roughness;
	METALLIC = 0.0;
}
