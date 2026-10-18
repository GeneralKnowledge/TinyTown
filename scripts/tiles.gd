class_name VillageTiles
extends RefCounted

## Kenney Tiny Town — 12×11 atlas (16×16 cells, packed sheet has no gutter).
## Index = row * 12 + col. See assets/SPRITE_MAP.md for audit notes.

const ATLAS_COLUMNS := 12

static func atlas_coords(tile_index: int) -> Vector2i:
	return Vector2i(tile_index % ATLAS_COLUMNS, int(tile_index / ATLAS_COLUMNS))

# --- Terrain (TileMap ground layer) ---
const GRASS := 0
const GRASS_TUFTS := 1
const GRASS_FLOWERS := 2
const DIRT_PATCH := 3
const PATH_FILL := 25
const SHORE_GRASS_DIRT := 13
const SHORE_DIRT_GRASS := 14
const STONE_COURTYARD := 60

# No dedicated open-water tile in Tiny Town; river uses grass + blue overlay (documented gap).
const GROUND_UNDER_WATER := GRASS

# --- Vegetation & props (decor sprites) ---
const TREE_PINE := 7
const TREE_PINE_AUTUMN := 4
const TREE_ROUND := 16
const BUSH := 6
const TREE_PAIR := 8
const MUSHROOM := 18
const SPROUT := 17
const SIGNPOST := 83
const WELL := 104
const LOGS := 106
const AXE := 115
const BEEHIVE := 106

# --- Characters (villagers only — 16×16 scenery figures) ---
const CHAR_MIRA := 45
const CHAR_ELDEN := 56
const CHAR_TOMA := 58
const CHAR_PELLA := 59
const CHAR_FINN := 73

# --- Building parts (multi-tile compositions) ---
const ROOF_PEAK := 67
const WALL_WOOD_LEFT := 88
const WALL_WOOD_DOOR := 89
const WALL_WOOD_WINDOW := 90
const WALL_WOOD_RIGHT := 91
const TOWER_STONE := 102
const STONE_WALL := 100
const STONE_ARCH := 78
const STONE_RUIN_CORNER := 113

# Blueprint: list of { "index": int, "atlas_offset": Vector2i }
static func blueprint_hut() -> Array:
	return [
		{"index": ROOF_PEAK, "atlas_offset": Vector2i(0, -1)},
		{"index": ROOF_PEAK, "atlas_offset": Vector2i(1, -1)},
		{"index": WALL_WOOD_LEFT, "atlas_offset": Vector2i(0, 0)},
		{"index": WALL_WOOD_DOOR, "atlas_offset": Vector2i(1, 0)},
	]

static func blueprint_workshop() -> Array:
	return [
		{"index": ROOF_PEAK, "atlas_offset": Vector2i(0, -1)},
		{"index": ROOF_PEAK, "atlas_offset": Vector2i(1, -1)},
		{"index": WALL_WOOD_WINDOW, "atlas_offset": Vector2i(0, 0)},
		{"index": WALL_WOOD_RIGHT, "atlas_offset": Vector2i(1, 0)},
	]

static func blueprint_lumber_camp() -> Array:
	return [
		{"index": BUSH, "atlas_offset": Vector2i(0, 0)},
		{"index": LOGS, "atlas_offset": Vector2i(1, 0)},
		{"index": BUSH, "atlas_offset": Vector2i(2, 0)},
		{"index": AXE, "atlas_offset": Vector2i(1, 1)},
	]

static func blueprint_garden() -> Array:
	return [
		{"index": BUSH, "atlas_offset": Vector2i(0, 0)},
		{"index": SPROUT, "atlas_offset": Vector2i(1, 0)},
		{"index": BUSH, "atlas_offset": Vector2i(2, 0)},
		{"index": BEEHIVE, "atlas_offset": Vector2i(1, 1)},
	]

static func blueprint_watchtower() -> Array:
	return [
		{"index": TOWER_STONE, "atlas_offset": Vector2i(0, -1)},
		{"index": TOWER_STONE, "atlas_offset": Vector2i(1, -1)},
		{"index": STONE_WALL, "atlas_offset": Vector2i(0, 0)},
		{"index": STONE_WALL, "atlas_offset": Vector2i(1, 0)},
	]

static func blueprint_for(building_id: String) -> Array:
	match building_id:
		"hut":
			return blueprint_hut()
		"workshop":
			return blueprint_workshop()
		"lumber_camp":
			return blueprint_lumber_camp()
		"garden":
			return blueprint_garden()
		"watchtower":
			return blueprint_watchtower()
		_:
			return []
