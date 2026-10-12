extends Node
## Graphics quality presets (Low / Medium / High), saved to user://settings.cfg. First run picks Low on integrated or
## software GPUs (old laptops, i5 + no graphics card, Wine) and High otherwise. Zones read Quality.level for density.
## Quality.cycle() steps to the next preset; Quality.apply() re-applies it to the viewport.

const PATH := "user://settings.cfg"
const NAMES := ["LOW", "MEDIUM", "HIGH"]
const SCALE := [0.5, 0.85, 1.0]            # 3D render scale (UI stays sharp)
const SHADOW_ATLAS := [1024, 2048, 4096]
const SHADOW_DIST := [22.0, 45.0, 80.0]
const MSAA := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
## Multiplier for scattered clutter / grass / far trees (1.0 = full).
const DENSITY := [0.12, 0.7, 1.0]

var level := 2


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		level = clampi(int(cfg.get_value("graphics", "quality", 2)), 0, 2)
	else:
		level = _detect()
	apply()


## First-run preset from the adapter name (the Compatibility renderer reports every GPU as type OTHER, so the name is all we have):
## software GL and old Intel HD parts -> LOW, newer Intel (Iris / UHD / Arc) -> MEDIUM, NVIDIA / AMD -> HIGH.
func _detect() -> int:
	var n := RenderingServer.get_video_adapter_name().to_lower()
	if "llvmpipe" in n or "softpipe" in n or "swrast" in n or "software" in n or "microsoft basic" in n:
		return 0
	if "intel" in n:
		return 0 if ("hd graphics" in n and not "uhd" in n) else 1
	return 2


func apply() -> void:
	var vp := get_viewport()
	vp.scaling_3d_scale = SCALE[level]
	vp.msaa_3d = MSAA[level]
	vp.mesh_lod_threshold = [10.0, 3.0, 1.0][level]   # bigger = switch to simpler mesh LODs sooner (imported GLBs have generated LODs)
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS[level], true)


func cycle() -> void:
	level = (level + 1) % 3
	apply()
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("graphics", "quality", level)
	cfg.save(PATH)


## Cheap-GPU switches: Low has no shadows, no glow and the lightweight terrain shader.
func shadows() -> bool:
	return level > 0


func glow() -> bool:
	return level > 0


func density() -> float:
	return DENSITY[level]


func shadow_distance() -> float:
	return SHADOW_DIST[level]
