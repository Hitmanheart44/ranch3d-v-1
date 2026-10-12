extends Node


func _texts(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_texts(c, out)


func _show() -> String:
	var t: Array = []
	_texts(self, t)
	return " | ".join(t)


func _ready() -> void:
	Game.new_game(Summoner.summon_machine())
	var defs: Array = SpeciesDB.all().duplicate()
	defs.sort_custom(func(a: SpeciesDef, b: SpeciesDef) -> bool: return a.roster_order < b.roster_order)
	Game.seen = {str(defs[2].id): {"owned": true, "fought": 0}, str(defs[4].id): {"owned": false, "fought": 3}}
	var book := EncyclopediaPage.body()
	add_child(book)
	await get_tree().process_frame
	var b := book as EncyclopediaPage.Book
	print("BOOK two breeds met -> ", b.defs.size(), " pages;  header: ", _show().substr(_show().find("Page"), 45))
	b.turn(1)
	await get_tree().process_frame
	await get_tree().process_frame
	print("BOOK second page is the breed met in battle: ", _show().contains("Met in battle  x3"), "   page ", b.idx + 1, " of ", b.defs.size())
	b.turn(1)
	await get_tree().process_frame
	print("BOOK wraps back to page ", b.idx + 1)
	Game.seen = {str(defs[2].id): {"owned": true, "fought": 0}}
	var one := EncyclopediaPage.body()
	add_child(one)
	await get_tree().process_frame
	var t: Array = []
	_texts(one, t)
	print("BOOK one breed met -> header: ", " | ".join(t).substr(" | ".join(t).find("Page"), 40), "   blank pages shown: ", " | ".join(t).contains("? ? ?"))
	Game.seen = {}
	var none := EncyclopediaPage.body()
	add_child(none)
	await get_tree().process_frame
	var t2: Array = []
	_texts(none, t2)
	print("BOOK no breeds met -> ", " | ".join(t2).contains("Nothing recorded yet"))
	get_tree().quit()
