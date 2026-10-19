shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

// Stylised pixel water: depth-tinted, with a pixelated foam line around anything
// that pokes through the surface and twinkling sparkles.

uniform vec3 shallow_color : source_color = vec3(0.27, 0.53, 0.58);
uniform vec3 deep_color : source_color = vec3(0.12, 0.29, 0.40);
uniform vec3 foam_color : source_color = vec3(0.93, 0.97, 1.0);
uniform float depth_range = 1.4;
uniform float foam_width = 0.22;
uniform float pixels_per_unit = 16.0;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Snap to the pixel grid so effects stay crisp like the textures.
	vec2 px = floor(world_pos.xz * pixels_per_unit) / pixels_per_unit;

	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	float diff = VERTEX.z - view.z;

	float t = clamp(diff / depth_range, 0.0, 1.0);
	vec3 col = mix(shallow_color, deep_color, t);

	// Gentle bands of lighter water drifting across.
	float band = sin(px.x * 0.9 + px.y * 0.6 + TIME * 0.8) * sin(px.y * 1.3 - TIME * 0.5);
	col += step(0.75, band) * 0.04;

	float wobble = 0.06 * sin(TIME * 2.0 + px.x * 2.7 + px.y * 1.9);
	float foam = step(diff, foam_width + wobble);
	float foam_dots = step(diff, foam_width * 2.2 + wobble) * step(0.82, hash(px + floor(TIME * 3.0)));
	float sparkle = step(0.9988, hash(px * 1.37 + floor(TIME * 2.0)));
	col = mix(col, foam_color, clamp(foam + foam_dots * 0.7 + sparkle, 0.0, 1.0));

	ALBEDO = col;
	ALPHA = mix(0.86, 0.97, t) + foam * 0.1;
	ROUGHNESS = 0.15;
	SPECULAR = 0.4;
}
