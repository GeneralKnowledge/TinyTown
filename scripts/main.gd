extends Control

const VillageTiles = preload("res://scripts/tiles.gd")
const TEX_PATH := "res://assets/kenney/tiny-town/Tilemap/tilemap_packed.png"

@onready var world_root: Node2D = %WorldRoot
@onready var tilemap: TileMapLayer = %Ground
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
	_spawn_water()
	_spawn_decor()
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
					idx = VillageTiles.GRASS if (x + y) % 3 else VillageTiles.GRASS_FLOWERS
				GameState.Terrain.GRASS_ALT:
					idx = VillageTiles.GRASS_ALT
				GameState.Terrain.PATH:
					idx = VillageTiles.PATH
				GameState.Terrain.WATER:
					idx = VillageTiles.WATER
				GameState.Terrain.BLOCKED:
					idx = VillageTiles.STONE_FLOOR
			tilemap.set_cell(Vector2i(x, y), 0, _tile_atlas(idx))

func _spawn_water() -> void:
	for y in GameState.MAP_H:
		for x in GameState.MAP_W:
			if GameState.map_grid[y][x] == GameState.Terrain.WATER:
				var r := ColorRect.new()
				r.size = Vector2(16, 16)
				r.position = Vector2(x, y) * 16
				r.color = Color(0.22, 0.45, 0.82, 0.85)
				decor.add_child(r)

func _spawn_decor() -> void:
	for c in decor.get_children():
		c.queue_free()
	_place_sprite(VillageTiles.TREE, Vector2i(6, 2))
	_place_sprite(VillageTiles.TREE, Vector2i(8, 2))
	_place_sprite(VillageTiles.TREE, Vector2i(12, 2))
	_place_sprite(VillageTiles.TREE_ORANGE, Vector2i(14, 2))
	_place_sprite(VillageTiles.TREE, Vector2i(15, 3))
	_place_sprite(VillageTiles.BUSH, Vector2i(5, 4))
	_place_sprite(VillageTiles.BUSH, Vector2i(16, 8))
	_place_sprite(VillageTiles.SHRINE_STONE, Vector2i(18, 3))
	_place_sprite(VillageTiles.SHRINE_STONE, Vector2i(19, 4))
	_place_sprite(VillageTiles.WELL, Vector2i(7, 10))
	_place_sprite(VillageTiles.TREE, Vector2i(19, 13))
	_place_sprite(VillageTiles.TREE, Vector2i(18, 15))

func _place_sprite(tile_index: int, cell: Vector2i) -> void:
	var s := Sprite2D.new()
	s.texture = load(TEX_PATH)
	s.region_enabled = true
	var ac := _tile_atlas(tile_index)
	s.region_rect = Rect2(ac.x * 16, ac.y * 16, 16, 16)
	s.position = Vector2(cell) * 16 + Vector2(8, 8)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decor.add_child(s)

func _refresh_buildings() -> void:
	for c in buildings_root.get_children():
		c.queue_free()
	for bid in GameState.buildings.keys():
		if GameState.buildings[bid]["built"]:
			_draw_building(bid, GameState.buildings[bid]["pos"])

func _draw_building(bid: String, origin: Vector2i) -> void:
	var parts: Array = []
	match bid:
		"hut":
			parts = [VillageTiles.HOUSE_WOOD_A, VillageTiles.HOUSE_WOOD_B, VillageTiles.HOUSE_ROOF]
		"lumber_camp":
			parts = [VillageTiles.FENCE, VillageTiles.FENCE, VillageTiles.TREE]
		"garden":
			parts = [VillageTiles.BUSH, VillageTiles.BUSH, VillageTiles.GRASS_FLOWERS]
		"workshop":
			parts = [VillageTiles.HOUSE_WOOD_B, VillageTiles.HOUSE_WOOD_A, VillageTiles.HOUSE_ROOF]
		"watchtower":
			parts = [VillageTiles.TOWER_STONE, VillageTiles.TOWER_STONE, VillageTiles.HOUSE_ROOF]
	var offsets := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, -1)]
	for i in parts.size():
		var cell: Vector2i = origin + offsets[i]
		_place_sprite(parts[i], cell)

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
		n.position = v["pos"] * 16
		var bob := sin(Time.get_ticks_msec() * 0.006 + hash(id)) * 1.5
		n.position.y += bob
		if GameState.selected_villager_id == id:
			n.modulate = Color(1.2, 1.2, 1.0)
		else:
			n.modulate = Color.WHITE
	_update_activity_label()

func _make_villager_node(v: Dictionary) -> Node2D:
	var root := Node2D.new()
	var body := Sprite2D.new()
	body.texture = load(TEX_PATH)
	body.region_enabled = true
	var ac := _tile_atlas(v["sprite"])
	body.region_rect = Rect2(ac.x * 16, ac.y * 16, 16, 16)
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.position = Vector2(8, 10)
	root.add_child(body)
	var label := Label.new()
	label.text = v["name"]
	label.position = Vector2(-4, -6)
	label.add_theme_font_size_override("font_size", 7)
	root.add_child(label)
	var ring := ColorRect.new()
	ring.size = Vector2(14, 14)
	ring.position = Vector2(1, 6)
	ring.color = Color(1, 1, 1, 0)
	root.add_child(ring)
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
