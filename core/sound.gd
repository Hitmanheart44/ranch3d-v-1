extends Node
## Music, ambience and sound effects. Watches the current scene and crossfades to its track, so zones don't have
## to call anything. Sound.sfx("click") from anywhere. Audio is synthesized by tools/audio/synth.py.

const TRACKS := {  # scene file -> [music, ambience]
	"title": ["title", "sea"], "ranch_v2": ["ranch", "wind"], "creator": ["ranch", ""], "intro": ["title", "sea"], "town": ["town", "birds"],
	"interior": ["town", ""], "shrine": ["shrine", "birds"], "arena": ["battle", ""], "dungeon": ["cave", "cave"], "cup_intro": ["battle", ""],
}
const MUSIC_DB := -9.0
const AMB_DB := -16.0

var music: Array[AudioStreamPlayer] = []  # two players for crossfading
var amb: AudioStreamPlayer
var cur := 0
var playing := ""
var playing_amb := ""
var pool: Array[AudioStreamPlayer] = []
var last_scene: Node
var _variants := {}   # sfx name -> how many numbered variants exist (name_1, name_2...), found once


## Music / SFX / Ambience buses (created here so no editor layout file is needed), with a gentle compressor on SFX,
## and "duck" to lower the music while something important (dialogue, a banner) plays.
func _setup_buses() -> void:
	for n in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(n) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, n)
			AudioServer.set_bus_send(i, "Master")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx_bus) == 0:
		var comp := AudioEffectCompressor.new()
		comp.threshold = -14.0
		comp.ratio = 3.0
		AudioServer.add_bus_effect(sfx_bus, comp)
		var rev := AudioEffectReverb.new()
		rev.wet = 0.06
		rev.room_size = 0.4
		AudioServer.add_bus_effect(sfx_bus, rev)


func duck(db := -6.0, seconds := 1.5) -> void:
	var bus := AudioServer.get_bus_index("Music")
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: AudioServer.set_bus_volume_db(bus, v), AudioServer.get_bus_volume_db(bus), db, 0.2)
	tw.tween_interval(seconds)
	tw.tween_method(func(v: float) -> void: AudioServer.set_bus_volume_db(bus, v), db, 0.0, 0.8)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -60.0
		p.bus = "Music"
		add_child(p)
		music.append(p)
	amb = AudioStreamPlayer.new()
	amb.bus = "Ambience"
	add_child(amb)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		pool.append(p)


func _process(_d: float) -> void:
	var s := get_tree().current_scene
	if s == last_scene or s == null:
		return
	last_scene = s
	var key := s.scene_file_path.get_file().get_basename()
	if key in TRACKS:
		play_music(TRACKS[key][0])
		play_amb(TRACKS[key][1])


func _load(name: String) -> AudioStream:
	var path := "res://assets/audio/%s.ogg" % name
	if not ResourceLoader.exists(path):
		return null
	var st: AudioStream = load(path)
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = name.begins_with("music_") or name.begins_with("amb_")
	return st


func play_music(name: String) -> void:
	if name == playing:
		return
	playing = name
	var old := music[cur]
	cur = 1 - cur
	var p := music[cur]
	p.stream = _load("music_" + name) if name != "" else null
	if p.stream == null:  # silence (e.g. a video plays its own sound): fade the old track out
		create_tween().tween_property(old, "volume_db", -60.0, 0.8)
		return
	p.volume_db = -40.0
	p.play()
	var tw := create_tween().set_parallel()
	tw.tween_property(p, "volume_db", MUSIC_DB, 1.5)
	tw.tween_property(old, "volume_db", -60.0, 1.5)
	tw.chain().tween_callback(old.stop)


func play_amb(name: String) -> void:
	if name == playing_amb:
		return
	playing_amb = name
	if name == "":
		amb.stop()
		return
	amb.stream = _load("amb_" + name)
	amb.volume_db = AMB_DB
	amb.play()


func sfx(name: String, db := -6.0, pitch_jitter := 0.0) -> void:
	if not _variants.has(name):   # sfx_hit_1.ogg, sfx_hit_2.ogg... pick one at random; plain sfx_hit.ogg still works
		var n := 0
		while ResourceLoader.exists("res://assets/audio/sfx_%s_%d.ogg" % [name, n + 1]):
			n += 1
		_variants[name] = n
	var pick := name if _variants[name] == 0 else "%s_%d" % [name, randi_range(1, _variants[name])]
	var st := _load("sfx_" + pick)
	if st == null:
		return
	for p in pool:
		if not p.playing:
			p.stream = st
			p.volume_db = db
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return
