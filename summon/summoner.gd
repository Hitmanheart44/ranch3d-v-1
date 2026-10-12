class_name Summoner
extends RefCounted
## Deterministic "summon a kami from X" system (Kami Rancher style).
## Godot 4.x, GDScript. Same input -> same kami on Windows and Linux.
##
## Returns a MonsterData (main breed x sub breed) built from the breeds in res://data/species/.
##
## Usage:
##   var m := Summoner.summon_machine()   # THE summon: this PC's CPU + GPU + threads + RAM class
##   var m := Summoner.summon_text("hello world")
##   var m := Summoner.summon_file("C:/some/song.mp3")
##   var m := Summoner.summon_daily()
##   var m := Summoner.summon_steam(steam_id)   # pass GodotSteam's Steam.getSteamID()
##
## Save the returned MonsterData in your save file. Never re-summon on load: adding breeds
## (see SpeciesDef.roster_order) changes what every input summons.

# Bump this if you ever change the algorithm. Old saves keep their stored kami.
const SALT := "ranch3d-v1"

const STAT_NAMES := ["hp", "power", "guard", "speed", "focus"]
const STAT_BUDGET := 300  # every kami has exactly this many total stat points
const MIN_STAT := 5       # floor per stat (data/balance.tres stat_min)

const PERSONALITIES := [
	"stubborn", "curious", "lazy", "fierce", "shy", "loyal",
	"mischievous", "calm", "proud", "anxious", "cheerful", "grumpy",
]

# ---------------------------------------------------------------------------
# Deterministic RNG (SplitMix64). Do NOT use Godot's RandomNumberGenerator
# here: its algorithm could change between engine versions.
# GDScript ints are 64-bit and wrap on overflow, which is what we want.
# The big constants are written as signed int64 equivalents of:
#   0x9E3779B97F4A7C15, 0xBF58476D1CE4E5B9, 0x94D049BB133111EB
# ---------------------------------------------------------------------------
class Rng:
	var state: int

	func _init(seed_value: int) -> void:
		state = seed_value

	static func _shr(x: int, n: int) -> int:
		# logical shift right (GDScript's >> is arithmetic)
		return (x >> n) & ((1 << (64 - n)) - 1)

	func next_u64() -> int:
		state += -7046029254386353131
		var z: int = state
		z = (z ^ _shr(z, 30)) * -4658895280553007687
		z = (z ^ _shr(z, 27)) * -7723592293110705685
		return z ^ _shr(z, 31)

	## Integer in [0, n). Integer math only, so no float differences.
	func next_int(n: int) -> int:
		return _shr(next_u64(), 1) % n


# ---------------------------------------------------------------------------
# Public summon entry points
# ---------------------------------------------------------------------------

## Locked to normalized CPU + GPU + thread count + RAM class (OS and monitor don't matter). The MAIN breed is chosen by the
## hardware identifier plus today's date (UTC), so the kami your machine offers changes every day; the sub breed, stats, personality,
## hue and quirks come from the hardware alone and are the same every day. `day` defaults to today.
static func summon_machine(day: String = "") -> MonsterData:
	var hw := read_hardware()
	var today := day if day != "" else Time.get_date_string_from_system(true)
	return _summon("machine", [hw["cpu_brand"], hw["gpu_name"], hw["threads"], hw["ram_gb"]], hw, [today])


## A machine found in an adventure: `makeup` = [cpu, gpu, threads, ram_gb], `nonce` makes every found machine unique. All rolls, main breed included, come from that seed.
static func summon_found(makeup: Array, nonce: int) -> MonsterData:
	return _summon("found", makeup + [nonce], read_hardware())

static func summon_daily() -> MonsterData:
	var hw := read_hardware()
	var today := Time.get_date_string_from_system(true)  # UTC, so travel/timezones don't matter
	return _summon("daily", [hw["cpu_brand"], today], hw)

static func summon_steam(steam_id: int) -> MonsterData:
	return _summon("steam", [str(steam_id)], read_hardware())

## Kami live 4 to 6 years (192..288 weeks): a species' base longevity (about 150..200) mapped into that range.
static func lifespan(base: int) -> int:
	return clampi(192 + int(round(float(base - 150) / 50.0 * 96.0)), 192, 288)


static func summon_text(text: String) -> MonsterData:
	return _summon("text", [text.strip_edges().to_lower()], read_hardware())

## Hash any file's raw bytes (binary, so no line-ending issues). Returns null on failure.
static func summon_file(path: String) -> MonsterData:
	var hex := FileAccess.get_sha256(path)
	if hex.is_empty():
		push_warning("Summoner: couldn't read file: " + path)
		return null
	return _summon("file", [hex], read_hardware())


# ---------------------------------------------------------------------------
# Core: parts -> SHA-256 -> seed -> kami
# ---------------------------------------------------------------------------

static func _summon(channel: String, parts: Array, hw: Dictionary, main_parts: Array = []) -> MonsterData:
	var all_parts := PackedStringArray([SALT, channel])
	for p in parts:
		all_parts.append(str(p))

	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update("|".join(all_parts).to_utf8_buffer())
	var digest := ctx.finish()

	var rng := Rng.new(digest.decode_s64(0))
	var roster := SpeciesDB.all()

	# Roll order matters. Never reorder these or every kami changes.
	var main: SpeciesDef = roster[rng.next_int(roster.size())]
	var seed_digest := digest
	if not main_parts.is_empty():   # the main breed rotates with main_parts (the date); every other roll stays hardware-only
		var mp := PackedStringArray([SALT, channel, "main"])
		for p in parts:
			mp.append(str(p))
		for p in main_parts:
			mp.append(str(p))
		var mctx := HashingContext.new()
		mctx.start(HashingContext.HASH_SHA256)
		mctx.update("|".join(mp).to_utf8_buffer())
		seed_digest = mctx.finish()
		main = roster[Rng.new(seed_digest.decode_s64(0)).next_int(roster.size())]
	var sub: SpeciesDef = roster[rng.next_int(roster.size())]
	var bias: Array[int] = []
	for i in STAT_NAMES.size():
		bias.append(main.bias[i] * 8 + sub.bias[i] * 2)  # 80% main, 20% sub, integer math
	var stats := _roll_stats(rng, bias)
	var personality: String = PERSONALITIES[rng.next_int(PERSONALITIES.size())]
	var hue := rng.next_int(360)

	var m := MonsterData.new()
	m.source = channel
	m.main_breed = main.id
	m.sub_breed = sub.id
	m.name = main.display_name
	m.type = main.type
	m.stats = stats
	m.personality = personality
	m.hue = hue
	m.lifespan_weeks = Summoner.lifespan(main.lifespan_weeks)
	m.quirks = PackedStringArray(_quirks_from_hardware(hw))  # flavor only, never affects the stat budget
	m.seed_hex = seed_digest.hex_encode().substr(0, 16)
	return m

## Breeding: one parent's main breed + the other's as the sub breed. 60% of the stats come from a fresh roll,
## 40% from the parents' (trained) stats, so training pays off across generations. Same pair = same child.
static func combine(a: MonsterData, b: MonsterData) -> MonsterData:
	if b.seed_hex < a.seed_hex:  # order-independent: the same pair always gives the same child
		var t := a
		a = b
		b = t
	var keys := [a.seed_hex, b.seed_hex]
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(("%s|combine|%s|%s" % [SALT, keys[0], keys[1]]).to_utf8_buffer())
	var digest := ctx.finish()
	var rng := Rng.new(digest.decode_s64(0))
	var first := a if rng.next_int(2) == 0 else b
	var second := b if first == a else a
	var main := SpeciesDB.get_def(first.main_breed)
	var sub := SpeciesDB.get_def(second.main_breed)
	var bias: Array[int] = []
	for i in STAT_NAMES.size():
		bias.append(main.bias[i] * 8 + sub.bias[i] * 2)
	var roll := _roll_stats(rng, bias)
	var stats := {}
	for s in STAT_NAMES:
		stats[s] = maxi(MIN_STAT, int(roll[s] * 0.6 + (a.stat(s) + b.stat(s)) * 0.5 * 0.4))
	var m := MonsterData.new()
	m.source = "combine"
	m.main_breed = main.id
	m.sub_breed = sub.id
	m.name = main.display_name
	m.type = main.type
	m.stats = stats
	m.personality = PERSONALITIES[rng.next_int(PERSONALITIES.size())]
	m.hue = (a.hue + b.hue) / 2 if rng.next_int(2) == 0 else rng.next_int(360)
	m.lifespan_weeks = Summoner.lifespan(main.lifespan_weeks)
	var q := PackedStringArray()
	for x in a.quirks + b.quirks:
		if not x in q:
			q.append(x)
	m.quirks = q
	m.seed_hex = digest.hex_encode().substr(0, 16)
	return m


@warning_ignore("integer_division")
static func _roll_stats(rng: Rng, bias: Array) -> Dictionary:
	var weights: Array[int] = []
	var total_weight := 0
	for i in STAT_NAMES.size():
		var w: int = int(bias[i]) * (50 + rng.next_int(100))
		weights.append(w)
		total_weight += w

	var free := STAT_BUDGET - MIN_STAT * STAT_NAMES.size()
	var values: Array[int] = []
	var used := 0
	var top := 0
	for i in STAT_NAMES.size():
		var v: int = MIN_STAT + (free * weights[i]) / total_weight
		values.append(v)
		used += v
		if weights[i] > weights[top]:
			top = i
	values[top] += STAT_BUDGET - used  # rounding leftovers go to the strongest stat

	var out := {}
	for i in STAT_NAMES.size():
		out[STAT_NAMES[i]] = values[i]
	return out


# ---------------------------------------------------------------------------
# Hardware reading (all no-permission, works on native Windows + Linux)
# ---------------------------------------------------------------------------

## The memory sizes a machine is recognised as having.
const RAM_SIZES := [1, 2, 4, 8, 12, 16, 32, 48, 64, 128, 256]


## The recognised size closest to what the OS reports (compared by ratio, so 10 GB is nearer 12 than 8).
static func nearest_ram_gb(reported_gb: float) -> int:
	var best: int = RAM_SIZES[0]
	var best_off := INF
	for size in RAM_SIZES:
		var off := absf(log(maxf(reported_gb, 0.01) / float(size)))
		if off < best_off:
			best_off = off
			best = size
	return best


static func read_hardware() -> Dictionary:
	var mem := OS.get_memory_info()
	var ram_bytes: int = int(mem.get("physical", -1))
	var ram_gb := 0
	if ram_bytes > 0:
		# Snap to a size the machine was sold with, so 15.6 GB and 16 GB match across OSes (the OS reports a little under the label).
		ram_gb = nearest_ram_gb(ram_bytes / 1073741824.0)

	return {
		"cpu_brand": normalize_cpu(OS.get_processor_name()),
		"threads": OS.get_processor_count(),
		"ram_gb": ram_gb,
		"gpu_name": normalize_gpu(RenderingServer.get_video_adapter_name()),
		"steam_deck": OS.get_environment("SteamDeck") == "1",
	}

static func _quirks_from_hardware(hw: Dictionary) -> Array[String]:
	var q: Array[String] = []
	var threads: int = hw["threads"]
	if threads <= 2:
		q.append("veteran")
	elif threads >= 16:
		q.append("hivemind")
	elif threads >= 8:
		q.append("multithreaded")
	if int(hw["ram_gb"]) >= 32:
		q.append("glutton")
	if hw["steam_deck"]:
		q.append("handheld")
	return q


# ---------------------------------------------------------------------------
# Normalizers: make "the same chip" produce the same string on both OSes
# ---------------------------------------------------------------------------

static func _collapse_spaces(s: String) -> String:
	return " ".join(s.split(" ", false))

static func normalize_cpu(raw: String) -> String:
	var t := raw.to_lower().replace("(r)", "").replace("(tm)", "")
	var rx := RegEx.new()
	# drop "@ 3.40GHz", "6-Core Processor", and filler words
	rx.compile("@.*$|\\d+-core processor|\\bcpu\\b|\\bprocessor\\b|[^a-z0-9 ]")
	t = rx.sub(t, " ", true)
	return _collapse_spaces(t)

static func normalize_gpu(raw: String) -> String:
	var t := raw.to_lower().replace("(r)", "").replace("(tm)", "")
	var rx := RegEx.new()
	# Mesa on Linux appends junk like "(radeonsi, navi21, LLVM ...)" and prefixes "Mesa"
	rx.compile("\\(.*?\\)|\\bmesa\\b|\\bcorporation\\b|\\bdirect3d\\d*\\b|[^a-z0-9 ]")
	t = rx.sub(t, " ", true)
	return _collapse_spaces(t)


