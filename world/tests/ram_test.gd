extends Node


func _ready() -> void:
	var cases := {47.0: 48, 46.6: 48, 48.0: 48, 62.9: 64, 64.0: 64, 11.5: 12, 12.0: 12, 15.6: 16, 31.2: 32, 7.6: 8, 3.8: 4, 126.0: 128, 10.0: 12}
	var bad := 0
	for k in cases:
		var got := Summoner.nearest_ram_gb(float(k))
		if got != cases[k]:
			bad += 1
			print("RAM  ", k, " GB reported -> ", got, " (expected ", cases[k], ")")
	print("RAM  ", cases.size(), " cases, mismatches: ", bad, "   this machine reads ", Summoner.read_hardware()["ram_gb"], " GB")
	get_tree().quit()
