extends Control

const VillageTiles = preload("res://scripts/tiles.gd")
const TEX_PATH := "res://assets/kenney/tiny-town/Tilemap/tilemap_packed.png"

@onready var world_root: Node2D = %WorldRoot
@onready var tilemap: TileMapLayer = %Ground
@onready var water_layer: Node2D = %Water
@onready var decor: Node2D = %Decor
@onready var buildings_root: Node2D = %Buildings
@onready var villagers_root: Node2D = %Villagers
@onready var resource_label: Label = %ResourceLabel
@onready var activity_label: Label = %ActivityLabel
@onready var toast_label: Label = %ToastLabel
@onready var history_list: ItemList = %HistoryList
@onready var build_option: OptionButton = %BuildOption
@onready var villager_option: OptionButton = %VillagerOption
@onready var poi_option: OptionButton = %PoiOption
@onready var speed_btn: Button = %SpeedBtn
@onready var pause_btn: Button = %PauseBtn
@onready var offer_btn: Button = %OfferBtn

var _tileset_ready := false
var _villager_nodes: Dictionary = {}
var _toast_timer := 0.0
var _world_scale := 1.35

func _ready() -> void:
	world_root.scale = Vector2(_world_scale, _world_scale)
	_setup_tilemap()
	_paint_map()
	_spawn_river()
	_spawn_world_props()
	_refresh_buildings()
	_setup_ui()
	_sync_villagers()
	GameState.resources_changed.connect(_on_resources)
	GameState.buildings_changed.connect(_refresh_buildings)
	GameState.villagers_changed.connect(_sync_villagers)
	GameState.history_added.connect(_on_history)
	GameState.toast.connect(_show_toast)
	GameState.discovery_updated.connect(_refresh_poi_options)
	_on_resources()
	_refresh_history()
	_refresh_poi_options()

func _setup_tilemap() -> void:
	var tex: Texture2D = load(TEX_PATH)
	var ts := TileSet.new()
	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(16, 16)
	atlas.separation = Vector2i(0, 0)
	for i in range(132):
		var c := VillageTiles.atlas_coords(i)
		atlas.create_tile(c)
	ts.add_source(atlas, 0)
	tilemap.tile_set = ts
	_tileset_ready = true

func _tile_atlas(index: int) -> Vector2i:
	return VillageTiles.atlas_coords(index)

func _paint_map() -> void:
	if not _tileset_ready:
		return
	for y in GameState.MAP_H:
		for x in GameState.MAP_W:
			var terrain: int = GameState.map_grid[y][x]
			var idx := VillageTiles.GRASS
			match terrain:
				GameState.Terrain.GRASS:
					idx = _grass_variant(x, y)
				GameState.Terrain.GRASS_ALT:
					idx = VillageTiles.GRASS_TUFTS
				GameState.Terrain.PATH:
					idx = VillageTiles.PATH_FILL
				GameState.Terrain.WATER:
					idx = VillageTiles.GROUND_UNDER_WATER
				GameState.Terrain.BLOCKED:
					idx = VillageTiles.STONE_COURTYARD
			tilemap.set_cell(Vector2i(x, y), 0, _tile_atlas(idx))

func _grass_variant(x: int, y: int) -> int:
	var n := (x * 7 + y * 13) % 5
	match n:
		0:
			return VillageTiles.GRASS
		1:
			return VillageTiles.GRASS_TUFTS
		2:
			return VillageTiles.GRASS_FLOWERS
		_:
			return VillageTiles.GRASS

func _spawn_river() -> void:
	for c in water_layer.get_children():
		c.queue_free()
	for y in GameState.MAP_H:
		for x in GameState.MAP_W:
			if GameState.map_grid[y][x] != GameState.Terrain.WATER:
				continue
			var r := ColorRect.new()
			r.size = Vector2(16, 16)
			r.position = Vector2(x, y) * 16
			r.color = Color(0.18, 0.42, 0.78, 0.88)
			water_layer.add_child(r)

func _spawn_world_props() -> void:
	for c in decor.get_children():
		c.queue_free()
	# Forest edge (north)
	_place_prop(VillageTiles.TREE_PINE, Vector2i(6, 2), 12)
	_place_prop(VillageTiles.TREE_PINE, Vector2i(8, 2), 12)
	_place_prop(VillageTiles.TREE_PAIR, Vector2i(10, 2), 12)
	_place_prop(VillageTiles.TREE_PINE, Vector2i(12, 2), 12)
	_place_prop(VillageTiles.TREE_PINE_AUTUMN, Vector2i(14, 2), 12)
	_place_prop(VillageTiles.TREE_PINE, Vector2i(15, 3), 12)
	_place_prop(VillageTiles.BUSH, Vector2i(5, 4), 13)
	# Shrine (stone arch + sign)
	_place_prop(VillageTiles.STONE_ARCH, Vector2i(18, 3), 11)
	_place_prop(VillageTiles.STONE_ARCH, Vector2i(19, 4), 11)
	# Village well
	_place_prop(VillageTiles.WELL, Vector2i(7, 10), 10)
	_place_prop(VillageTiles.SIGNPOST, Vector2i(9, 9), 11)
	# Ruins / forest south-east
	_place_prop(VillageTiles.STONE_RUIN_CORNER, Vector2i(19, 13), 11)
	_place_prop(VillageTiles.TREE_ROUND, Vector2i(18, 15), 12)
	_place_prop(VillageTiles.TREE_PINE, Vector2i(19, 15), 12)
	_place_prop(VillageTiles.MUSHROOM, Vector2i(17, 14), 13)
	_place_prop(VillageTiles.BUSH, Vector2i(16, 8), 13)

func _place_prop(tile_index: int, cell: Vector2i, feet_y: float = 14.0) -> void:
	var s := _make_atlas_sprite(tile_index)
	s.position = Vector2(cell) * 16 + Vector2(8, feet_y)
	s.z_index = int(feet_y)
	decor.add_child(s)

func _make_atlas_sprite(tile_index: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(TEX_PATH)
	s.region_enabled = true
	var ac := _tile_atlas(tile_index)
	s.region_rect = Rect2(ac.x * 16, ac.y * 16, 16, 16)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = true
	return s

func _refresh_buildings() -> void:
	for c in buildings_root.get_children():
		c.queue_free()
	for bid in GameState.buildings.keys():
		if GameState.buildings[bid]["built"]:
			_draw_building(bid, GameState.buildings[bid]["pos"])

func _draw_building(bid: String, origin: Vector2i) -> void:
	var parts: Array = VillageTiles.blueprint_for(bid)
	for part in parts:
		var cell: Vector2i = origin + part["atlas_offset"]
		var s := _make_atlas_sprite(part["index"])
		s.position = Vector2(cell) * 16 + Vector2(8, 13)
		s.z_index = 13
		buildings_root.add_child(s)

func _setup_ui() -> void:
	build_option.clear()
	for bid in GameState.BUILDING_DEFS.keys():
		var def: Dictionary = GameState.BUILDING_DEFS[bid]
		var cost_str := _cost_string(def["cost"])
		build_option.add_item("%s (%s)" % [def["label"], cost_str])
		build_option.set_item_metadata(build_option.item_count - 1, bid)
	villager_option.clear()
	for v in GameState.villagers:
		villager_option.add_item("%s — %s" % [v["name"], v["trait"]])
		villager_option.set_item_metadata(villager_option.item_count - 1, v["id"])
	if villager_option.item_count > 0:
		villager_option.select(0)
		_on_villager_selected(0)
	speed_btn.text = "Speed ×1"
	pause_btn.text = "Pause"

func _refresh_poi_options() -> void:
	poi_option.clear()
	for pid in GameState.pois.keys():
		var p: Dictionary = GameState.pois[pid]
		if p["discovered"]:
			poi_option.add_item(p["label"])
			poi_option.set_item_metadata(poi_option.item_count - 1, pid)
	offer_btn.visible = GameState.discoveries["river_marking"] and not GameState.discoveries["shrine_offering"]

func _on_resources() -> void:
	resource_label.text = "Wood %d   Food %d   Stone %d" % [
		int(GameState.resources["wood"]),
		int(GameState.resources["food"]),
		int(GameState.resources["stone"]),
	]

func _on_history(_entry: Dictionary) -> void:
	_refresh_history()

func _refresh_history() -> void:
	history_list.clear()
	for entry in GameState.history:
		history_list.add_item(entry["text"])

func _sync_villagers() -> void:
	for v in GameState.villagers:
		var id: String = v["id"]
		if not _villager_nodes.has(id):
			var node := _make_villager_node(v)
			villagers_root.add_child(node)
			_villager_nodes[id] = node
		var n: Node2D = _villager_nodes[id]
		var feet: Vector2 = v["pos"] * 16 + Vector2(8, 13)
		var bob := sin(Time.get_ticks_msec() * 0.006 + hash(id)) * 1.0
		n.position = feet + Vector2(0, bob)
		n.z_index = 14
		if GameState.selected_villager_id == id:
			n.modulate = Color(1.15, 1.12, 1.0)
		else:
			n.modulate = Color.WHITE
	_update_activity_label()

func _make_villager_node(v: Dictionary) -> Node2D:
	var root := Node2D.new()
	var body := _make_atlas_sprite(v["sprite"])
	body.position = Vector2.ZERO
	root.add_child(body)
	var label := Label.new()
	label.text = v["name"]
	label.position = Vector2(-10, -18)
	label.add_theme_font_size_override("font_size", 7)
	root.add_child(label)
	return root

func _update_activity_label() -> void:
	if GameState.selected_villager_id == "":
		activity_label.text = "Select a villager to send exploring."
		return
	var v: Dictionary = GameState.get_villager(GameState.selected_villager_id)
	if v.is_empty():
		return
	activity_label.text = "%s — %s" % [v["name"], v["activity"]]

func _show_toast(msg: String) -> void:
	toast_label.text = msg
	_toast_timer = 4.0

func _process(delta: float) -> void:
	_sync_villagers()
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			toast_label.text = ""

func _cost_string(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in cost.keys():
		parts.append("%d %s" % [cost[k], k])
	return ", ".join(parts)

func _on_build_selected(idx: int) -> void:
	GameState.selected_building = build_option.get_item_metadata(idx)

func _on_villager_selected(idx: int) -> void:
	GameState.select_villager(villager_option.get_item_metadata(idx))
	_update_activity_label()

func _on_build_pressed() -> void:
	var bid: String = GameState.selected_building
	if bid == "workshop" and GameState.buildings["workshop"]["built"] and not GameState.workshop_upgrade:
		GameState.try_workshop_upgrade()
	else:
		GameState.try_build(bid)

func _on_explore_pressed() -> void:
	if poi_option.item_count == 0:
		return
	var pid = poi_option.get_item_metadata(poi_option.get_selected())
	GameState.send_expedition(pid)

func _on_offer_pressed() -> void:
	GameState.try_shrine_offering()
	_refresh_poi_options()

func _on_speed_pressed() -> void:
	var cur: float = GameState.sim_speed
	var next := 1.0
	if cur < 1.5:
		next = 2.0
	elif cur < 2.5:
		next = 3.0
	else:
		next = 1.0
	GameState.set_speed(next)
	speed_btn.text = "Speed ×%d" % int(next)

func _on_pause_pressed() -> void:
	GameState.toggle_pause()
	pause_btn.text = "Resume" if GameState.paused else "Pause"
