class_name SettingsPage
extends RefCounted
## Sound on/off, graphics preset and window mode as one parchment page. `host` is anything with open_page()/toast().

static func body(host) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var bus := AudioServer.get_bus_index("Master")
	v.add_child(_row("SOUND", "Off" if AudioServer.is_bus_mute(bus) else "On", func() -> void:
		AudioServer.set_bus_mute(bus, not AudioServer.is_bus_mute(bus)), host))
	v.add_child(_row("GRAPHICS", Quality.NAMES[Quality.level].capitalize(), func() -> void: Quality.cycle(), host))
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	v.add_child(_row("DISPLAY", "Fullscreen" if full else "Window", func() -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN), host))
	v.add_child(MR4.ink("Graphics changes finish applying the next time a scene loads.", 13, true))
	return v


static func _row(label: String, value: String, toggle: Callable, host) -> Control:
	var row := HBoxContainer.new()
	var l := MR4.ink(label, 20, false, "display")
	l.custom_minimum_size = Vector2(220, 0)
	row.add_child(l)
	var b := Button.new()
	b.text = value
	b.custom_minimum_size = Vector2(200, 44)
	b.pressed.connect(func() -> void:
		toggle.call()
		(host.page.get_meta("close") as Callable).call()
		host._open_settings())
	row.add_child(b)
	return row
