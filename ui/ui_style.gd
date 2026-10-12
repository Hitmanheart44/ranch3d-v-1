class_name UIStyle
extends RefCounted
## UIStyle: the one place for ChipMon's look (fonts, palette, panel shapes, Theme).
##
## Used by main3d.gd (ranch Theme), arena3d.gd (HUD) and summon_screen.gd.
## Fonts are SystemFonts with fallback chains, so there are still no asset files.
## Look: near-black slate, hard edges, thin hairline borders, one hot accent.

const BG := Color(0.07, 0.04, 0.035)
const PANEL := Color(0.13, 0.065, 0.05, 0.93)        # deep lacquered wood
const PANEL_HI := Color(0.2, 0.09, 0.06, 0.96)
const LINE := Color(0.62, 0.14, 0.09)                # vermilion lacquer trim
const LINE_HI := Color(0.86, 0.66, 0.3)              # gold leaf
const TEXT := Color(0.99, 0.94, 0.84)                # rice-paper cream
const DIM := Color(0.78, 0.7, 0.58)
const ACCENT := Color(0.92, 0.7, 0.3)                # gold: focus, hover
const GOOD := Color(0.55, 0.95, 0.6)
const BAD := Color(1.0, 0.36, 0.3)
const FONT_FILES := {"display": "res://assets/fonts/YujiSyuku-Regular.ttf", "body": "res://assets/fonts/ZenMaruGothic-Medium.ttf",
	"bold": "res://assets/fonts/ZenMaruGothic-Bold.ttf"}

static var _fonts: Dictionary = {}


## kind: "display" (heavy condensed, for titles and numbers), "body" (condensed), "mono" (readouts).
static func font(kind: String = "body") -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	if FONT_FILES.has(kind) and ResourceLoader.exists(FONT_FILES[kind]):  # kami theme fonts (brush titles, rounded body)
		var ff := load(FONT_FILES[kind]) as FontFile
		_fonts[kind] = ff
		return ff
	var sf := SystemFont.new()
	match kind:
		"display":
			sf.font_names = PackedStringArray(["Fira Sans Condensed", "Oswald", "Bebas Neue", "Roboto Condensed", "Arial Narrow", "DejaVu Sans Condensed", "sans-serif"])
			sf.font_weight = 800
		"mono":
			sf.font_names = PackedStringArray(["JetBrains Mono", "Hack", "Fira Mono", "DejaVu Sans Mono", "monospace"])
			sf.font_weight = 500
		_:
			sf.font_names = PackedStringArray(["Fira Sans Condensed", "Roboto Condensed", "Arial Narrow", "DejaVu Sans Condensed", "sans-serif"])
			sf.font_weight = 500
	sf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	sf.hinting = TextServer.HINTING_LIGHT
	sf.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	_fonts[kind] = sf
	return sf


## Hard-edged panel. `top` > 0 draws a thicker accent line on top (the "header bar" look).
static func box(bg: Color, border: Color, bw: int = 1, top: int = 0, pad_h: float = 14.0, pad_v: float = 8.0, skew_x: float = 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	if top > 0:
		s.border_width_top = top
	s.set_corner_radius_all(6 if skew_x == 0.0 else 0)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	s.skew = Vector2(skew_x, 0.0)
	s.anti_aliasing = skew_x != 0.0
	return s


## A plain label in one of the fonts. Uppercase + letter spacing reads as "HUD".
static func label(text: String, size: int, col: Color = TEXT, kind: String = "body") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.02, 0.9))  # readable over the bright world
	l.add_theme_constant_override("outline_size", maxi(3, size / 5))
	return l


## Nine-slice texture from assets/ui (drawn by tools/assets/make_ui_art.py).
static func tex_box(name: String, margin: int, pad_h := -1.0, pad_v := -1.0) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load("res://assets/ui/%s.png" % name)
	s.set_texture_margin_all(margin)
	s.content_margin_left = pad_h if pad_h >= 0.0 else margin
	s.content_margin_right = s.content_margin_left
	s.content_margin_top = pad_v if pad_v >= 0.0 else margin * 0.6
	s.content_margin_bottom = s.content_margin_top
	return s


## Red lacquer for the one key action on a screen (Start the week, Back...).
static func make_primary(b: Button) -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, tex_box("plate_primary_" + st, 14, 26.0, 9.0))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color(1.0, 0.95, 0.8))
	b.add_theme_constant_override("outline_size", 3)
	b.add_theme_color_override("font_outline_color", Color(0.25, 0.05, 0.03))


static func theme() -> Theme:
	var th := Theme.new()
	th.default_font = font("body")
	th.set_color("font_outline_color", "Label", Color(0.08, 0.03, 0.02, 0.9))
	th.set_constant("outline_size", "Label", 3)
	th.default_font_size = 18

	# Buttons: red lacquer with gold trim and a gloss band (textures); hover lights them up.
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		th.set_stylebox(st, "Button", tex_box("plate_" + st, 14, 26.0, 9.0))
	var ink := Color(0.2, 0.11, 0.06)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		th.set_color(k, "Button", ink)
	th.set_color("font_disabled_color", "Button", Color(0.45, 0.38, 0.3))
	th.set_constant("outline_size", "Button", 0)

	th.set_stylebox("panel", "PanelContainer", tex_box("panel_dark", 20, 24.0, 18.0))
	th.set_stylebox("panel", "Panel", tex_box("panel_dark", 20))

	th.set_stylebox("background", "ProgressBar", tex_box("bar_trough", 11, 0.0, 0.0))
	th.set_stylebox("fill", "ProgressBar", tex_box("bar_fill", 9, 0.0, 0.0))
	th.set_font("font", "ProgressBar", font("mono"))

	for cls in ["LineEdit", "TextEdit"]:
		th.set_stylebox("normal", cls, box(Color(0.02, 0.022, 0.03), LINE_HI, 1, 0, 10.0, 6.0))
		th.set_stylebox("focus", cls, box(Color(0.02, 0.022, 0.03), ACCENT, 1, 0, 10.0, 6.0))
		th.set_font("font", cls, font("mono"))

	th.set_color("font_color", "Label", TEXT)

	# Thin, square scrollbars.
	th.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), 0, 0, 3.0, 0.0))
	th.set_stylebox("grabber", "VScrollBar", box(LINE_HI, LINE_HI, 0, 0, 3.0, 0.0))
	th.set_stylebox("grabber_highlight", "VScrollBar", box(ACCENT, ACCENT, 0, 0, 3.0, 0.0))
	th.set_stylebox("grabber_pressed", "VScrollBar", box(ACCENT, ACCENT, 0, 0, 3.0, 0.0))

	th.set_stylebox("panel", "TooltipPanel", box(Color(0.02, 0.022, 0.03, 0.97), ACCENT.darkened(0.3), 1, 0, 10.0, 6.0))
	return th
