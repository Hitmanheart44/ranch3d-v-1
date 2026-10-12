class_name ArenaDress
extends RefCounted
## Dresses the tournament ground: rolling hills and a pine forest all round (reusing the overworld's terrain shader and
## pine model), a cheering crowd on the stands (one multimesh of low-poly spectators, bobbing in a vertex shader),
## gold inlay rings on the ring floor and drifting petals. Quality scales the crowd and forest; Low skips the forest.

const CROWD_SHADER := """
shader_type spatial;
varying vec3 vc;
void vertex() {
	float t = TIME * (2.2 + fract(float(INSTANCE_ID) * 0.37) * 1.6) + float(INSTANCE_ID) * 1.9;
	float up = max(0.0, sin(t)) * 0.18 * smoothstep(0.2, 0.9, VERTEX.y);   // heads and shoulders hop, feet stay
	VERTEX.y += up;
	vc = COLOR.rgb;
}
void fragment() {
	ALBEDO = vc;
	ROUGHNESS = 0.9;
}
"""


## Placeholder ground for the hills until the new arena map replaces this whole stage.
const HILL_SHADER := """
shader_type spatial;
uniform sampler2D ground : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() { ALBEDO = texture(ground, wp.xz / 6.0).rgb * vec3(0.62, 0.74, 0.42); ROUGHNESS = 0.95; }
"""


static func build(stage: Node3D) -> void:
	_hills(stage)
	_inlay(stage)
	_crowd(stage)


## A ring-shaped landscape: flat out to ~40 m, then rolling hills up to ~22 m, shaded by the overworld's terrain shader.
static func _hills(stage: Node3D) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 21
	noise.frequency = 0.035
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 36
	var segs := 96
	for ri in rings:
		for si in segs:
			for c in [[0, 0], [1, 1], [1, 0], [0, 0], [0, 1], [1, 1]]:
				var a: float = (si + c[0]) * TAU / segs
				var t := float(ri + c[1]) / rings
				var r := lerpf(0.5, 260.0, t * t)
				var h := smoothstep(44.0, 120.0, r) * (18.0 + noise.get_noise_2d(cos(a) * r, sin(a) * r) * 22.0) + noise.get_noise_2d(r * 0.6, a * 40.0) * 0.8 * smoothstep(40.0, 70.0, r)
				st.set_color(Color(0, 0, 0, 1))
				st.add_vertex(Vector3(cos(a) * r, h - 0.12, sin(a) * r))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = HILL_SHADER
	sm.set_shader_parameter("ground", load("res://assets/tex/ground037_color.jpg"))
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(mi)
	stage.set_meta("hill_noise", noise)


static func _hill_height(noise: FastNoiseLite, x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var a := atan2(z, x)
	return smoothstep(44.0, 120.0, r) * (18.0 + noise.get_noise_2d(x, z) * 22.0) + noise.get_noise_2d(r * 0.6, a * 40.0) * 0.8 * smoothstep(40.0, 70.0, r)


## Spectators on the two stands: a body + head per person, colours varied, hopping out of phase.
static func _crowd(stage: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var torso := CapsuleMesh.new()
	torso.radius = 0.2
	torso.height = 0.62
	torso.radial_segments = 6
	torso.rings = 1
	var head := SphereMesh.new()
	head.radius = 0.13
	head.height = 0.26
	head.radial_segments = 6
	head.rings = 3
	var hair := SphereMesh.new()
	hair.radius = 0.145
	hair.height = 0.17
	hair.radial_segments = 6
	hair.rings = 2
	var arm := CylinderMesh.new()
	arm.top_radius = 0.05
	arm.bottom_radius = 0.06
	arm.height = 0.42
	arm.radial_segments = 4
	arm.rings = 1
	# [mesh, offset, tilt around z (radians), vertex colour: white = per-instance clothes, otherwise fixed]
	for part in [[torso, Vector3(0, 0.38, 0), 0.0, Color(1, 1, 1)], [head, Vector3(0, 0.84, 0), 0.0, Color(0.9, 0.74, 0.62)],
			[hair, Vector3(0, 0.91, 0), 0.0, Color(0.12, 0.09, 0.07)], [arm, Vector3(0.3, 0.88, 0), -0.22, Color(0.9, 0.74, 0.62)],
			[arm, Vector3(-0.3, 0.88, 0), 0.22, Color(0.9, 0.74, 0.62)]]:
		var arr: Array = (part[0] as Mesh).surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var rot := Basis(Vector3(0, 0, 1), float(part[2]))
		for i in idx:
			st.set_color(part[3])
			st.set_normal(rot * ns[i])
			st.add_vertex(rot * vs[i] + part[1])
	var mesh := st.commit()
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	var density := 1.0 if Quality.level >= 2 else (0.6 if Quality.level == 1 else 0.3)
	for side in [-1, 1]:
		for row in 3:
			for seg in 7:
				for k in int(5 * density + 0.5):
					var a: float = side * PI / 2 + (seg - 3) * 0.22 + (k - 2) * 0.034 + r.randf_range(-0.01, 0.01)
					var rad := RADIUS_STANDS + row * 1.6 + r.randf_range(-0.3, 0.3)
					var y := (0.8 + row * 1.4) + 0.0
					var b := Basis(Vector3.UP, -a + PI * 0.5 + r.randf_range(-0.4, 0.4)).scaled(Vector3.ONE * r.randf_range(0.9, 1.1))
					xf.append(Transform3D(b, Vector3(cos(a) * rad, y, sin(a) * rad)))
					var col := Color.from_hsv(r.randf(), r.randf_range(0.25, 0.65), r.randf_range(0.5, 0.95))
					cols.append(col)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = CROWD_SHADER
	mmi.material_override = sm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(mmi)


const RADIUS_STANDS := 21.0   # ArenaStage.RADIUS + 8


## Two thin gold rings inlaid in the ring floor and a small centre medallion.
static func _inlay(stage: Node3D) -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.9, 0.7, 0.3)
	gold.metallic = 0.7
	gold.roughness = 0.35
	for r in [4.5, 9.0]:
		var m := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r - 0.07
		tm.outer_radius = r + 0.07
		tm.rings = 48
		tm.ring_segments = 6
		m.mesh = tm
		m.scale.y = 0.15
		m.position.y = 0.17
		m.material_override = gold
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stage.add_child(m)
	var med := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.2
	cm.bottom_radius = 1.2
	cm.height = 0.02
	cm.radial_segments = 32
	med.mesh = cm
	med.position.y = 0.17
	med.material_override = gold
	med.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(med)
