class_name Build
## Shared helpers for building textured scenery out of primitives (ranch, shrine). Textures: res://assets/tex/.

static var _mats: Dictionary = {}


static func mat(tex: String, uv: Vector3, tint: Color = Color.WHITE, emit: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [tex, uv, tint, emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	if tex != "":
		m.albedo_texture = load("res://assets/tex/%s_color.jpg" % tex)
		if ResourceLoader.exists("res://assets/tex/%s_normal.jpg" % tex):
			m.normal_enabled = true
			m.normal_texture = load("res://assets/tex/%s_normal.jpg" % tex)
	m.albedo_color = tint
	m.uv1_scale = uv
	m.roughness = 0.9
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = tint
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


static func box(parent: Node3D, p: Vector3, size: Vector3, m: Material, solid := false, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	mi.rotation = rot
	parent.add_child(mi)
	if solid:
		mi.create_convex_collision()
	return mi


static func cyl(parent: Node3D, p: Vector3, top: float, bottom: float, h: float, m: Material, solid := false, seg := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = seg
	mi.mesh = cm
	mi.material_override = m
	mi.position = p
	parent.add_child(mi)
	if solid:
		mi.create_convex_collision()
	return mi


static func ball(parent: Node3D, p: Vector3, r: float, scale: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = m
	mi.position = p
	mi.scale = scale
	parent.add_child(mi)
	return mi


static func torus(parent: Node3D, p: Vector3, r: float, thick: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - thick
	tm.outer_radius = r + thick
	tm.rings = 32
	tm.ring_segments = 8
	mi.mesh = tm
	mi.material_override = m
	mi.position = p
	parent.add_child(mi)
	return mi


static func pillar_collider(parent: Node3D, p: Vector3, r: float, h: float) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = r
	cy.height = h
	cs.shape = cy
	sb.position = p + Vector3(0, h / 2.0, 0)
	sb.add_child(cs)
	parent.add_child(sb)
