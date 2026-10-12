class_name Props
## Blender-built props carry their paint as vertex colors (material "vcol", linear). Godot's glTF import doesn't
## show them by default; this switches every such surface to use its vertex colors.

static func fix(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i) as StandardMaterial3D
			if m != null and m.resource_name.begins_with("vcol"):
				var n := m.duplicate() as StandardMaterial3D
				n.vertex_color_use_as_albedo = true
				n.vertex_color_is_srgb = false
				n.albedo_color = Color.WHITE
				n.roughness = 0.9
				(mi as MeshInstance3D).set_surface_override_material(i, n)


## Surfaces whose material is named "water" get the animated water shader (RanchWorld.WATER).
static func water_swap(root: Node) -> void:
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = RanchWorld.WATER
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m != null and m.resource_name.begins_with("water"):
				(mi as MeshInstance3D).set_surface_override_material(i, sm)


## Place a free/downloaded model (assets/props/<path>.glb) under `parent`, scaled to `height` meters, standing on
## the ground, turned by `yaw`. Optional box collision around its footprint. Returns null if the file is missing.
static var lite := false  # true while a neighbouring zone is built as distant scenery: skip small props + collision


static func model(parent: Node3D, path: String, pos: Vector3, height: float, yaw := 0.0, solid := true) -> Node3D:
	if lite and height < 4.0:  # too small to see from the next zone over
		var stub := Node3D.new()
		parent.add_child(stub)
		return stub
	if lite:
		solid = false
	var res := "res://assets/props/%s.glb" % path
	if not ResourceLoader.exists(res):
		return null
	var m: Node3D = (load(res) as PackedScene).instantiate()
	fix(m)
	var bb := MonsterModel.bounds(m)
	var k := height / maxf(bb.size.y, 0.01)
	m.scale = Vector3.ONE * k
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	parent.add_child(holder)
	m.position = Vector3(-bb.get_center().x * k, -bb.position.y * k, -bb.get_center().z * k)
	holder.add_child(m)
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(bb.size.x * k * 0.85, height, bb.size.z * k * 0.85)
		cs.shape = bx
		cs.position.y = height / 2.0
		sb.add_child(cs)
		holder.add_child(sb)
	return holder


## Every mesh part of a model as its own MultiMesh-ready piece: [mesh, material, aabb] (mesh-local space).
## Used to scatter many copies cheaply (wall stones, rocks).
static func parts(path: String) -> Array:
	var res := "res://assets/props/%s.glb" % path
	if not ResourceLoader.exists(res):
		return []
	var root: Node3D = (load(res) as PackedScene).instantiate()
	var out: Array = []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		for i in m.get_surface_count():
			var single := ArrayMesh.new()
			single.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m.surface_get_arrays(i))
			out.append([single, m.surface_get_material(i), single.get_aabb()])
	root.free()
	return out
