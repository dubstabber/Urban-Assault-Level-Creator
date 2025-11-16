shader_type spatial;
render_mode cull_disabled, depth_draw_always;

// Sector top surface shader with world-space tiling.
// Supports atlas textures composed of an NxM grid (e.g., UA ground textures are 2x2 variants).

uniform sampler2D ground_texture : source_color, filter_linear, repeat_enable;
uniform float tile_scale : hint_range(0.0001, 0.01) = 0.000333; // world units to UV scale (~1 tile per ~3 sectors)
uniform vec2 atlas_grid = vec2(1.0, 1.0); // e.g., vec2(2,2) for 2x2 atlas
uniform int variant = 0;                  // global fallback atlas cell (0..atlas_grid.x*atlas_grid.y-1)
uniform bool use_vertex_variant = true;   // if true, decode per-sector variant from vertex COLOR

// Pass world position from vertex to fragment shader
varying vec3 world_position;

void vertex() {
	// Calculate world position in vertex shader for accurate world-space UVs
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Use world position for tiling (calculated in vertex shader)
	// This ensures textures stay fixed in world space regardless of camera movement
	vec2 tile_uv = world_position.xz * tile_scale;
	vec2 base = fract(tile_uv);

	// Atlas slicing: map base UVs into the selected atlas cell
	float cols = max(1.0, atlas_grid.x);
	float rows = max(1.0, atlas_grid.y);
	float total_cells = max(1.0, cols * rows);

	int variant_index = variant;
	if (use_vertex_variant) {
		// COLOR.r encodes the atlas cell as (cell+0.5)/total_cells.
		// This keeps selection stable per sector while allowing 2x2 atlases.
		float encoded = clamp(COLOR.r, 0.0, 0.9999);
		variant_index = int(floor(encoded * total_cells));
	}

	float fx = mod(float(variant_index), cols);
	float fy = floor(float(variant_index) / cols);
	vec2 cell_size = vec2(1.0 / cols, 1.0 / rows);
	vec2 offset = vec2(fx, fy) * cell_size;
	vec2 atlas_uv = offset + base * cell_size;

	// Sample the ground texture
	vec4 col = texture(ground_texture, atlas_uv);

	ALBEDO = col.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.2;
}

