extends Node2D
## Builds a simple Hell room at runtime from two layers:
##   - a 16x16 TileMapLayer for floor and walls (walls have collision)
##   - a 32x32 TileMapLayer for big decor (door arch, pillars, pit)
## Attach this script to an empty Node2D. No scene setup required.

const TILES_16 := "res://assets/16x16/16x16_%03d.png"
const TILES_32 := "res://assets/32x32/32x32_%03d.png"

# Legend for the 16x16 layout -> tile file number in assets/16x16
const LEGEND_16 := {
	"C": 4,   # wall cap (top edge)
	"W": 6,   # top wall face (brick)
	"S": 18,  # side wall
	"B": 12,  # bottom wall
	".": 16,  # floor
	",": 30,  # floor variant
	"r": 28,  # rubble
	"o": 34,  # boulder
	"t": 26,  # stairs down
	" ": -1,  # leave empty (covered by a 32x32 tile)
}
const SOLID_16 := ["C", "W", "S", "B", "r", "o"]

# 20 x 13 tiles = 320 x 208 px
const LAYOUT_16 := [
	"CCCCCCCC  CCCCCCCCCC",
	"WWWWWWWW  WWWWWWWWWW",
	"S..................S",
	"S.r..............o.S",
	"S..................S",
	"S........,.........S",
	"S...,..............S",
	"S..................S",
	"S.............,....S",
	"S..o...............S",
	"S..............r...S",
	"S..................S",
	"BBBBBBBBttBBBBBBBBBB",
]

# 32x32 decor: [cell on the 32 grid, tile file number, solid?]
const DECOR_32 := [
	[Vector2i(4, 0), 16, true],   # arched doorway in the top wall
	[Vector2i(2, 2), 13, true],   # pillars
	[Vector2i(7, 2), 13, true],
	[Vector2i(2, 4), 13, true],
	[Vector2i(7, 4), 13, true],
	[Vector2i(4, 3), 10, false],  # swirling pit in the center
]

var floor_layer: TileMapLayer
var decor_layer: TileMapLayer


func _ready() -> void:
	floor_layer = _make_layer("Floor16", 16, _tile_ids_16())
	decor_layer = _make_layer("Decor32", 32, _tile_ids_32())
	_paint_16()
	_paint_32()


func _tile_ids_16() -> Dictionary:
	var ids := {}
	for key in LEGEND_16:
		var n: int = LEGEND_16[key]
		if n >= 0:
			ids[n] = key in SOLID_16
	return ids


func _tile_ids_32() -> Dictionary:
	var ids := {}
	for entry in DECOR_32:
		ids[entry[1]] = ids.get(entry[1], false) or entry[2]
	return ids


## Creates a TileMapLayer whose TileSet has one atlas source per tile file.
## Source id == tile file number. `ids` maps tile number -> has collision.
func _make_layer(layer_name: String, size: int, ids: Dictionary) -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(size, size)
	tile_set.add_physics_layer()
	var path_fmt := TILES_16 if size == 16 else TILES_32
	var half := size / 2.0
	var box := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	])

	for n in ids:
		var source := TileSetAtlasSource.new()
		source.texture = load(path_fmt % n)
		source.texture_region_size = Vector2i(size, size)
		source.create_tile(Vector2i.ZERO)
		tile_set.add_source(source, n)
		if ids[n]:
			var data := source.get_tile_data(Vector2i.ZERO, 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, box)

	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	add_child(layer)
	return layer


func _paint_16() -> void:
	for y in LAYOUT_16.size():
		var row: String = LAYOUT_16[y]
		for x in row.length():
			var n: int = LEGEND_16.get(row[x], -1)
			if n >= 0:
				floor_layer.set_cell(Vector2i(x, y), n, Vector2i.ZERO)


func _paint_32() -> void:
	for entry in DECOR_32:
		decor_layer.set_cell(entry[0], entry[1], Vector2i.ZERO)
