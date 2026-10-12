class_name BattleIntro
extends CanvasLayer
## Battle-start transition (our own take on the MR4 encounter screen): the frame freezes, a vermilion brush
## stroke slashes across it with a seal and the foe's name, then the frozen frame shatters into shards that fall
## away into darkness. Calls `done` when the screen is black, so the arena loads behind it.
##   BattleIntro.play(self, "ENCOUNTER", "VEXA / PLANT", func(): Scenes.goto(...))

const COLS := 9
const ROWS := 5

var title := ""
var sub := ""
var done: Callable


static func play(parent: Node, p_title: String, p_sub: String, p_done: Callable) -> void:
	var b := BattleIntro.new()
	b.title = p_title
	b.sub = p_sub
	b.done = p_done
	b.layer = 50
	parent.add_child(b)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var tex := ImageTexture.create_from_image(img)
	var size := get_viewport().get_visible_rect().size
	var black := ColorRect.new()
	black.color = Color(0, 0, 0)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	var shards: Array[TextureRect] = []
	var cw := size.x / COLS
	var ch := size.y / ROWS
	var iw := float(img.get_width()) / COLS
	var ih := float(img.get_height()) / ROWS
	for j in ROWS:
		for i in COLS:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * iw, j * ih, iw, ih)
			var t := TextureRect.new()
			t.texture = at
			t.stretch_mode = TextureRect.STRETCH_SCALE
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.position = Vector2(i * cw, j * ch)
			t.size = Vector2(cw + 1, ch + 1)
			t.pivot_offset = t.size / 2.0
			add_child(t)
			shards.append(t)
	# the brush stroke and the seal, over the frozen frame
	var stroke := ColorRect.new()
	stroke.color = UIStyle.LINE
	stroke.size = Vector2(size.x * 1.4, 120)
	stroke.position = Vector2(-size.x * 1.4, size.y / 2.0 - 60)
	stroke.rotation = -0.06
	add_child(stroke)
	var gold := ColorRect.new()
	gold.color = UIStyle.LINE_HI
	gold.size = Vector2(size.x * 1.4, 4)
	gold.position = Vector2(size.x * 1.4, size.y / 2.0 + 64)
	gold.rotation = -0.06
	add_child(gold)
	var seal := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIStyle.LINE.darkened(0.2)
	sb.border_color = UIStyle.LINE_HI
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(6)
	seal.add_theme_stylebox_override("panel", sb)
	seal.size = Vector2(150, 150)
	seal.pivot_offset = seal.size / 2.0
	seal.position = Vector2(size.x * 0.18 - 75, size.y / 2.0 - 75)
	seal.scale = Vector2(3, 3)
	seal.modulate.a = 0.0
	seal.rotation = 0.3
	add_child(seal)
	var kanji := UIStyle.label("戦", 96, UIStyle.TEXT, "display")
	kanji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kanji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kanji.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	seal.add_child(kanji)
	var t1 := UIStyle.label(title, 64, UIStyle.TEXT, "display")
	t1.position = Vector2(size.x * 0.3, size.y / 2.0 - 58)
	t1.modulate.a = 0.0
	add_child(t1)
	var t2 := UIStyle.label(sub, 22, UIStyle.ACCENT, "display")
	t2.position = Vector2(size.x * 0.3 + 6, size.y / 2.0 + 14)
	t2.modulate.a = 0.0
	add_child(t2)
	Sound.sfx("summon", -6.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(stroke, "position:x", -size.x * 0.2, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(gold, "position:x", -size.x * 0.2, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(seal, "scale", Vector2.ONE, 0.25).set_delay(0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(seal, "modulate:a", 1.0, 0.12).set_delay(0.12)
	tw.tween_property(seal, "rotation", -0.08, 0.25).set_delay(0.12)
	tw.tween_property(t1, "modulate:a", 1.0, 0.15).set_delay(0.2)
	tw.tween_property(t2, "modulate:a", 1.0, 0.15).set_delay(0.3)
	await tw.finished
	await get_tree().create_timer(0.75).timeout
	# shatter: every shard spins and falls away from the seal; the text goes with it
	var tw2 := create_tween()
	tw2.set_parallel(true)
	var origin := seal.position + seal.size / 2.0
	for s in shards:
		var c := s.position + s.size / 2.0
		var away := (c - origin).normalized() * randf_range(120, 380) + Vector2(0, randf_range(400, 900))
		var dl := c.distance_to(origin) / size.x * 0.25
		tw2.tween_property(s, "position", s.position + away, 0.75).set_delay(dl).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw2.tween_property(s, "rotation", randf_range(-2.5, 2.5), 0.75).set_delay(dl)
		tw2.tween_property(s, "scale", Vector2.ONE * randf_range(0.4, 0.8), 0.75).set_delay(dl)
		tw2.tween_property(s, "modulate:a", 0.0, 0.5).set_delay(dl + 0.25)
	for n in [stroke, gold, seal, t1, t2]:
		tw2.tween_property(n, "modulate:a", 0.0, 0.5).set_delay(0.35)
	await tw2.finished
	if done.is_valid():
		done.call()
