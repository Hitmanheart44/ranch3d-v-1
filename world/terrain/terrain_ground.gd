class_name TerrainGround
extends RefCounted
## Terrain3D ground for a zone. The shape still comes from Overworld.height() (so roads, building pads, cliffs and
## the town valley stay where the layouts expect them); Terrain3D supplies the texture layers, slope shading,
## collision and clipmap LOD. Dirt (road + yards) is painted into the control map from the same layout functions.

const TEX := ["grass004", "ground037", "rock030", "grass001"]   # slot 0 grass, 1 dirt, 2 rock, 3 meadow
const UV_SCALE := [0.30, 0.38, 0.55, 0.28]
const REGION_SIZE := 128


static func build(parent: Node3D, ov: Overworld) -> Terrain3D:
	var t := Terrain3D.new()
	t.name = "Terrain3D"
	parent.add_child(t, true)
	t.region_size = REGION_SIZE
	if Quality.level == 0:   # fewer clipmap rings and a smaller mesh: a fraction of the triangles
		t.mesh_size = 24
		t.mesh_lods = 5
	t.material.world_background = Terrain3DMaterial.NONE
	t.material.auto_shader = true
	t.material.set_shader_param("auto_slope", 1.0)
	t.material.set_shader_param("auto_base_texture", 2)      # steep ground shows rock...
	t.material.set_shader_param("auto_overlay_texture", 0)   # ...flat ground shows grass
	t.material.set_shader_param("blend_sharpness", 0.85)
	t.material.set_shader_param("enable_projection", true)     # steep faces get side-projected rock, not stretched
	t.material.set_shader_param("projection_threshold", 0.9)
	if Quality.level == 0:   # the stripped-down shader: autoshader + base/overlay/blend only (no detiling, projection, macro noise)
		t.material.shader_override = load("res://addons/terrain_3d/extras/shaders/lightweight.gdshader")
		t.material.shader_override_enabled = true
	t.assets = Terrain3DAssets.new()
	for i in TEX.size():
		t.assets.set_texture(i, _texture(TEX[i], i))
	Prof.mark("  terrain setup + textures")
	var field := _heights(t, ov)
	Prof.mark("  terrain data import")
	t.set_meta("field", field)
	return t


static func _texture(base: String, id: int) -> Terrain3DTextureAsset:
	var ta := Terrain3DTextureAsset.new()
	ta.name = base
	ta.id = id
	# precomputed by tools/bake/bake_terrain.py (tinted, 1024 px, height/roughness in alpha) and VRAM-compressed on import
	ta.albedo_texture = load("res://assets/terrain/tex/%s_alb.png" % base)
	ta.normal_texture = load("res://assets/terrain/tex/%s_nrm.png" % base)
	ta.uv_scale = UV_SCALE[id]
	ta.detiling_rotation = 0.15
	ta.normal_depth = 2.2 if id == 2 else 1.0   # the cliffs need real relief
	return ta


## Pixel bounds (1 m each): the zone's region plus a margin, snapped out to whole Terrain3D regions.
static func _bounds(ov: Overworld) -> Rect2i:
	var r := ov.region.grow(12.0)
	var lo := Vector2i(floori(r.position.x / REGION_SIZE), floori(r.position.y / REGION_SIZE)) * REGION_SIZE
	var hi := Vector2i(ceili(r.end.x / REGION_SIZE), ceili(r.end.y / REGION_SIZE)) * REGION_SIZE
	return Rect2i(lo, hi - lo)


## The baked world (tools/bake/bake_terrain.py): heights on a 1 m grid covering every zone, plus the AO colour map.
const BAKE_RECT := Rect2i(-128, -128, 256, 384)
const BAKE_HEIGHTS := "res://assets/terrain/world_height.bin"
const BAKE_COLOR := "res://assets/terrain/world_color.png"


## Baked heights for the zone's bounds, or an empty image when the bake is missing / no longer matches height().
static func _baked_heights(ov: Overworld, b: Rect2i) -> Image:
	if not FileAccess.file_exists(BAKE_HEIGHTS):
		return null
	var bytes := FileAccess.get_file_as_bytes(BAKE_HEIGHTS)
	if bytes.size() != BAKE_RECT.size.x * BAKE_RECT.size.y * 4 or not BAKE_RECT.encloses(b):
		return null
	var full := Image.create_from_data(BAKE_RECT.size.x, BAKE_RECT.size.y, false, Image.FORMAT_RF, bytes)
	for pt in [Vector2i(0, 0), Vector2i(20, -50), Vector2i(18, -52), Vector2i(16, 90), Vector2i(-40, 10), Vector2i(60, -30)]:   # stale-bake check
		var px := full.get_pixel(pt.x - BAKE_RECT.position.x, pt.y - BAKE_RECT.position.y).r
		if absf(px - ov.height(pt.x, pt.y)) > 0.02:
			push_warning("terrain bake is stale (height() changed): run tools/bake/bake_all.sh. Sampling live instead.")
			return null
	return full.get_region(Rect2i(b.position - BAKE_RECT.position, b.size))


static func _heights(t: Terrain3D, ov: Overworld) -> TerrainField:
	var b := _bounds(ov)
	var img := _baked_heights(ov, b)
	if img == null:
		img = Image.create_empty(b.size.x, b.size.y, false, Image.FORMAT_RF)
		for j in b.size.y:
			for i in b.size.x:
				img.set_pixel(i, j, Color(ov.height(b.position.x + i, b.position.y + j), 0, 0, 1))
	var color: Image = null
	if ResourceLoader.exists(BAKE_COLOR) and BAKE_RECT.encloses(b):
		var full: Image = (load(BAKE_COLOR) as Texture2D).get_image()
		if full.is_compressed():
			full.decompress()
		full.convert(Image.FORMAT_RGBA8)
		color = full.get_region(Rect2i(b.position - BAKE_RECT.position, b.size))
	Prof.mark("  heights + colour read")
	var field := TerrainField.build(ov, b, img)
	Prof.mark("  ground mask (road / yards / paving)")
	t.data.import_images([img, field.control_image(), color], Vector3(b.position.x, 0, b.position.y), 0.0, 1.0)
	return field
