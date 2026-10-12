class_name ExtraClips
extends RefCounted
## Extra animation clips added at load time to every rigged model that has the standard bones (autorig2 naming):
## Cheer (victory), Talk (gestures + nods, loops), Wave, Bow, Think (hand to chin, loops), KO (collapse, holds), Rest (slow breathing slump, loops).
## NOTE: arm keys are skipped for now (see below). Keyed on rotation tracks only, so they work on every rig (fairy and mermaid rigs just ignore leg bones).

## Set true for any rig whose arm skin weights still drag the trousers (see tools/blender/fix_arm_weights.py).
const SKIP_ARMS := true   # the AI meshes have hands fused to the trousers (thin stretched triangles remain even after the weight fix); needs the arms separated in the mesh


static func add(player: AnimationPlayer) -> void:
	var skel := _skeleton(player)
	if skel == null:
		return
	var path := str(player.get_node(player.root_node).get_path_to(skel))
	var lib: AnimationLibrary = player.get_animation_library("") if player.has_animation_library("") else null
	if lib == null:
		return
	var defs := {
		"Cheer": [1.6, false, {"upperarm.L": [[0, 0, 0], [0, 0, 140], [0, 0, 120], [0, 0, 145], [0, 0, 0]], "upperarm.R": [[0, 0, 0], [0, 0, -140], [0, 0, -120], [0, 0, -145], [0, 0, 0]],
			"forearm.L": [[0, 0, 0], [0, 0, 20], [0, 0, 10], [0, 0, 20], [0, 0, 0]], "forearm.R": [[0, 0, 0], [0, 0, -20], [0, 0, -10], [0, 0, -20], [0, 0, 0]],
			"spine": [[0, 0, 0], [-10, 0, 3], [-3, 0, -3], [-10, 0, 3], [0, 0, 0]], "chest": [[0, 0, 0], [-8, 0, 0], [-2, 0, 0], [-8, 0, 0], [0, 0, 0]], "head": [[0, 0, 0], [-16, 6, 0], [-6, -6, 0], [-16, 6, 0], [0, 0, 0]]}],
		"Wave": [1.6, false, {"upperarm.R": [[0, 0, 0], [0, 0, -130], [0, 0, -130], [0, 0, -130], [0, 0, 0]], "forearm.R": [[0, 0, 0], [0, 0, -10], [0, 0, -50], [0, 0, 10], [0, 0, 0]],
			"head": [[0, 0, 0], [0, 8, 6], [0, 8, 6], [0, 8, 6], [0, 0, 0]]}],
		"Bow": [1.8, false, {"spine": [[0, 0, 0], [30, 0, 0], [34, 0, 0], [30, 0, 0], [0, 0, 0]], "head": [[0, 0, 0], [20, 0, 0], [24, 0, 0], [20, 0, 0], [0, 0, 0]],
			"chest": [[0, 0, 0], [10, 0, 0], [12, 0, 0], [10, 0, 0], [0, 0, 0]]}],
		"Talk": [3.2, true, {"upperarm.L": [[0, 0, 12], [0, 0, 30], [0, 0, 12], [0, 0, 40], [0, 0, 12]], "upperarm.R": [[0, 0, -12], [0, 0, -40], [0, 0, -12], [0, 0, -28], [0, 0, -12]],
			"forearm.L": [[0, 0, 20], [0, 0, 50], [0, 0, 20], [0, 0, 60], [0, 0, 20]], "forearm.R": [[0, 0, -20], [0, 0, -60], [0, 0, -20], [0, 0, -45], [0, 0, -20]],
			"head": [[0, 0, 0], [6, 5, 0], [-2, -4, 0], [5, 3, 0], [0, 0, 0]], "neck": [[0, 0, 0], [3, 2, 0], [-1, -2, 0], [2, 1, 0], [0, 0, 0]]}],
		"Think": [3.0, true, {"upperarm.R": [[0, 0, -20], [-40, 0, -50], [-45, 0, -52], [-40, 0, -50], [0, 0, -20]], "forearm.R": [[0, 0, -20], [0, 0, -120], [0, 0, -125], [0, 0, -120], [0, 0, -20]],
			"head": [[0, 0, 0], [10, 14, 6], [12, 16, 6], [10, 14, 6], [0, 0, 0]]}],
		"KO": [1.2, false, {"spine": [[0, 0, 0], [20, 0, 6], [38, 0, 10], [42, 0, 12], [42, 0, 12]], "head": [[0, 0, 0], [18, 8, 0], [30, 14, 0], [34, 16, 0], [34, 16, 0]],
			"upperarm.L": [[0, 0, 4], [0, 0, 12], [0, 0, 22], [0, 0, 26], [0, 0, 26]], "upperarm.R": [[0, 0, -4], [0, 0, -12], [0, 0, -22], [0, 0, -26], [0, 0, -26]],
			"thigh.L": [[0, 0, 0], [-6, 0, 0], [-12, 0, 0], [-14, 0, 0], [-14, 0, 0]], "thigh.R": [[0, 0, 0], [-6, 0, 0], [-12, 0, 0], [-14, 0, 0], [-14, 0, 0]]}],
		"Rest": [4.0, true, {"spine": [[8, 0, 0], [12, 0, 0], [8, 0, 0], [12, 0, 0], [8, 0, 0]], "head": [[16, 0, 0], [20, 0, 0], [16, 0, 0], [20, 0, 0], [16, 0, 0]],
			"upperarm.L": [[0, 0, 6], [0, 0, 8], [0, 0, 6], [0, 0, 8], [0, 0, 6]], "upperarm.R": [[0, 0, -6], [0, 0, -8], [0, 0, -6], [0, 0, -8], [0, 0, -6]]}],
	}
	for name in defs:
		if lib.has_animation(name):
			continue
		var d: Array = defs[name]
		var anim := Animation.new()
		anim.length = d[0]
		anim.loop_mode = Animation.LOOP_LINEAR if d[1] else Animation.LOOP_NONE
		for bone in d[2]:
			if skel.find_bone(bone) == -1 or (SKIP_ARMS and (bone.begins_with("upperarm") or bone.begins_with("forearm"))):
				continue   # arm bones drag the baggy trousers (their skin weights overlap); gestures use spine, chest, neck and head until the weights are repainted
			var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(tr, NodePath("%s:%s" % [path, bone]))
			var rest := skel.get_bone_rest(skel.find_bone(bone)).basis.get_rotation_quaternion()
			var keys: Array = d[2][bone]
			for i in keys.size():
				var e: Array = keys[i]
				var q := rest * Quaternion.from_euler(Vector3(deg_to_rad(e[0]), deg_to_rad(e[1]), deg_to_rad(e[2])))
				anim.rotation_track_insert_key(tr, d[0] * float(i) / float(keys.size() - 1), q)
		lib.add_animation(name, anim)


static func _skeleton(player: AnimationPlayer) -> Skeleton3D:
	var root := player.get_node_or_null(player.root_node)
	if root == null:
		return null
	var found := root.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null
