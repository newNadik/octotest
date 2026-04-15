shader_type spatial;
render_mode blend_mix, unshaded, cull_back;

uniform sampler2D depth_texture : hint_depth_texture;
uniform float thickness : hint_range(0.5, 20.0, 0.1) = 3.0;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int samples : hint_range(4, 32) = 4;

uniform float sensitivity : hint_range(0.01, 1.0, 0.01) = 0.1;
uniform float edge_fade : hint_range(0.0, 0.1, 0.001) = 0.0;

void fragment() {
	vec2 pixel_size = 1.0 / VIEWPORT_SIZE;
	vec2 step_size = pixel_size * thickness;
	
	float angle_step = TAU / float(samples);
	
	vec3 avg_dx = vec3(0.0);
	vec3 avg_dy = vec3(0.0);
	
	// Pre-calculate screen UV adjustments
	vec2 screen_uv_normalized = SCREEN_UV * 2.0 - 1.0;
	
	// Sample in a circle around the pixel
	for (int i = 0; i < samples; i++) {
		float angle = float(i) * angle_step;
		vec2 dir = vec2(cos(angle), sin(angle));
		vec2 offset = dir * step_size;
		
		vec2 uv1 = SCREEN_UV + offset;
		vec2 uv2 = SCREEN_UV - offset;
		
		float d1 = texture(depth_texture, uv1).r;
		float d2 = texture(depth_texture, uv2).r;
		
		// Optimized inverse projection
		vec2 uv1_norm = uv1 * 2.0 - 1.0;
		vec2 uv2_norm = uv2 * 2.0 - 1.0;
		
		vec4 up1 = INV_PROJECTION_MATRIX * vec4(uv1_norm, d1, 1.0);
		vec4 up2 = INV_PROJECTION_MATRIX * vec4(uv2_norm, d2, 1.0);
		
		// Combine division and difference calculation
		vec3 diff = (up1.xyz / up1.w) - (up2.xyz / up2.w);
		
		// Accumulate weighted by direction
		avg_dx += diff * dir.x;
		avg_dy += diff * dir.y;
	}
	
	// Combine normalization with inverse samples
	float inv_samples = 1.0 / float(samples);
	avg_dx *= inv_samples;
	avg_dy *= inv_samples;
	
	// Edge detection
	vec3 normal = normalize(cross(avg_dy, avg_dx));
	float edge = 1.0 - smoothstep(sensitivity, sensitivity + 0.05, abs(dot(normal, VIEW)));
	
	// Optimized viewport edge fade
	vec2 screen_center_dist = abs(SCREEN_UV - 0.5) * 2.0;
	float max_dist = max(screen_center_dist.x, screen_center_dist.y);
	float vignette = smoothstep(0.0, edge_fade * thickness, 1.0 - max_dist);
	
	ALBEDO = outline_color.rgb;
	ALPHA = edge * vignette * outline_color.a;
}