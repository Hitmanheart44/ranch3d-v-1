class_name TerrainField
extends RefCounted
## The zone's ground sampled once on a 1 m grid: heights (baked or live) and a 0..1 "bare ground" mask (roads, ranch
## paths and yards, town paving). Terrain painting and the cover scatter read these arrays instead of calling the
## expensive Overworld.height() / road_info() / RanchLayout.dirt() thousands of times each.

var rect: Rect2i
var heights := PackedFloat32Array()
var dirt := PackedFloat32Array()


static func build(ov: Overworld, p_rect: Rect2i, height_img: Image) -> TerrainField:
	var f := TerrainField.new()
	f.rect = p_rect
	f.heights = height_img.get_data().to_float32_array()
	f.dirt.resize(p_rect.size.x * p_rect.size.y)
	var area := Rect2i(ov.region.grow(12.0))
	var road := f._road_mask(ov, area)   # smoothstep(3.6 -> 2.0, distance to the nearest road), rasterised once
	for j in range(area.position.y, area.end.y):
		for i in range(area.position.x, area.end.x):
			var x := float(i)   # vertices sit on whole metres
			var z := float(j)
			var d: float = road[(j - area.position.y) * area.size.x + (i - area.position.x)]
			if x * x + z * z < 2500.0:   # the ranch's paths and yards live inside ~50 m of its centre
				d = maxf(d, RanchLayout.dirt(x, z))
			if d < 1.0 and z > 40.0 and TownLayout.paved(x, z):
				d = 1.0
			f.dirt[(j - p_rect.position.y) * p_rect.size.x + (i - p_rect.position.x)] = d
	return f


## Road mask on `area` (1 m grid): for each road segment only the pixels within 3.7 m are touched.
func _road_mask(ov: Overworld, area: Rect2i) -> PackedFloat32Array:
	var dist := PackedFloat32Array()
	dist.resize(area.size.x * area.size.y)
	dist.fill(99.0)
	for rd in [ov.road, ov.road2]:
		for k in rd.size() - 1:
			var a := Vector2(rd[k].x, rd[k].z)
			var b := Vector2(rd[k + 1].x, rd[k + 1].z)
			var lo := Vector2i(floori(minf(a.x, b.x) - 3.7), floori(minf(a.y, b.y) - 3.7))
			var hi := Vector2i(ceili(maxf(a.x, b.x) + 3.7), ceili(maxf(a.y, b.y) + 3.7))
			var ab := b - a
			var l2 := maxf(ab.length_squared(), 1e-6)
			for j in range(maxi(lo.y, area.position.y), mini(hi.y, area.end.y)):
				for i in range(maxi(lo.x, area.position.x), mini(hi.x, area.end.x)):
					var p := Vector2(i + 0.5, j + 0.5)
					var d := p.distance_to(a + ab * clampf((p - a).dot(ab) / l2, 0.0, 1.0))
					var idx := (j - area.position.y) * area.size.x + (i - area.position.x)
					if d < dist[idx]:
						dist[idx] = d
	for k in dist.size():
		dist[k] = smoothstep(3.6, 2.0, dist[k])
	return dist


func _idx(x: float, z: float) -> int:
	var i := clampi(int(floorf(x)) - rect.position.x, 0, rect.size.x - 1)
	var j := clampi(int(floorf(z)) - rect.position.y, 0, rect.size.y - 1)
	return j * rect.size.x + i


func height_at(x: float, z: float) -> float:   # bilinear between the 1 m vertices: objects stand on the surface that is drawn
	var fx := x - rect.position.x
	var fz := z - rect.position.y
	var i0 := clampi(int(floorf(fx)), 0, rect.size.x - 1)
	var j0 := clampi(int(floorf(fz)), 0, rect.size.y - 1)
	var i1 := mini(i0 + 1, rect.size.x - 1)
	var j1 := mini(j0 + 1, rect.size.y - 1)
	var tx := clampf(fx - float(i0), 0.0, 1.0)
	var tz := clampf(fz - float(j0), 0.0, 1.0)
	var w := rect.size.x
	var top := lerpf(heights[j0 * w + i0], heights[j0 * w + i1], tx)
	var bot := lerpf(heights[j1 * w + i0], heights[j1 * w + i1], tx)
	return lerpf(top, bot, tz)


func dirt_at(x: float, z: float) -> float:
	return dirt[_idx(x, z)]


## Height change over `step` metres in x and z (rise, for slope tests).
func rise_at(x: float, z: float, step: float) -> float:
	var h := height_at(x, z)
	return maxf(absf(height_at(x + step, z) - h), absf(height_at(x, z + step) - h))


## Terrain3D control map (uint32 per pixel packed into an RF image): flat grass keeps the autoshader, bare ground is
## painted base grass / overlay dirt with the mask as the blend.
func control_image() -> Image:
	var ints := PackedInt32Array()
	ints.resize(heights.size())
	for k in ints.size():
		var d := dirt[k]
		ints[k] = 1 if d < 0.05 else (1 << 22) | (int(clampf(d, 0.0, 1.0) * 255.0) << 14)
	return Image.create_from_data(rect.size.x, rect.size.y, false, Image.FORMAT_RF, ints.to_byte_array())
