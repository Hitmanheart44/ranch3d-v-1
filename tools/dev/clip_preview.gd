extends Node3D
## Dev: the extra clips frozen mid-pose side by side. godot --path . --write-movie out.png --fixed-fps 30 --quit-after 20 res://tools/dev/clip_preview.tscn
func _ready() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.3, 7.5)
	add_child(cam)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-35, 20, 0)
	add_child(l)
	var clips := ["Idle", "Cheer", "Wave", "Bow", "Talk", "Think", "KO", "Rest"]
	for i in clips.size():
		var m := MonsterModel.new()._imported(load(OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "res://assets/models/trainer_f.glb"), {"type": "light", "hue": 0}, false)
		m.position = Vector3((i - 3.5) * 1.5, 0, 0)
		add_child(m)
		var p: AnimationPlayer = m.get_meta("skel")
		p.play(clips[i])
		p.seek(minf(0.8, p.current_animation_length * 0.5), true)
		p.pause()
