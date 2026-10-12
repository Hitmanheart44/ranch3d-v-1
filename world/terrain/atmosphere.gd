class_name Atmosphere
extends Node
## Time of day and weather for the overworld. The sun, sky brightness, fog and ambient follow a slow cycle (a full day
## is DAY_SECONDS of real time; each zone visit starts in the morning), and the weather is picked from the season and
## the week number: spring/summer/autumn clear or rain, winter clear or snow. Cheap: a few property writes per frame
## and one particle emitter that follows the camera. Weather is the same all week (seeded by week), so it never flickers.

const DAY_SECONDS := 720.0
const START_HOUR := 8.5

var sun: DirectionalLight3D
var env: Environment
var pano: PanoramaSkyMaterial
var weather := "clear"
var hour := START_HOUR
var _precip: GPUParticles3D
var _cam: Camera3D


static func attach(parent: Node, p_sun: DirectionalLight3D, p_env: Environment, p_pano: PanoramaSkyMaterial) -> Atmosphere:
	var a := Atmosphere.new()
	a.sun = p_sun
	a.env = p_env
	a.pano = p_pano
	parent.add_child(a)
	return a


func _ready() -> void:
	weather = _weather_for(Game.week)
	if weather != "clear":
		_precip = _make_precip(weather == "snow")
		add_child(_precip)
	_apply()


static func _weather_for(abs_week: int) -> String:
	var month := (abs_week / 4) % 12
	var r := RandomNumberGenerator.new()
	r.seed = abs_week * 7919 + 13
	var roll := r.randf()
	if abs_week <= 2:
		return "clear"   # a fair start to the first weeks
	if month >= 9:
		return "snow" if roll < 0.3 else "clear"
	return "rain" if roll < 0.12 else "clear"


func _process(delta: float) -> void:
	hour = fposmod(hour + delta * 24.0 / DAY_SECONDS, 24.0)
	_apply()
	if _precip != null:
		if _cam == null or not is_instance_valid(_cam):
			_cam = get_viewport().get_camera_3d()
		if _cam != null:
			_precip.global_position = _cam.global_position + Vector3(0, 14, 0)


func _apply() -> void:
	var day := clampf(sin((hour - 6.0) / 12.0 * PI), -1.0, 1.0)     # 1 at noon, 0 at 6:00 / 18:00, <0 at night
	var light := smoothstep(-0.28, 0.3, day)
	var horizon := 1.0 - smoothstep(0.0, 0.55, absf(day + 0.05))            # warm near sunrise / sunset
	var wet := 0.0 if weather == "clear" else 0.3
	sun.rotation_degrees = Vector3(-lerpf(4.0, 62.0, clampf(day, 0.0, 1.0)), lerpf(100.0, 250.0, (hour - 6.0) / 12.0), 0.0)
	sun.light_color = Color(0.55, 0.65, 1.0).lerp(Color(1.0, 0.97, 0.92).lerp(Color(1.0, 0.62, 0.36), horizon), light)
	sun.light_energy = lerpf(0.85, 1.15, light) * (1.0 - wet * 0.6)
	pano.energy_multiplier = lerpf(0.85, 1.0, light) * (1.0 - wet * 0.45)
	env.ambient_light_energy = lerpf(1.6, 0.5, light)
	env.fog_light_color = Color(0.13, 0.16, 0.27).lerp(Color(0.9, 0.78, 0.66).lerp(Color(1.0, 0.6, 0.4), horizon * 0.6), light).lerp(Color(0.62, 0.66, 0.7), wet)
	env.fog_density = 0.0016 + wet * 0.0022


func _make_precip(snow: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 900 if snow else 1400
	p.lifetime = 5.0 if snow else 1.4
	p.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 30, 60))
	p.local_coords = false
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(28, 1, 28)
	m.direction = Vector3(0.0, -1.0, 0.0)
	m.spread = 4.0 if not snow else 25.0
	m.initial_velocity_min = 3.0 if snow else 22.0
	m.initial_velocity_max = 5.0 if snow else 28.0
	m.gravity = Vector3(0.6 if snow else 2.0, 0.0, 0.2)
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07) if snow else Vector2(0.02, 0.55)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.85) if snow else Color(0.75, 0.82, 0.95, 0.45)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED if snow else BaseMaterial3D.BILLBOARD_PARTICLES
	if not snow:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	q.material = mat
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
