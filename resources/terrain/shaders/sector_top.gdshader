shader_type spatial;
render_mode cull_disabled, depth_draw_always;

// Sector top surface shader with world-space tiling.
// Supports atlas textures composed of an NxM grid (e.g., UA ground textures are 2x2 variants).

uniform sampler2D ground_texture : source_color, filter_linear, repeat_disable; // fallback single
uniform sampler2D ground0 : source_color, filter_linear, repeat_disable;
uniform sampler2D ground1 : source_color, filter_linear, repeat_disable;
uniform sampler2D ground2 : source_color, filter_linear, repeat_disable;
uniform sampler2D ground3 : source_color, filter_linear, repeat_disable;
uniform sampler2D ground4 : source_color, filter_linear, repeat_disable;
uniform sampler2D ground5 : source_color, filter_linear, repeat_disable;
uniform float tile_scale : hint_range(0.0001, 0.01) = 0.000333; // world units to UV scale (~1 tile per ~3 sectors)
uniform vec2 atlas_grid = vec2(1.0, 1.0); // e.g., vec2(2,2) for 2x2 atlas (fallback)
uniform int variant = 0;                  // global fallback atlas cell (0..atlas_grid.x*atlas_grid.y-1)
uniform bool use_vertex_variant = true;   // if true, decode per-sector variant from vertex COLOR
uniform bool use_mesh_uv = true;          // if true, take base UV from mesh UVs; otherwise use world-space tiling
uniform bool use_multi_textures = true;   // if true, pick among ground0..ground5 via COLOR.g
uniform int debug_mode = 0;

// Pass world position from vertex to fragment shader
varying vec3 world_position;

void vertex() {
	// Calculate world position in vertex shader for accurate world-space UVs
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Use world position for tiling (calculated in vertex shader)
	// For composition from sub-quads we want exact mesh UVs; otherwise world tiling
	vec2 base;
	if (use_mesh_uv) {
		base = UV;
	} else {
		vec2 tile_uv = world_position.xz * tile_scale;
		base = fract(tile_uv);
	}

    // File selection: COLOR.g encodes file index as (file+0.5)/6.
    int file_index = 0;
    if (use_multi_textures) {
        file_index = int(floor(clamp(COLOR.g, 0.0, 0.9999) * 6.0));
    }

    // Per-file grid: 4x4 for file 4, else 2x2
    float cols = (file_index == 4) ? 4.0 : 2.0;
    float rows = (file_index == 4) ? 4.0 : 2.0;
    if (!use_vertex_variant) { cols = max(1.0, atlas_grid.x); rows = max(1.0, atlas_grid.y); }
    float total_cells = max(1.0, cols * rows);

    int variant_index = variant;
    if (use_vertex_variant) {
        float encoded = clamp(COLOR.r, 0.0, 0.9999);
        variant_index = int(floor(encoded * total_cells));
    }

    float fx = mod(float(variant_index), cols);
    float fy = floor(float(variant_index) / cols);
    vec2 cell_size = vec2(1.0 / cols, 1.0 / rows);
    vec2 offset = vec2(fx, fy) * cell_size;
    // Compute half-texel padding for the selected texture to avoid bleeding across atlas cells
    vec2 tex_size = vec2(textureSize(ground0, 0));
    if (file_index == 1)      tex_size = vec2(textureSize(ground1, 0));
    else if (file_index == 2) tex_size = vec2(textureSize(ground2, 0));
    else if (file_index == 3) tex_size = vec2(textureSize(ground3, 0));
    else if (file_index == 4) tex_size = vec2(textureSize(ground4, 0));
    else if (file_index == 5) tex_size = vec2(textureSize(ground5, 0));
    vec2 pad = vec2(0.5) / max(tex_size, vec2(1.0)); // half-pixel in normalized UV space
    vec2 uv_scale = max(cell_size - pad * 2.0, vec2(0.0));
    vec2 atlas_uv = offset + pad + base * uv_scale;

    vec4 col;
    if (debug_mode == 1) {
        vec3 m = vec3(float(file_index) / 5.0, 0.0, 1.0 - float(file_index) / 5.0);
        col = vec4(m, 1.0);
    } else if (debug_mode == 2) {
        float denom = max(1.0, total_cells - 1.0);
        float vnorm = float(variant_index) / denom;
        col = vec4(vec3(vnorm, vnorm, vnorm), 1.0);
    } else {
        // Sample the selected ground texture
        if (!use_multi_textures) {
            col = texture(ground_texture, atlas_uv);
        } else {
            if (file_index == 0)      col = texture(ground0, atlas_uv);
            else if (file_index == 1) col = texture(ground1, atlas_uv);
            else if (file_index == 2) col = texture(ground2, atlas_uv);
            else if (file_index == 3) col = texture(ground3, atlas_uv);
            else if (file_index == 4) col = texture(ground4, atlas_uv);
            else                      col = texture(ground5, atlas_uv);
        }
    }

	ALBEDO = col.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.2;
}
