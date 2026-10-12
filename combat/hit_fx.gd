class_name HitFx
extends RefCounted
## Combat effects, ported from ChipMon's arena. Stateless helpers: pass the node to spawn into.
##   HitFx.on_hit(world, point, dir, color, result)   # everything a landed hit needs
## Hitstop freezes the whole game briefly (Engine.time_scale), so no system needs to know about it.
## Screen shake goes to the "camera_shake" group (FollowCamera joins it).

static var _stop_timer: SceneTreeTimer


static func on_hit(world: Node, point: Vector3, dir: Vector3, col: Color, r: Dictionary) -> void:
	var move := r["move"] as MoveDef
	var amount: int = r["amount"]
	var mult: float = r["mult"]
	var txt := str(amount)
	var tc := Color.WHITE
	var big := false
	if r["guarded"]:
		txt = "BLOCK " + txt
		tc = Color(0.55, 0.85, 1.0)
	elif mult > 1.0:
		txt += "!"
		tc = Color(1.0, 0.75, 0.2)
		big = true
	elif mult < 1.0:
		tc = Color(0.6, 0.65, 0.75)
	popup(world, point + Vector3(randf_range(-0.4, 0.4), 1.6, 0), txt, tc, big)
	sparks(world, point, col, dir, 14)
	burst(world, point, col, 10, 4.0)
	shock(world, point, col, 2.6, 0.35)
	var stop := move.hitstop + (0.03 if big else 0.0)
	if r.get("killed", false):
		stop = 0.2
		burst(world, point, col, 40, 8.0)
		sparks(world, point, col, Vector3.UP, 30)
		shock(world, point, col, 7.0, 0.8)
	hitstop(world.get_tree(), stop)
	world.get_tree().call_group("post_fx", "kick", 1.4 if r.get("killed", false) else 0.6)
	shake(world.get_tree(), 0.7 if r.get("killed", false) else (0.2 if r["guarded"] else 0.35))


## Freeze time for `dur` real seconds. Overlapping calls extend the freeze.
static func hitstop(tree: SceneTree, dur: float) -> void:
	if dur <= 0.0:
		return
	if _stop_timer != null and _stop_timer.time_left >= dur:
		return
	Engine.time_scale = 0.03
	var t := tree.create_timer(dur, true, false, true)
	_stop_timer = t
	t.timeout.connect(func() -> void:
		if _stop_timer == t:
			_stop_timer = null
			Engine.time_scale = 1.0)


static func shake(tree: SceneTree, amount: float) -> void:
	tree.call_group("camera_shake", "shake", amount)


# ---------------------------------------------------------------- materials

static func glow_mat(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = Color(c.r, c.g, c.b)
	m.emission_energy_multiplier = energy
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func additive_mat(c: Color, energy: float) -> StandardMaterial3D:
	var m := glow_mat(c, energy)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


# ---------------------------------------------------------------- effects

static func _fade_free(world: Node, n: Node, dur: float) -> void:
	world.get_tree().create_timer(dur, false).timeout.connect(n.queue_free)


## Glowing bits flying out in every direction.
static func burst(world: Node, pos: Vector3, col: Color, n: int, spd: float) -> void:
	var p := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	sm.radial_segments = 4
	sm.rings = 2
	sm.material = glow_mat(col, 5.0)
	p.mesh = sm
	p.amount = n
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.7
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = spd * 0.4
	p.initial_velocity_max = spd
	p.gravity = Vector3(0, -9, 0)
	world.add_child(p)
	p.global_position = pos
	p.emitting = true
	_fade_free(world, p, 1.5)


## Hot streaks flying out along `dir`.
static func sparks(world: Node, pos: Vector3, col: Color, dir: Vector3, n: int) -> void:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.03, 0.45, 0.03)
	bm.material = glow_mat(col.lerp(Color.WHITE, 0.5), 8.0)
	p.mesh = bm
	p.amount = n
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.35
	p.direction = (dir + Vector3(0, 0.35, 0)).normalized()
	p.spread = 55.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 18.0
	p.gravity = Vector3(0, -14, 0)
	p.damping_min = 8.0
	p.damping_max = 14.0
	p.particle_flag_align_y = true
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	world.add_child(p)
	p.global_position = pos
	p.emitting = true
	_fade_free(world, p, 1.0)


## Flat ring expanding along the floor under `pos`.
static func shock(world: Node, pos: Vector3, col: Color, radius: float, dur: float) -> void:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 1.0
	t.rings = 48
	mi.mesh = t
	var mt := glow_mat(Color(col, 1.0), 6.0)
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mt
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.08, pos.z)
	mi.scale = Vector3(0.3, 1.0, 0.3)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 1.0, radius), dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(mt, "albedo_color:a", 0.0, dur)
	tw.tween_property(mt, "emission_energy_multiplier", 0.0, dur)
	tw.chain().tween_callback(mi.queue_free)


## A fan of thin blades sweeping across `dir` = a slash arc.
static func slash(world: Node, origin: Vector3, dir: Vector3, col: Color) -> void:
	var pivot := Node3D.new()
	world.add_child(pivot)
	pivot.global_position = origin
	pivot.rotation.y = atan2(dir.x, dir.z)
	for i in 5:
		var mt := additive_mat(Color(col.lerp(Color.WHITE, 0.3), 0.9), 7.0)
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		mi.material_override = mt
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ang := deg_to_rad(-50.0 + float(i) * 25.0)
		mi.position = Vector3(sin(ang), 0.1 * float(i - 2), cos(ang)) * 1.5
		mi.rotation.y = ang + PI * 0.5
		mi.scale = Vector3(0.9, 0.04, 0.06)
		pivot.add_child(mi)
		var tw := mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "scale", Vector3(1.3, 0.02, 0.03), 0.14).set_delay(float(i) * 0.012)
		tw.tween_property(mt, "albedo_color:a", 0.0, 0.14).set_delay(float(i) * 0.012)
	_fade_free(world, pivot, 0.3)


## Floating damage number.
static func popup(world: Node, pos: Vector3, text: String, col: Color, big: bool = false) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = UIStyle.font("display")
	l.font_size = 96 if big else 72
	l.pixel_size = 0.009
	l.modulate = col
	l.outline_size = 20
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	world.add_child(l)
	l.global_position = pos
	l.scale = Vector3.ONE * 1.8
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", pos.y + 1.4, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.3).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)
