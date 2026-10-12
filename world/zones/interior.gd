extends Zone
## Indoor rooms in town (one scene, the room comes from Scenes.params["room"]): Mira's food shop, Tobin's goods,
## the Trainers' Association hall. Built from textured primitives, lamp-lit. The door leads back out to town.

const TOWN := "res://world/zones/town.tscn"
const ROOMS := {  # size (w, h, d), wall tint
	"food_shop": [Vector3(9, 3.6, 7), Color(1.0, 0.92, 0.8)],
	"item_shop": [Vector3(8, 3.6, 7), Color(0.92, 0.92, 1.0)],
	"association": [Vector3(15, 5.5, 11), Color(0.95, 0.88, 0.82)],
}

var room := "food_shop"
var town_ref: Node  # shop/association menus live in town.gd; we borrow them


func zone_id() -> String:
	return "interior"


func outdoor() -> bool:
	return false


func entries() -> Dictionary:
	var d: Vector3 = ROOMS[room][0]
	return {"start": [Vector3(0, 0, -d.z / 2.0 + 1.5), 0.0]}


func _pre_ready() -> bool:
	room = str(Scenes.params.get("room", "food_shop"))
	return true


func build_room() -> void:
	var size: Vector3 = ROOMS[room][0]
	var tint: Color = ROOMS[room][1]
	var floor_m := Build.mat("planks012", Vector3(size.x / 2.0, size.z / 2.0, 1), Color(0.85, 0.7, 0.55))
	var wall := Build.mat("woodsiding008", Vector3(size.x / 2.5, size.y / 2.0, 1), tint)
	Build.box(self, Vector3(0, -0.05, 0), Vector3(size.x, 0.1, size.z), floor_m, true)
	Build.box(self, Vector3(0, size.y, 0), Vector3(size.x, 0.1, size.z), Build.mat("planks012", Vector3(3, 3, 1), Color(0.45, 0.35, 0.28)))
	for side in [[Vector3(0, size.y / 2, size.z / 2), Vector3(size.x, size.y, 0.2)], [Vector3(0, size.y / 2, -size.z / 2), Vector3(size.x, size.y, 0.2)],
			[Vector3(size.x / 2, size.y / 2, 0), Vector3(0.2, size.y, size.z)], [Vector3(-size.x / 2, size.y / 2, 0), Vector3(0.2, size.y, size.z)]]:
		Build.box(self, side[0], side[1], wall, true)
	for x in [-size.x / 2.0 + 0.15, size.x / 2.0 - 0.15]:  # beams
		Build.box(self, Vector3(x, size.y / 2, 0), Vector3(0.25, size.y, 0.25), Build.mat("planks012", Vector3(1, 3, 1), Color(0.4, 0.28, 0.2)))
	Build.box(self, Vector3(0, 1.1, -size.z / 2 + 0.12), Vector3(1.4, 2.2, 0.06), Build.mat("planks012", Vector3.ONE, Color(0.6, 0.4, 0.25)))  # door
	for x in [-size.x / 4.0, size.x / 4.0]:  # windows letting in daylight
		Build.box(self, Vector3(x, size.y * 0.6, -size.z / 2 + 0.12), Vector3(1.2, 0.9, 0.04), Build.mat("", Vector3.ONE, Color(0.95, 0.92, 0.8), 1.5))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.06, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.72, 0.58)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	for x in [-size.x / 4.0, size.x / 4.0]:  # hanging lamps
		var l := OmniLight3D.new()
		l.position = Vector3(x, size.y - 0.9, 0)
		l.light_color = Color(1.0, 0.8, 0.55)
		l.light_energy = 1.6
		l.omni_range = size.x * 0.8
		add_child(l)
		Build.ball(self, l.position, 0.2, Vector3.ONE, Build.mat("", Vector3.ONE, Color(1.0, 0.8, 0.5), 3.0))
	call("_furnish_" + room, size)


func _counter(size: Vector3, z: float) -> void:
	if Props.model(self, "sf/counter_3", Vector3(0, 0, z), 1.05, PI) != null:
		return
	var wood := Build.mat("planks012", Vector3(3, 1, 1), Color(0.6, 0.42, 0.28))
	Build.box(self, Vector3(0, 0.55, z), Vector3(size.x * 0.55, 1.1, 0.8), wood, true)


## Back wall: two real shelving units at the sides (permanent furniture) and a centre rack whose spheres and boxes
## stand in for the shop's items until those are modelled. Plus floor clutter by the door.
func _shelves(size: Vector3, goods: Array) -> void:
	var back := size.z / 2 - 0.5
	var real := Props.model(self, "ph/wooden_display_shelves_01", Vector3(-size.x * 0.36, 0, back), 2.6, PI) != null
	if real:
		Props.model(self, "ph/wooden_bookshelf_worn", Vector3(size.x * 0.36, 0, back), 2.4, PI)
		Props.model(self, "ph/wooden_barrels_01", Vector3(-size.x / 2 + 0.9, 0, -size.z / 2 + 1.6), 1.0, 0.4)
		Props.model(self, "ph/potted_plant_02", Vector3(size.x / 2 - 0.8, 0, -size.z / 2 + 1.3), 1.0, 0.0, false)
		Props.model(self, "ph/wicker_basket_02", Vector3(size.x / 2 - 0.9, 0, 0.0), 0.5, 0.4, false)
	var span := size.x * (0.36 if real else 0.8)  # the item placeholder rack
	var wood := Build.mat("planks012", Vector3(2, 1, 1), Color(0.5, 0.35, 0.22))
	var n := 5 if real else 9
	for k in 3:
		var y := 0.6 + k * 0.85
		Build.box(self, Vector3(0, y, size.z / 2 - 0.45), Vector3(span, 0.08, 0.6), wood)
		for i in n:
			var c: Color = goods[(i + k) % goods.size()]
			var x := -span / 2.0 + span * (i + 0.5) / n
			if (i + k) % 3 == 0:
				Build.box(self, Vector3(x, y + 0.2, size.z / 2 - 0.45), Vector3(0.3, 0.35, 0.3), Build.mat("planks012", Vector3.ONE, c))
			else:
				Build.ball(self, Vector3(x, y + 0.18, size.z / 2 - 0.45), 0.15, Vector3.ONE, Build.mat("", Vector3.ONE, c))


func _furnish_food_shop(size: Vector3) -> void:
	_counter(size, 1.0)
	_shelves(size, [Color(0.7, 0.3, 0.22), Color(0.78, 0.62, 0.28), Color(0.42, 0.58, 0.3), Color(0.62, 0.45, 0.3)])
	for x in [-3.0, 3.0]:  # baskets of produce
		Build.cyl(self, Vector3(x, 0.3, -0.5), 0.45, 0.35, 0.6, Build.mat("planks012", Vector3.ONE, Color(0.75, 0.6, 0.35)), true, 12)
		Build.ball(self, Vector3(x, 0.65, -0.5), 0.38, Vector3(1, 0.5, 1), Build.mat("", Vector3.ONE, Color(0.9, 0.35, 0.2)))
	add_npc(Npc.make("Mira", Vector3(0, 0, 2.0), ["Fresh from the market! Kami fight better on a full belly."],
		{"robe": Color(0.85, 0.5, 0.2), "hair": Color(0.45, 0.2, 0.1), "model": "npc_mira"}, func(): Town.shop(self, true, "Mira's Food Shop")))


func _furnish_item_shop(size: Vector3) -> void:
	_counter(size, 1.0)
	_shelves(size, [Color(0.35, 0.6, 0.95), Color(0.75, 0.35, 0.85), Color(0.3, 0.8, 0.7), Color(0.95, 0.85, 0.4)])
	add_npc(Npc.make("Mira", Vector3(0, 0, 2.0), ["My other shop! Tonics, teas, oils. Things a kami-keeper needs."],
		{"robe": Color(0.3, 0.45, 0.8), "model": "npc_mira"}, func(): Town.shop(self, false, "Mira's Goods")))


func _furnish_association(size: Vector3) -> void:
	var red := Build.mat("planks012", Vector3(4, 1, 1), Color(0.85, 0.25, 0.15))
	if Props.model(self, "sf/reception_desk_2", Vector3(0, 0, 2.0), 1.0, PI) == null:
		Build.box(self, Vector3(0, 0.45, 2.0), Vector3(5.0, 0.9, 0.9), red, true)  # reception desk (low, so the clerk shows)
	var board := Build.mat("planks012", Vector3(2, 1, 1), Color(0.5, 0.36, 0.24))
	Build.box(self, Vector3(-size.x / 2 + 0.2, 2.2, -1.0), Vector3(0.1, 2.0, 3.6), board)  # tournament board
	for i in 6:
		Build.box(self, Vector3(-size.x / 2 + 0.28, 1.7 + (i / 3) * 0.9, -2.2 + (i % 3) * 1.2), Vector3(0.02, 0.6, 0.8),
			Build.mat("", Vector3.ONE, Color(0.96, 0.93, 0.84)))
	var furnished := Props.model(self, "ph/chinese_cabinet", Vector3(-3.4, 0, size.z / 2 - 0.6), 2.8, PI) != null
	if furnished:
		Props.model(self, "ph/chinese_cabinet", Vector3(3.4, 0, size.z / 2 - 0.6), 2.8, PI)
		for zz in [-2.0, 2.0]:
			Props.model(self, "ph/chinese_screen_panels", Vector3(size.x / 2 - 0.7, 0, zz), 2.4, -PI / 2)
			Props.model(self, "ph/chinese_screen_panels", Vector3(-size.x / 2 + 0.7, 0, zz + 1.0), 2.4, PI / 2)
		Props.model(self, "ph/katana_stand_01", Vector3(0, 1.0, size.z / 2 - 0.8), 0.9, PI, false)
		var sword := Props.model(self, "ph/antique_katana_01", Vector3(0.55, 1.66, size.z / 2 - 0.8), 1.1, 0.0, false)
		if sword != null:
			sword.rotation = Vector3(0.0, 0.0, PI / 2.0)   # modelled upright (1.1 m tall): laid on its side it rests across the stand's two arms
		Build.box(self, Vector3(0, 0.5, size.z / 2 - 0.8), Vector3(1.6, 1.0, 0.4), board)  # plinth for the display, clear of the back wall
		for x in [-5.6, 5.6, -1.6, 1.6]:
			Props.model(self, "ph/antique_ceramic_vase_01", Vector3(x, 0, size.z / 2 - 0.7), 1.1, x, false)
		for side in [-1, 1]:  # waiting areas either side of the door
			Props.model(self, "ph/chinese_tea_table", Vector3(side * 4.4, 0, -2.6), 0.8, 0.3)
			for dx in [-0.9, 0.9]:
				Props.model(self, "ph/chinese_armchair", Vector3(side * 4.4 + dx, 0, -3.6), 1.15, 0.0)
			Props.model(self, "ph/potted_plant_02", Vector3(side * (size.x / 2 - 0.8), 0, -size.z / 2 + 0.9), 1.2, 0.0, false)
		Props.model(self, "sf/stone_lantern_6", Vector3(-size.x / 2 + 0.9, 0, -size.z / 2 + 1.2), 1.6, 0.0)
	var gold := Build.mat("", Vector3.ONE, Color(1.0, 0.8, 0.3), 0.4)
	for i in (0 if furnished else 5):  # trophies on a ledge (fallback)
		var x := -3.0 + i * 1.5
		Build.box(self, Vector3(x, 1.4, size.z / 2 - 0.4), Vector3(1.0, 0.1, 0.5), board)
		Build.cyl(self, Vector3(x, 1.65, size.z / 2 - 0.4), 0.18, 0.08, 0.4, gold, false, 10)
		Build.cyl(self, Vector3(x, 1.5, size.z / 2 - 0.4), 0.1, 0.12, 0.1, gold, false, 10)
	for x in ([] if furnished else [-size.x / 2 + 1.5, size.x / 2 - 1.5]):  # banners (fallback)
		Build.box(self, Vector3(x, 3.2, size.z / 2 - 0.15), Vector3(1.0, 3.0, 0.03), Build.mat("", Vector3.ONE, Color(0.8, 0.15, 0.1)))
	var hana := Npc.make("Clerk Hana", Vector3(0, 0, 3.1), ["Welcome to the Trainers' Association.", "Tournaments, adventures, rank exams. What brings you in?"],
		{"robe": Color(0.7, 0.12, 0.1), "hair": Color(0.1, 0.1, 0.12), "model": "npc_hana"}, func(): Town.association(self))
	hana.yaw0 = PI  # behind her desk, facing the door
	add_npc(hana)


func setup() -> void:
	var d: Vector3 = ROOMS[room][0]
	add_exit(Vector3(0, 0, -d.z / 2.0 + 0.4), 0.9, TOWN, room + "_door", "Outside")
