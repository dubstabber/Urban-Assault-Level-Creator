extends SceneTree

# Run with:
#   godot4 --headless -s res://scripts/generate_ground_textures.gd
# Generates six 512x512 tileable placeholder ground textures to:
#   res://resources/terrain/textures/common/ground_0.png .. ground_5.png

const OUT_DIR := "res://resources/terrain/textures/common"
const SIZE := 512

# Names for logs only
const NAMES := [
	"grass",    # 0
	"dirt",     # 1
	"concrete", # 2
	"rock",     # 3
	"water",    # 4
	"sand"      # 5
]

func _init() -> void:
	# Attempt to read base colors from Preloads singleton, else fall back to known values
	var colors: Array = []
	var pre = get_root().get_node_or_null("Preloads")
	if pre and pre.has_method("get"):
		var c = pre.get("_ground_fb_colors")
		if typeof(c) == TYPE_ARRAY and not c.is_empty():
			colors = c
	if colors.is_empty():
		colors = [
			Color(0.35, 0.55, 0.35), # grass
			Color(0.42, 0.30, 0.20), # dirt
			Color(0.55, 0.55, 0.55), # concrete
			Color(0.30, 0.30, 0.35), # rock
			Color(0.20, 0.35, 0.60), # water
			Color(0.70, 0.60, 0.45)  # sand
		]

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var failures := 0
	for i in range(6):
		var ok := _generate_one(i, colors[i])
		if not ok:
			failures += 1
	if failures == 0:
		print("Generated ground textures -> ", OUT_DIR)
		quit(0)
	else:
		push_error("Failed to generate %d textures" % failures)
		quit(1)

func _generate_one(idx: int, base_color: Color) -> bool:
	var path := "%s/ground_%d.png" % [OUT_DIR, idx]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	# Different pattern parameters per surface to avoid all looking the same
	var cycles := Vector2(6.0, 6.0)
	var amp := 0.14
	var checker := 8
	match idx:
		0: # grass
			cycles = Vector2(7.0, 9.0); amp = 0.16; checker = 8
		1: # dirt
			cycles = Vector2(9.0, 11.0); amp = 0.18; checker = 12
		2: # concrete
			cycles = Vector2(12.0, 12.0); amp = 0.08; checker = 16
		3: # rock
			cycles = Vector2(10.0, 7.0); amp = 0.20; checker = 10
		4: # water
			cycles = Vector2(4.0, 6.0); amp = 0.22; checker = 32
		5: # sand
			cycles = Vector2(8.0, 6.0); amp = 0.12; checker = 10

	for y in SIZE:
		for x in SIZE:
			var n := _tileable_noise(x, y, SIZE, SIZE, cycles.x, cycles.y)
			# Small checker overlay for micro-variation (tileable by design)
			var cx := int(floor(float(x) / checker))
			var cy := int(floor(float(y) / checker))
			var cmod := (cx + cy) & 1
			var checker_delta := 0.03
			if cmod == 0:
				checker_delta = -0.03

			# Convert noise to lighten/darken around base color
			var delta := (n - 0.5) * 2.0 # [-1..1]
			var col := base_color
			if delta >= 0.0:
				col = col.lightened(min(amp * delta, 0.5))
			else:
				col = col.darkened(min(amp * -delta, 0.5))

			# Apply checker micro-variation
			if checker_delta > 0.0:
				col = col.lightened(checker_delta)
			else:
				col = col.darkened(-checker_delta)

			# Water: slightly increase saturation and add gentle wave direction bias
			if idx == 4:
				# subtle blue tint and wave streaks along x
				var wave := 0.5 + 0.5 * sin(6.2831853 * (float(y) / SIZE) * 6.0)
				col = Color(col.r * 0.95, col.g * 0.97, min(col.b * 1.05 + 0.02 * wave, 1.0), 1.0)

			img.set_pixel(x, y, col)
	var err := img.save_png(path)
	if err != OK:
		push_error("Failed to save %s (err=%d)" % [path, err])
		return false
	return true

# Tileable pseudo-noise based on periodic sines, so it repeats seamlessly across edges
func _tileable_noise(x: int, y: int, w: int, h: int, cycles_x: float, cycles_y: float) -> float:
	var t_x := 6.2831853 * cycles_x * float(x) / float(w) # 2π * cycles * x/W
	var t_y := 6.2831853 * cycles_y * float(y) / float(h)
	var v := 0.0
	v += 0.50 * sin(t_x)
	v += 0.50 * cos(t_y)
	v += 0.25 * sin(t_x + t_y * 0.5)
	v += 0.15 * cos(t_x * 0.5 - t_y)
	# Normalize to 0..1 roughly
	v = 0.5 + 0.5 * (v / 1.40)
	return clamp(v, 0.0, 1.0)

