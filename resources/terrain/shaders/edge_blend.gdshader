shader_type spatial;
render_mode cull_disabled, depth_draw_always;

// Edge strip blend between two ground textures.
// World-space UVs, with support for atlas textures (e.g., 2x2 variants).

uniform sampler2D texture_a : source_color, filter_linear, repeat_enable;
uniform sampler2D texture_b : source_color, filter_linear, repeat_enable;
uniform float tile_scale : hint_range(0.0001, 0.01) = 0.000333; // world units to UV scale (~1 tile per ~3 sectors)
uniform bool vertical_seam = false; // true for vertical seams, false for horizontal
uniform vec2 atlas_grid = vec2(1.0, 1.0); // e.g., vec2(2,2) for 2x2 atlases
uniform int variant_a = 0;                // atlas cell for texture_a
uniform int variant_b = 0;                // atlas cell for texture_b

varying vec3 world_position;

void vertex() {
	// Calculate world position in vertex shader for stable world-space UVs
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Use world position for tiling (stable, camera-independent)
	vec2 tile_uv = world_position.xz * tile_scale;
	vec2 base = fract(tile_uv);

	// Atlas slicing for A
	float cols = max(1.0, atlas_grid.x);
	float rows = max(1.0, atlas_grid.y);
	float fx_a = mod(float(variant_a), cols);
	float fy_a = floor(float(variant_a) / cols);
	vec2 cell_size = vec2(1.0 / cols, 1.0 / rows);
	vec2 offset_a = vec2(fx_a, fy_a) * cell_size;
	vec2 uv_a = offset_a + base * cell_size;

	// Atlas slicing for B
	float fx_b = mod(float(variant_b), cols);
	float fy_b = floor(float(variant_b) / cols);
	vec2 offset_b = vec2(fx_b, fy_b) * cell_size;
	vec2 uv_b = offset_b + base * cell_size;

	// sample both textures
	vec4 col_a = texture(texture_a, uv_a);
	vec4 col_b = texture(texture_b, uv_b);

	float t = vertical_seam ? UV.y : UV.x; // blend direction
	t = clamp(t, 0.0, 1.0);

	vec3 albedo = mix(col_a.rgb, col_b.rgb, t);
	ALBEDO = albedo;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.2;
}

