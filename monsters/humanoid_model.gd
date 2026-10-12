class_name HumanoidModel
extends MonsterModel
## Humanoid breeds (see BESTIARY.md): an adult female base body built from primitives, plus each
## breed's outfit and features. MonsterModel.create() routes the ids in BREEDS here.
## Procedural stand-ins until real models arrive (art track A6); they keep gameplay unblocked.

const BREEDS := ["vexa", "sylvara", "valkra", "nysse"]


static func handles(id: String) -> bool:
	return id in BREEDS


# ---------------------------------------------------------------- helpers

## Skin/hair materials: same shader as the kami, lighter so the figure reads.
func _skin(col: Color, veins: float = 0.0) -> void:
	if sil:
		mats["skin"] = mats["body"]
		mats["hair"] = mats["plate"]
		return
	var glow: Color = mats["glow"].get_shader_parameter("col")
	mats["skin"] = _body(col, glow, 0.7, 0.05, 0.45, veins)


func _hair(col: Color) -> void:
	if sil:
		return
	var glow: Color = mats["glow"].get_shader_parameter("col")
	mats["hair"] = _body(col, glow, 0.6, 0.1, 0.35, 0.0)


## A capsule stretched between two points: arms, legs, horns, tails.
func _limb(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = MonsterModel._mesh("caps")
	mi.material_override = mats[mat]
	var y := (b - a)
	var length := y.length()
	y = y.normalized()
	var x := y.cross(Vector3(0, 0, 1))
	if x.length() < 0.01:
		x = Vector3(1, 0, 0)
	x = x.normalized()
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x * r * 2.0, y * (length + r * 2.0) * 0.5, z * r * 2.0), (a + b) * 0.5)
	parent.add_child(mi)
	return mi


## The base body. Returns anchor points for outfits: head, chest, hips, hand_l, hand_r, back.
## `legs` = false skips legs (the lamia has a serpent tail instead).
func _woman(legs: bool = true) -> Dictionary:
	var b := _pivot(root, Vector3.ZERO)
	_anim(b, "float", 0.012, 2.0)  # breathing
	# torso
	_p(b, "sph", Vector3(0, 1.27, 0), Vector3(0.5, 0.34, 0.33), "skin")
	for sx in [-1.0, 1.0]:
		_p(b, "sph", Vector3(sx * 0.12, 1.22, -0.08), Vector3(0.27, 0.27, 0.25), "skin")
	_p(b, "sph", Vector3(0, 1.53, 0), Vector3(0.3, 0.38, 0.22), "skin")
	_p(b, "sph", Vector3(0, 1.8, -0.01), Vector3(0.4, 0.38, 0.26), "skin")
	for sx in [-1.0, 1.0]:
		_p(b, "sph", Vector3(sx * 0.105, 1.82, 0.1), Vector3(0.25, 0.24, 0.23), "skin", Vector3(-8, sx * 14.0, 0))
	_p(b, "sph", Vector3(0, 1.97, -0.02), Vector3(0.46, 0.14, 0.2), "skin")
	_p(b, "cyl", Vector3(0, 2.07, 0), Vector3(0.1, 0.18, 0.1), "skin")
	# head: dark face, glowing eyes
	var head := _pivot(b, Vector3(0, 2.27, 0.01))
	_anim(head, "yaw", 0.08, 0.6)
	_p(head, "sph", Vector3.ZERO, Vector3(0.24, 0.3, 0.27), "skin")
	_p(head, "sph", Vector3(0, -0.1, 0.05), Vector3(0.17, 0.14, 0.16), "skin")
	_eyes(head, 0.02, 0.125, 0.06, 0.07, 0.022, 12.0)
	# arms
	var hands := []
	for sx in [-1.0, 1.0]:
		var sh := Vector3(sx * 0.25, 1.95, -0.02)
		var el := Vector3(sx * 0.35, 1.64, -0.04)
		var wr := Vector3(sx * 0.37, 1.36, 0.06)
		_p(b, "sph", sh, Vector3.ONE * 0.15, "skin")
		_limb(b, sh, el, 0.062, "skin")
		_limb(b, el, wr, 0.05, "skin")
		var hand := _pivot(b, wr + Vector3(0, -0.07, 0))
		_p(hand, "sph", Vector3.ZERO, Vector3(0.08, 0.13, 0.06), "skin")
		hands.append(hand)
	# legs: weight on the right leg, left knee forward
	if legs:
		var knees := [Vector3(-0.1, 0.68, 0.07), Vector3(0.13, 0.68, 0.0)]
		var ankles := [Vector3(-0.11, 0.1, 0.0), Vector3(0.14, 0.1, -0.04)]
		for i in 2:
			var hip := Vector3(-0.12 if i == 0 else 0.12, 1.2, 0)
			_limb(b, hip, knees[i], 0.105, "skin")
			_limb(b, knees[i], ankles[i], 0.066, "skin")
			_p(b, "sph", knees[i].lerp(ankles[i], 0.3) + Vector3(0, 0, -0.02), Vector3(0.13, 0.22, 0.13), "skin")
			_p(b, "box", ankles[i] + Vector3(0, -0.06, 0.06), Vector3(0.09, 0.08, 0.24), "skin")
	return {"body": b, "head": head, "hand_l": hands[0], "hand_r": hands[1]}


## Covers the bust with `mat` (a top / armor cups) and adds a glowing trim strap.
func _top(b: Node3D, mat: String, trim: bool = true) -> void:
	for sx in [-1.0, 1.0]:
		_p(b, "sph", Vector3(sx * 0.105, 1.825, 0.105), Vector3(0.262, 0.252, 0.24), mat, Vector3(-8, sx * 14.0, 0))
	if trim:
		_p(b, "box", Vector3(0, 1.72, 0.17), Vector3(0.36, 0.02, 0.03), "glow")


# ---------------------------------------------------------------- breeds

## Dusk demoness: swept horns, long dark hair, leather top, thigh-high boots, bat-wing cape, whip-blade tail.
func _vexa() -> void:
	_skin(Color.from_hsv(0.8, 0.22, 0.38))
	_hair(Color(0.04, 0.03, 0.06))
	var w := _woman()
	var b: Node3D = w["body"]
	var head: Node3D = w["head"]
	_top(b, "plate")
	for sx in [-1.0, 1.0]:
		_limb(head, Vector3(sx * 0.08, 0.1, 0.0), Vector3(sx * 0.2, 0.28, -0.12), 0.035, "plate")
		_limb(head, Vector3(sx * 0.2, 0.28, -0.12), Vector3(sx * 0.18, 0.42, -0.3), 0.025, "plate")
		_limb(b, Vector3(sx * 0.12, 0.85, 0.02), Vector3(sx * 0.12, 0.08, 0.0), 0.075, "plate")  # boots
		var wing := _pivot(b, Vector3(sx * 0.18, 1.95, -0.15), Vector3(0, sx * 25.0, -sx * 20.0))
		_anim(wing, "flap", sx * 0.08, 2.0)
		_p(wing, "prism", Vector3(sx * 0.4, -0.3, -0.05), Vector3(0.9, 1.2, 0.03), "plate", Vector3(0, 0, sx * 160.0))
	_p(head, "sph", Vector3(0, 0.03, -0.06), Vector3(0.29, 0.34, 0.3), "hair")
	_p(b, "box", Vector3(0, 1.85, -0.17), Vector3(0.28, 0.75, 0.07), "hair", Vector3(8, 0, 0))
	_p(b, "box", Vector3(0, 1.15, 0.0), Vector3(0.48, 0.07, 0.34), "plate")
	_p(b, "octa", Vector3(0, 1.15, 0.17), Vector3(0.07, 0.09, 0.04), "glow")
	var tail := _pivot(b, Vector3(0, 1.15, -0.2))
	_anim(tail, "wag", 0.25, 2.5)
	var pts := [Vector3.ZERO, Vector3(0, -0.35, -0.3), Vector3(0.1, -0.7, -0.55), Vector3(0.25, -0.95, -0.6)]
	for i in 3:
		_limb(tail, pts[i], pts[i + 1], 0.04 - 0.008 * i, "skin")
	_p(tail, "pyr", pts[3] + Vector3(0.05, -0.08, 0), Vector3(0.12, 0.25, 0.03), "glow", Vector3(0, 0, 160))


## Dryad witch: bark skin with glowing veins, thorn crown, hanging root hair, vine bodice, a staff.
func _sylvara() -> void:
	_skin(Color.from_hsv(0.3, 0.35, 0.3), 0.5)
	_hair(Color.from_hsv(0.08, 0.5, 0.12))
	var w := _woman()
	var b: Node3D = w["body"]
	var head: Node3D = w["head"]
	_top(b, "hair", false)
	for i in 7:
		var a := TAU * float(i) / 7.0
		_p(head, "pyr", Vector3(cos(a) * 0.13, 0.17, sin(a) * 0.13), Vector3(0.04, 0.16, 0.04), "glow", Vector3(sin(a) * 20.0, 0, -cos(a) * 20.0))
	for i in 6:
		var x := -0.12 + float(i) * 0.05
		var root_n := _p(head, "cone", Vector3(x, -0.25, -0.14 + absf(x) * 0.3), Vector3(0.05, 0.6, 0.05), "hair", Vector3(180 + 8.0, 0, x * 40.0))
		_anim(root_n, "wag", 0.05, 1.2)
	for sx in [-1.0, 1.0]:
		_limb(b, Vector3(sx * 0.2, 1.95, 0.05), Vector3(-sx * 0.15, 1.2, 0.18), 0.018, "hair")
		_p(b, "octa", Vector3(sx * 0.2, 1.18, 0.12), Vector3(0.12, 0.2, 0.05), "glow", Vector3(0, 0, sx * 30.0))
	var staff := _pivot(w["hand_l"] as Node3D, Vector3.ZERO)
	_limb(staff, Vector3(0, -1.2, 0.05), Vector3(0, 0.75, 0.05), 0.03, "hair")
	var orb := _p(staff, "octa", Vector3(0, 0.88, 0.05), Vector3(0.14, 0.2, 0.14), "glow")
	_anim(orb, "spin", 0.0, 1.5)
	_particles(root, Vector3(0, 1.4, 0), 10, Vector3(0.4, 0.6, 0.3), 0.4, 0.025)


## Storm valkyrie: winged helm, plated armor top, pauldrons, armored skirt, greaves, lightning spear, wings.
func _valkra() -> void:
	_skin(Color(0.55, 0.43, 0.38))
	_hair(Color(0.55, 0.45, 0.25))
	var w := _woman()
	var b: Node3D = w["body"]
	var head: Node3D = w["head"]
	_top(b, "plate")
	_p(head, "sph", Vector3(0, 0.06, -0.01), Vector3(0.27, 0.24, 0.29), "plate")
	_p(b, "box", Vector3(0, 1.75, -0.2), Vector3(0.26, 0.85, 0.06), "hair", Vector3(10, 0, 0))
	for sx in [-1.0, 1.0]:
		_p(head, "box", Vector3(sx * 0.16, 0.1, -0.02), Vector3(0.22, 0.03, 0.08), "glow", Vector3(0, 0, sx * 30.0))
		_p(b, "sph", Vector3(sx * 0.27, 1.98, -0.02), Vector3(0.22, 0.14, 0.24), "plate", Vector3(0, 0, -sx * 15.0))
		_limb(b, Vector3(sx * 0.12, 0.6, 0.02), Vector3(sx * 0.13, 0.06, 0.0), 0.075, "plate")
		_limb(b, Vector3(sx * 0.36, 1.55, -0.03), Vector3(sx * 0.37, 1.36, 0.06), 0.06, "plate")
		var wing := _pivot(b, Vector3(sx * 0.12, 1.9, -0.18), Vector3(0, -sx * 20.0, sx * 35.0))
		_anim(wing, "flap", sx * 0.1, 1.8)
		for k in 3:
			_p(wing, "box", Vector3(sx * (0.35 + 0.1 * k), 0.05 - 0.18 * k, 0), Vector3(0.75 - 0.15 * k, 0.1, 0.03), "plate")
			_p(wing, "box", Vector3(sx * (0.35 + 0.1 * k), 0.0 - 0.18 * k, 0.02), Vector3(0.7 - 0.15 * k, 0.015, 0.02), "glow")
	for i in 5:
		var a := -0.9 + float(i) * 0.45
		_p(b, "box", Vector3(sin(a) * 0.22, 1.05, cos(a) * 0.15), Vector3(0.12, 0.28, 0.03), "plate", Vector3(-8, rad_to_deg(a), 0))
	var spear := _pivot(w["hand_r"] as Node3D, Vector3.ZERO)
	_limb(spear, Vector3(0, -1.0, 0.05), Vector3(0, 1.3, 0.05), 0.022, "plate")
	var tip := _p(spear, "pyr", Vector3(0, 1.5, 0.05), Vector3(0.09, 0.4, 0.04), "glow")
	_anim(tip, "flicker", 0.15, 12.0)


## Lamia sea-witch: serpent tail instead of legs, fin ears, shell top, coral jewelry, long hair.
func _nysse() -> void:
	_skin(Color.from_hsv(0.52, 0.2, 0.42))
	_hair(Color.from_hsv(0.5, 0.5, 0.12))
	var w := _woman(false)
	var b: Node3D = w["body"]
	var head: Node3D = w["head"]
	_top(b, "plate")
	_p(head, "sph", Vector3(0, 0.03, -0.06), Vector3(0.29, 0.34, 0.3), "hair")
	_p(b, "box", Vector3(0, 1.75, -0.18), Vector3(0.3, 0.9, 0.07), "hair", Vector3(6, 0, 0))
	for sx in [-1.0, 1.0]:
		_p(head, "prism", Vector3(sx * 0.15, 0.03, -0.02), Vector3(0.03, 0.18, 0.16), "glow", Vector3(0, 90, -sx * 30.0))
		_p(b, "octa", Vector3(sx * 0.36, 1.5, -0.03), Vector3(0.07, 0.1, 0.07), "glow")
	for i in 5:
		var a := -0.6 + float(i) * 0.3
		_p(b, "octa", Vector3(sin(a) * 0.12, 2.0 - absf(a) * 0.08, 0.1 + cos(a) * 0.02), Vector3.ONE * 0.04, "glow")
	var pts := [Vector3(0, 1.15, 0), Vector3(0, 0.75, -0.08), Vector3(0, 0.38, -0.3), Vector3(0, 0.2, -0.75),
		Vector3(0.3, 0.16, -1.15), Vector3(0.72, 0.13, -1.35), Vector3(1.05, 0.12, -1.15)]
	var tail := _pivot(root, Vector3.ZERO)
	for i in pts.size() - 1:
		var r := 0.2 - 0.022 * float(i)
		_limb(tail, pts[i], pts[i + 1], r, "plate")
		_p(tail, "sph", pts[i + 1], Vector3.ONE * r * 0.5, "glow")
	var fin := _pivot(tail, pts[6])
	_anim(fin, "yaw", 0.3, 2.0)
	_p(fin, "prism", Vector3(0.15, 0.1, 0), Vector3(0.4, 0.4, 0.03), "glow", Vector3(0, 0, -90))
