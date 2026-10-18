extends Node

const VillageTiles = preload("res://scripts/tiles.gd")

signal resources_changed
signal buildings_changed
signal villagers_changed
signal history_added(entry: Dictionary)
signal toast(message: String)
signal expedition_finished(villager_id: String, result: Dictionary)
signal discovery_updated

const SAVE_PATH := "user://little_worlds_save.json"
const MAP_W := 22
const MAP_H := 18
const TILE_PX := 16

enum Terrain { GRASS, GRASS_ALT, PATH, WATER, BLOCKED }

var sim_speed := 1.0
var paused := false

var resources := {"wood": 18, "food": 22, "stone": 10}
var production := {"wood": 0.35, "food": 0.45, "stone": 0.08}
var food_upkeep := 0.04

var buildings := {
	"hut": {"built": false, "pos": Vector2i(9, 8)},
	"lumber_camp": {"built": false, "pos": Vector2i(5, 6)},
	"garden": {"built": false, "pos": Vector2i(11, 9)},
	"workshop": {"built": false, "pos": Vector2i(8, 11)},
	"watchtower": {"built": false, "pos": Vector2i(14, 5)},
}

const BUILDING_DEFS := {
	"hut": {"label": "Hut", "cost": {"wood": 8, "food": 5}, "desc": "More comfortable homes (+food upkeep efficiency)."},
	"lumber_camp": {"label": "Lumber Camp", "cost": {"wood": 6, "stone": 2}, "desc": "Boosts wood gathering."},
	"garden": {"label": "Garden", "cost": {"wood": 5, "food": 3}, "desc": "Steady food from plots."},
	"workshop": {"label": "Workshop", "cost": {"wood": 10, "stone": 8}, "desc": "Unlocks village tools upgrade."},
	"watchtower": {"label": "Watchtower", "cost": {"wood": 15, "stone": 10}, "desc": "Better forest expeditions."},
}

var workshop_upgrade := false

var pois := {
	"shrine": {"label": "Abandoned Shrine", "pos": Vector2i(18, 4), "discovered": true},
	"forest": {"label": "Whispering Forest", "pos": Vector2i(10, 2), "discovered": false},
	"river": {"label": "River Stones", "pos": Vector2i(2, 10), "discovered": true},
	"ruins": {"label": "Old Ruins", "pos": Vector2i(19, 14), "discovered": false},
}

var discoveries := {
	"silver_bell": false,
	"bell_symbol_known": false,
	"river_marking": false,
	"shrine_offering": false,
}

var unique_loot_given := {}

var history: Array = []
var map_grid: Array = []

var villagers: Array = []
var selected_villager_id := ""
var selected_building := "hut"

var _sim_accum := 0.0
var _event_cooldown := 8.0

func _ready() -> void:
	_init_map()
	_init_villagers()
	load_game()
	recalculate_production()
	add_history("The little village wakes beneath an amber sky.", "intro")

func _process(delta: float) -> void:
	if paused:
		return
	var dt: float = delta * sim_speed
	_sim_accum += dt
	while _sim_accum >= 0.25:
		_sim_accum -= 0.25
		_sim_tick(0.25)
	_event_cooldown -= dt
	if _event_cooldown <= 0.0:
		Events.try_random_event()
		_event_cooldown = randf_range(18.0, 32.0)

func _sim_tick(dt: float) -> void:
	for key in resources.keys():
		var gain: float = float(production.get(key, 0.0)) * dt
		if key == "food":
			gain -= food_upkeep * villagers.size() * dt
		resources[key] = maxf(0.0, resources[key] + gain)
	resources_changed.emit()
	_update_villagers(dt)
	_try_autosave()

func _init_map() -> void:
	map_grid.clear()
	for y in MAP_H:
		var row: Array = []
		for x in MAP_W:
			row.append(Terrain.GRASS)
		map_grid.append(row)
	for x in MAP_W:
		map_grid[0][x] = Terrain.GRASS_ALT
		map_grid[MAP_H - 1][x] = Terrain.GRASS_ALT
	for y in MAP_H:
		map_grid[y][0] = Terrain.GRASS_ALT
		map_grid[y][MAP_W - 1] = Terrain.GRASS_ALT
	# River on the west
	for y in range(6, 14):
		for x in range(1, 4):
			map_grid[y][x] = Terrain.WATER
	# Paths
	for x in range(4, 18):
		map_grid[9][x] = Terrain.PATH
	for y in range(4, 15):
		map_grid[y][10] = Terrain.PATH
	# Forest band (blocked trees placed as decor; keep grass walkable at edges)
	for x in range(6, 16):
		map_grid[3][x] = Terrain.GRASS_ALT

func _stamp_blocked(origin: Vector2i, size: Vector2i) -> void:
	for dy in size.y:
		for dx in size.x:
			var p := origin + Vector2i(dx, dy)
			if _in_map(p):
				map_grid[p.y][p.x] = Terrain.BLOCKED

func _init_villagers() -> void:
	villagers = [
		_make_villager("mira", "Mira", "Curious", VillageTiles.CHAR_MIRA, Vector2(9.5, 10.2)),
		_make_villager("elden", "Elden", "Wise", VillageTiles.CHAR_ELDEN, Vector2(7.2, 9.5)),
		_make_villager("toma", "Toma", "Hardworking", VillageTiles.CHAR_TOMA, Vector2(11.0, 11.0)),
		_make_villager("pella", "Pella", "Cheerful", VillageTiles.CHAR_PELLA, Vector2(8.0, 12.0)),
		_make_villager("finn", "Finn", "Cautious", VillageTiles.CHAR_FINN, Vector2(12.5, 8.5)),
	]

func _make_villager(id: String, display_name: String, personality: String, sprite: int, pos: Vector2) -> Dictionary:
	var rel := {}
	for v in ["mira", "elden", "toma", "pella", "finn"]:
		if v != id:
			rel[v] = randf_range(0.2, 0.55)
	return {
		"id": id,
		"name": display_name,
		"trait": personality,
		"sprite": sprite,
		"pos": pos,
		"target": pos,
		"activity": "Wandering",
		"state": "wander",
		"state_time": 0.0,
		"relationships": rel,
		"personal_history": ["Arrived at the founding fire."],
		"expedition": null,
	}

func recalculate_production() -> void:
	production = {"wood": 0.25, "food": 0.35, "stone": 0.05}
	if buildings["lumber_camp"]["built"]:
		production["wood"] += 0.45
	if buildings["garden"]["built"]:
		production["food"] += 0.55
	if buildings["watchtower"]["built"]:
		production["stone"] += 0.05
	if workshop_upgrade:
		production["wood"] += 0.15
		production["stone"] += 0.12
	if buildings["hut"]["built"]:
		food_upkeep = 0.032
	else:
		food_upkeep = 0.04

func can_afford(cost: Dictionary) -> bool:
	for k in cost.keys():
		if resources.get(k, 0.0) < cost[k]:
			return false
	return true

func spend(cost: Dictionary) -> void:
	for k in cost.keys():
		resources[k] -= cost[k]
	resources_changed.emit()

func try_build(building_id: String) -> bool:
	if buildings[building_id]["built"]:
		toast.emit("%s is already built." % BUILDING_DEFS[building_id]["label"])
		return false
	var cost: Dictionary = BUILDING_DEFS[building_id]["cost"]
	if not can_afford(cost):
		toast.emit("Not enough resources.")
		return false
	spend(cost)
	buildings[building_id]["built"] = true
	var pos: Vector2i = buildings[building_id]["pos"]
	if building_id in ["hut", "workshop", "lumber_camp", "garden", "watchtower"]:
		_stamp_blocked(pos, Vector2i(2, 2))
	recalculate_production()
	buildings_changed.emit()
	add_history("Built the %s." % BUILDING_DEFS[building_id]["label"], "build")
	toast.emit("%s completed!" % BUILDING_DEFS[building_id]["label"])
	return true

func try_workshop_upgrade() -> bool:
	if not buildings["workshop"]["built"] or workshop_upgrade:
		return false
	if not can_afford({"wood": 6, "stone": 4}):
		toast.emit("Need 6 wood and 4 stone for tools.")
		return false
	spend({"wood": 6, "stone": 4})
	workshop_upgrade = true
	recalculate_production()
	add_history("Village tools gleam — work goes faster.", "upgrade")
	toast.emit("Workshop upgrade installed.")
	return true

func select_villager(id: String) -> void:
	selected_villager_id = id
	villagers_changed.emit()

func get_villager(id: String) -> Dictionary:
	for v in villagers:
		if v["id"] == id:
			return v
	return {}

func send_expedition(poi_id: String) -> bool:
	if selected_villager_id == "":
		toast.emit("Select a villager first.")
		return false
	var v: Dictionary = get_villager(selected_villager_id)
	if v.is_empty() or v["expedition"] != null:
		toast.emit("That villager is already busy.")
		return false
	if not pois[poi_id]["discovered"]:
		toast.emit("That place is still hidden.")
		return false
	var travel: float = 22.0
	if buildings["watchtower"]["built"]:
		travel *= 0.75
	v["state"] = "explore"
	v["activity"] = "Expedition → %s" % pois[poi_id]["label"]
	v["expedition"] = {
		"poi": poi_id,
		"time_left": travel,
		"phase": "outbound",
		"target": Vector2(pois[poi_id]["pos"]) + Vector2(0.5, 0.5),
	}
	villagers_changed.emit()
	add_history("%s set out toward the %s." % [v["name"], pois[poi_id]["label"]], "explore")
	return true

func _update_villagers(dt: float) -> void:
	for v in villagers:
		if v["expedition"] != null:
			_update_expedition(v, dt)
			continue
		v["state_time"] -= dt
		if v["state_time"] <= 0.0:
			_pick_new_state(v)
		_apply_gathering(v, dt)
		_move_towards(v, v["target"], dt, 1.1)
	villagers_changed.emit()

func _apply_gathering(v: Dictionary, dt: float) -> void:
	var amt: float = 0.18 * dt * dt_scale_bonus()
	match v["state"]:
		"gather_wood":
			resources["wood"] += amt
		"gather_food":
			resources["food"] += amt
		"gather_stone":
			resources["stone"] += amt
		_:
			return
	resources_changed.emit()

func _pick_new_state(v: Dictionary) -> void:
	var roll: int = randi() % 100
	if roll < 20:
		v["state"] = "gather_wood"
		v["activity"] = "Gathering wood"
		v["target"] = _random_walkable_near(v["pos"], 6.0)
	elif roll < 38:
		v["state"] = "gather_food"
		v["activity"] = "Foraging food"
		v["target"] = _random_walkable_near(v["pos"], 5.0)
	elif roll < 48:
		v["state"] = "gather_stone"
		v["activity"] = "Collecting stone"
		v["target"] = _random_walkable_near(v["pos"], 5.0)
	elif roll < 58:
		v["state"] = "rest"
		v["activity"] = "Resting"
		v["target"] = _random_walkable_near(v["pos"], 3.0)
	else:
		v["state"] = "wander"
		v["activity"] = "Wandering"
		v["target"] = _random_walkable_near(v["pos"], 8.0)
	v["state_time"] = randf_range(4.0, 9.0)

func dt_scale_bonus() -> float:
	return 1.0 + (0.2 if workshop_upgrade else 0.0)

func _update_expedition(v: Dictionary, dt: float) -> void:
	var e: Dictionary = v["expedition"]
	e["time_left"] -= dt
	var dest: Vector2 = e["target"]
	if e["phase"] == "outbound":
		_move_towards(v, dest, dt, 1.35)
		if v["pos"].distance_to(dest) < 0.35 or e["time_left"] < 11.0:
			e["phase"] = "at_site"
			e["time_left"] = minf(e["time_left"], 8.0)
			v["activity"] = "Searching…"
	elif e["phase"] == "at_site":
		v["pos"] = dest
		if e["time_left"] <= 0.0:
			var result: Dictionary = _resolve_expedition(v, e["poi"])
			e["phase"] = "return"
			e["time_left"] = 16.0
			e["target"] = Vector2(9.5, 10.0)
			v["activity"] = "Returning home"
			expedition_finished.emit(v["id"], result)
	else:
		_move_towards(v, e["target"], dt, 1.25)
		if v["pos"].distance_to(e["target"]) < 0.4 or e["time_left"] <= 0.0:
			v["expedition"] = null
			v["state"] = "wander"
			v["activity"] = "Wandering"
			v["state_time"] = 2.0

func _resolve_expedition(v: Dictionary, poi_id: String) -> Dictionary:
	var outcome: Dictionary = {"type": "resources", "summary": ""}
	match poi_id:
		"shrine":
			if not discoveries["silver_bell"]:
				discoveries["silver_bell"] = true
				outcome = {"type": "discovery", "summary": "Silver bell found at the shrine."}
				add_history("%s found a silver bell, cold but ringing softly." % v["name"], "discovery")
				Events.run_chain_event("bell_found", v["id"])
			else:
				if discoveries["bell_symbol_known"] and not discoveries["shrine_offering"]:
					outcome = {"type": "followup", "summary": "Shrine ready for an offering."}
					add_history("The shrine waits for a humble offering.", "mystery")
				else:
					outcome = _resource_loot(v, "shrine")
		"forest":
			if not pois["forest"]["discovered"]:
				pois["forest"]["discovered"] = true
				discovery_updated.emit()
			if not unique_loot_given.get("forest_idol", false) and randf() < 0.55:
				unique_loot_given["forest_idol"] = true
				resources["food"] += 6
				outcome = {"type": "discovery", "summary": "Forest idol carved from rootwood."}
				add_history("%s discovered a tiny idol beneath the pines." % v["name"], "discovery")
			else:
				outcome = _resource_loot(v, "forest")
		"river":
			if discoveries["bell_symbol_known"] and not discoveries["river_marking"]:
				discoveries["river_marking"] = true
				outcome = {"type": "discovery", "summary": "Matching symbol by the river."}
				add_history("%s found the same spiral carved into river stone." % v["name"], "discovery")
				Events.run_chain_event("river_marking", v["id"])
			else:
				outcome = _resource_loot(v, "river")
		"ruins":
			if not pois["ruins"]["discovered"]:
				pois["ruins"]["discovered"] = true
				discovery_updated.emit()
			if not unique_loot_given.get("ruins_key", false):
				unique_loot_given["ruins_key"] = true
				resources["stone"] += 5
				outcome = {"type": "discovery", "summary": "Ancient key in the rubble."}
				add_history("%s recovered an ornate key from the ruins." % v["name"], "discovery")
			else:
				outcome = _resource_loot(v, "ruins")
		_:
			outcome = _resource_loot(v, poi_id)
	discovery_updated.emit()
	return outcome

func _resource_loot(v: Dictionary, _place: String) -> Dictionary:
	var bundle: Dictionary = {"wood": 2, "food": 2, "stone": 1}
	if buildings["watchtower"]["built"]:
		bundle["wood"] += 1
		bundle["stone"] += 1
	for k in bundle.keys():
		resources[k] += bundle[k]
	resources_changed.emit()
	var summary: String = "Returned with supplies."
	add_history("%s returned with wood, food, and stone." % v["name"], "explore")
	return {"type": "resources", "summary": summary}

func try_shrine_offering() -> bool:
	if not discoveries["silver_bell"] or not discoveries["river_marking"]:
		toast.emit("The mystery isn't ready yet.")
		return false
	if discoveries["shrine_offering"]:
		toast.emit("The shrine already accepted your gift.")
		return false
	if not can_afford({"food": 8}):
		toast.emit("Need 8 food for the offering.")
		return false
	spend({"food": 8})
	discoveries["shrine_offering"] = true
	for v in villagers:
		if v["id"] == "elden" or v["id"] == "mira":
			_bump_relationship(v["id"], "pella", 0.15)
	add_history("An offering at the shrine — the bell chimed and the village remembered its name: Little Worlds.", "mystery")
	toast.emit("The bell rings across the valley!")
	discovery_updated.emit()
	return true

func _bump_relationship(a: String, b: String, amount: float) -> void:
	var va: Dictionary = get_villager(a)
	if not va.is_empty():
		va["relationships"][b] = clampf(va["relationships"].get(b, 0.3) + amount, 0.0, 1.0)

func _move_towards(v: Dictionary, target: Vector2, dt: float, speed: float) -> void:
	var pos: Vector2 = v["pos"]
	var dir: Vector2 = target - pos
	if dir.length() < 0.05:
		return
	var step: Vector2 = dir.normalized() * speed * dt
	var next: Vector2 = pos + step
	if _is_walkable(next):
		v["pos"] = next
	else:
		var try_x: Vector2 = Vector2(next.x, pos.y)
		var try_y: Vector2 = Vector2(pos.x, next.y)
		if _is_walkable(try_x):
			v["pos"] = try_x
		elif _is_walkable(try_y):
			v["pos"] = try_y
		else:
			v["target"] = _random_walkable_near(pos, 4.0)

func _random_walkable_near(origin: Vector2, radius: float) -> Vector2:
	for _i in 24:
		var offset: Vector2 = Vector2(randf_range(-radius, radius), randf_range(-radius, radius))
		var p: Vector2 = origin + offset
		if _is_walkable(p):
			return p
	return origin

func _is_walkable(pos: Vector2) -> bool:
	if not _in_map(Vector2i(floori(pos.x), floori(pos.y))):
		return false
	var t: int = map_grid[pos.y][pos.x]
	return t == Terrain.GRASS or t == Terrain.GRASS_ALT or t == Terrain.PATH

func _in_map(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < MAP_W and p.y < MAP_H

func add_history(text: String, kind: String = "event") -> void:
	var entry: Dictionary = {"text": text, "kind": kind, "time": Time.get_unix_time_from_system()}
	history.push_front(entry)
	if history.size() > 40:
		history.resize(40)
	history_added.emit(entry)
	toast.emit(text)

func set_speed(s: float) -> void:
	sim_speed = s

func toggle_pause() -> void:
	paused = not paused

func reveal_forest() -> void:
	if not pois["forest"]["discovered"]:
		pois["forest"]["discovered"] = true
		discovery_updated.emit()

func reveal_ruins() -> void:
	if not pois["ruins"]["discovered"]:
		pois["ruins"]["discovered"] = true
		discovery_updated.emit()

func save_game() -> void:
	var data := {
		"resources": resources,
		"buildings": buildings,
		"villagers": villagers,
		"pois": pois,
		"discoveries": discoveries,
		"unique_loot_given": unique_loot_given,
		"history": history,
		"workshop_upgrade": workshop_upgrade,
		"selected_villager_id": selected_villager_id,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

var _autosave_timer := 0.0

func _try_autosave() -> void:
	_autosave_timer += 0.25
	if _autosave_timer >= 12.0:
		_autosave_timer = 0.0
		save_game()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	resources = parsed.get("resources", resources)
	buildings = parsed.get("buildings", buildings)
	villagers = parsed.get("villagers", villagers)
	pois = parsed.get("pois", pois)
	discoveries = parsed.get("discoveries", discoveries)
	unique_loot_given = parsed.get("unique_loot_given", unique_loot_given)
	history = parsed.get("history", history)
	workshop_upgrade = parsed.get("workshop_upgrade", false)
	selected_villager_id = parsed.get("selected_villager_id", "")
	for bid in buildings.keys():
		if buildings[bid]["built"]:
			_stamp_blocked(buildings[bid]["pos"], Vector2i(2, 2))
	recalculate_production()
	resources_changed.emit()
	buildings_changed.emit()
	villagers_changed.emit()
	discovery_updated.emit()
