class_name VillageTiles
extends RefCounted

const ATLAS_COLUMNS := 12

static func atlas_coords(tile_index: int) -> Vector2i:
	return Vector2i(tile_index % ATLAS_COLUMNS, int(tile_index / ATLAS_COLUMNS))

# Hand-picked Kenney Tiny Town tile indices (16×16 atlas).
const GRASS := 0
const GRASS_FLOWERS := 1
const GRASS_ALT := 2
const DIRT := 14
const PATH := 14
const WATER := 0
const TREE := 7
const TREE_ORANGE := 4
const BUSH := 6
const FENCE := 24
const STONE_FLOOR := 60
const SHRINE_STONE := 100
const WELL := 83

const CHAR_MIRA := 45
const CHAR_ELDEN := 56
const CHAR_TOMA := 58
const CHAR_PELLA := 22
const CHAR_FINN := 47

const HOUSE_WOOD_A := 91
const HOUSE_WOOD_B := 92
const HOUSE_ROOF := 67
const TOWER_STONE := 101
