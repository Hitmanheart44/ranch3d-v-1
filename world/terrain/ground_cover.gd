class_name GroundCover
extends RefCounted
## Grass on the Terrain3D ground, through Terrain3D's instancer: cell-culled, distance-LOD'd, wind-swayed on the GPU.
## Placement rules (no tufts on roads, yards, town paving, steep slopes or past the cliff edge) live here.

const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tuft : source_color, filter_linear_mipmap;
uniform float tint_amount = 1.0;   // 0 = leave the card's own colours (flowers)
varying float tip;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }
void vertex() {
	tip = 1.0 - UV.y;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(TIME * 1.6 + wpos.x * 0.35 + wpos.z * 0.25) * 0.5 + sin(TIME * 2.7 + wpos.x * 0.9) * 0.2;
	VERTEX.xz += vec2(w, w * 0.6) * 0.06 * tip;
}
void fragment() {
	vec4 t = texture(tuft, UV);
	if (t.a < 0.5) discard;
	// meadow colour drifts between fresh green and sun-dried straw across the field, with per-clump variation
	float patch_n = vnoise(wpos.xz * 0.045) * 0.65 + vnoise(wpos.xz * 0.35) * 0.35;
	vec3 fresh = vec3(0.42, 0.6, 0.3);
	vec3 dry = vec3(0.62, 0.58, 0.32);
	vec3 tint = mix(fresh, dry, smoothstep(0.5, 0.8, patch_n));
	float clump = 0.85 + 0.3 * hash(floor(wpos.xz * 1.7));
	float root = mix(0.38, 1.0, smoothstep(0.0, 0.75, tip));      // dark roots: contact shading the sun can't give a card
	ALBEDO = t.rgb * mix(vec3(1.0), tint * clump, tint_amount) * root;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);  // lit like the ground, both sides
	ROUGHNESS = 0.95;
}
"""
const PER_M2 := 0.55


static func grass(t: Terrain3D, ov: Overworld) -> void:
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = GRASS_SHADER
	sm.set_shader_parameter("tuft", load("res://assets/tex/grass_card.png"))
	var ma := Terrain3DMeshAsset.new()
	ma.name = "Grass"
	ma.generated_type = Terrain3DMeshAsset.TYPE_TEXTURE_CARD
	ma.generated_faces = 3
	ma.generated_size = Vector2(0.9, 0.5)
	ma.material_override = sm
	ma.cast_shadows = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ma.set_lod_range(0, 70.0)
	ma.fade_margin = 15.0
	t.assets.set_mesh_asset(0, ma)
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var field: TerrainField = t.get_meta("field")
	var reg := ov.region
	var count := int(reg.size.x * reg.size.y * PER_M2 * Quality.density())
	var xf: Array[Transform3D] = []
	var tries := 0
	while xf.size() < count and tries < count * 8:
		tries += 1
		var p := Vector2(r.randf_range(reg.position.x, reg.end.x), r.randf_range(reg.position.y, reg.end.y))
		if field.dirt_at(p.x, p.y) > 0.2 or p.x > Overworld.coast(p.y) - 2.0 or (p.length() < 30.0 and r.randf() < 0.6):
			continue
		if field.rise_at(p.x, p.y, 2.0) > 1.0:   # no tufts on slopes steep enough to show rock (grade 0.5 and up)
			continue
		var sc := r.randf_range(0.6, 1.3)
		var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(sc, sc * r.randf_range(0.7, 1.3), sc))
		xf.append(Transform3D(b, Vector3(p.x, field.height_at(p.x, p.y), p.y)))
	t.instancer.add_transforms(0, xf)
	if Quality.level > 0:
		_flowers(t, ov, r, field)


## Flower patches (cards drawn by tools/assets/make_cover_art.py): each kind gets its own mesh asset slot; patches cluster
## 5-14 blooms in a small circle, and a few seed-grass clumps stand between. Medium: a third as many as High.
const FLOWERS := [["daisy", 70, 0.55], ["buttercup", 60, 0.5], ["violet", 45, 0.5], ["poppy", 35, 0.55], ["clover", 55, 0.45], ["seedgrass", 70, 0.9]]


static func _flowers(t: Terrain3D, ov: Overworld, r: RandomNumberGenerator, field: TerrainField) -> void:
	var reg := ov.region
	var scale := 1.0 if Quality.level >= 2 else 0.35
	for k in FLOWERS.size():
		var f: Array = FLOWERS[k]
		var sm := ShaderMaterial.new()
		sm.shader = Shader.new()
		sm.shader.code = GRASS_SHADER
		sm.set_shader_parameter("tuft", load("res://assets/terrain/cover/%s.png" % f[0]))
		sm.set_shader_parameter("tint_amount", 0.5 if f[0] == "seedgrass" else 0.0)
		var ma := Terrain3DMeshAsset.new()
		ma.name = str(f[0])
		ma.generated_type = Terrain3DMeshAsset.TYPE_TEXTURE_CARD
		ma.generated_faces = 2
		ma.generated_size = Vector2(float(f[2]), float(f[2]))
		ma.material_override = sm
		ma.cast_shadows = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ma.set_lod_range(0, 45.0)
		ma.fade_margin = 10.0
		t.assets.set_mesh_asset(1 + k, ma)
		var xf: Array[Transform3D] = []
		var patches := int(float(f[1]) * reg.size.x * reg.size.y / 16800.0 * scale)
		for i in patches:
			var c := Vector2(r.randf_range(reg.position.x, reg.end.x), r.randf_range(reg.position.y, reg.end.y))
			for j in r.randi_range(5, 14):
				var p := c + Vector2.from_angle(r.randf() * TAU) * r.randf_range(0.0, 1.8)
				if field.dirt_at(p.x, p.y) > 0.02 or field.dirt_at(p.x + 2.0, p.y) > 0.3 or field.dirt_at(p.x, p.y + 2.0) > 0.3 \
						or p.x > Overworld.coast(p.y) - 3.0 or p.length() < 6.0 or field.rise_at(p.x, p.y, 1.5) > 0.75:
					continue
				var h := field.height_at(p.x, p.y)
				var sc := r.randf_range(0.7, 1.25)
				xf.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(p.x, h, p.y)))
		t.instancer.add_transforms(1 + k, xf)
