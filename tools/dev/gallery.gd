extends Node3D
## Gallery (dev tool): every species side by side, slowly turning. Open gallery.tscn, F6.
## Use it to check MonsterModel changes without playing the game. Breeds come from res://data/species/.

var models: Array = []
var t := 0.0


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.022, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.5)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	# `godot res://gallery.tscn -- solo=3` shows one species close up (index into SpeciesDB.all()).
	var solo := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("solo="):
			solo = int(a.substr(5))
	var i := 0
	for sp: SpeciesDef in SpeciesDB.all():
		if solo >= 0 and i != solo:
			i += 1
			continue
		var m := {"species_id": sp.model_key(), "type": sp.type, "hue": (i * 37) % 360}
		var x := 0.0 if solo >= 0 else (float(i % 5) - 2.0) * 4.4
		var z := 0.0 if solo >= 0 else -float(i / 5) * 5.5 + 4.0
		var md := MonsterModel.create(m)
		md.position = Vector3(x, 0, z)
		md.rotation_degrees.y = 25.0
		add_child(md)
		models.append(md)
		var lbl := Label3D.new()
		lbl.text = sp.display_name.to_upper()
		lbl.font = UIStyle.font("display")
		lbl.font_size = 48
		lbl.pixel_size = 0.006
		lbl.position = Vector3(x, -0.35, z + 1.2)
		add_child(lbl)
		i += 1
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.position = Vector3(0, 10.0, 24.0)
	cam.look_at(Vector3(0, 1.0, -3.0))
	if solo >= 0:
		cam.position = Vector3(0, 2.6, 6.5)
		cam.look_at(Vector3(0, 1.2, 0))


func _process(delta: float) -> void:
	t += delta
	for md in models:
		MonsterModel.animate(md, t)
