class_name EnvPresets
extends RefCounted
## Shared lighting moods, so every scene looks like the same game.


## Dark night: AgX, glow, SSAO, reflections, volumetric fog tinted by `accent`.
static func night(accent: Color) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.006, 0.007, 0.01)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.35, 0.45)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.ssr_enabled = true
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.018
	env.volumetric_fog_albedo = Color(0.55, 0.6, 0.7)
	env.volumetric_fog_emission = accent * 0.003
	env.volumetric_fog_anisotropy = 0.55
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	return env


## Moonlight with shadows. Add it to the scene.
static func moon() -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-55, 30, 0)
	l.light_energy = 0.6
	l.light_color = Color(0.72, 0.8, 1.0)
	l.shadow_enabled = true
	l.light_volumetric_fog_energy = 0.4
	return l
