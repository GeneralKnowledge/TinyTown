extends Node

var _templates: Array = []

func _ready() -> void:
	_templates = [
		{"id": "chat_path", "needs": [], "text": "%s and %s shared stories on the path.", "fx": "relationship"},
		{"id": "garden_bloom", "needs": ["garden"], "text": "The garden burst into bloom — extra food for all.", "fx": "food"},
		{"id": "lumber_song", "needs": ["lumber_camp"], "text": "Axes rhythm at the lumber camp; spirits lift.", "fx": "wood"},
		{"id": "well_gossip", "needs": [], "text": "%s heard rumors of the old shrine by the river.", "fx": "hint_shrine"},
		{"id": "finn_watches", "needs": [], "text": "%s spotted smoke beyond the trees.", "fx": "reveal_forest"},
		{"id": "pella_bakes", "needs": [], "text": "%s baked honey cakes — everyone smiles.", "fx": "food"},
		{"id": "toma_mends", "needs": [], "text": "%s patched a fence before dawn.", "fx": "wood"},
		{"id": "elden_reads", "needs": [], "text": "%s copied a spiral symbol into a journal.", "fx": "hint_symbol"},
		{"id": "mira_mushroom", "needs": [], "text": "%s found bright mushrooms near the pines.", "fx": "food"},
		{"id": "river_glitter", "needs": [], "text": "Sunlight on the river revealed a hidden stepping stone.", "fx": "stone"},
		{"id": "ruins_dream", "needs": [], "text": "%s dreamed of towers buried under ivy.", "fx": "reveal_ruins"},
		{"id": "watchtower_spark", "needs": ["watchtower"], "text": "A lantern at the watchtower guided a safe return.", "fx": "morale"},
		{"id": "workshop_clang", "needs": ["workshop"], "text": "The workshop echoed with purposeful hammering.", "fx": "stone"},
		{"id": "hut_warmth", "needs": ["hut"], "text": "Warm lamplight from the new hut softened the night.", "fx": "morale"},
		{"id": "bell_echo", "needs": [], "text": "A faint bell echo rolled down from the hills.", "fx": "hint_shrine"},
	]

func try_random_event() -> void:
	if GameState.villagers.is_empty():
		return
	var options: Array = []
	for t in _templates:
		if _meets_needs(t):
			options.append(t)
	if options.is_empty():
		return
	if randf() > 0.42:
		return
	var pick: Dictionary = options[randi() % options.size()]
	_fire_template(pick)

func _meets_needs(t: Dictionary) -> bool:
	for need in t.get("needs", []):
		if not GameState.buildings.get(need, {}).get("built", false):
			return false
	return true

func _fire_template(t: Dictionary) -> void:
	var a: Dictionary = GameState.villagers[randi() % GameState.villagers.size()]
	var b: Dictionary = GameState.villagers[randi() % GameState.villagers.size()]
	var text: String = t["text"]
	if text.find("%s") != -1:
		text = text % [a["name"], b["name"]]
	match t["fx"]:
		"relationship":
			a["relationships"][b["id"]] = clampf(a["relationships"].get(b["id"], 0.3) + 0.08, 0.0, 1.0)
		"food":
			GameState.resources["food"] += 2
		"wood":
			GameState.resources["wood"] += 2
		"stone":
			GameState.resources["stone"] += 1
		"hint_shrine":
			pass
		"reveal_forest":
			GameState.reveal_forest()
		"reveal_ruins":
			GameState.reveal_ruins()
		"hint_symbol":
			if GameState.discoveries["silver_bell"]:
				GameState.discoveries["bell_symbol_known"] = true
		"morale":
			pass
	GameState.resources_changed.emit()
	GameState.add_history(text, "event")

func run_chain_event(event_id: String, villager_id: String) -> void:
	var v: Dictionary = GameState.get_villager(villager_id)
	match event_id:
		"bell_found":
			var elden: Dictionary = GameState.get_villager("elden")
			if not elden.is_empty():
				GameState.discoveries["bell_symbol_known"] = true
				elden["personal_history"].append("Recognised the bell's spiral symbol.")
				GameState.add_history("Elden whispered: 'That spiral belongs to the river stones.'", "mystery")
				GameState._bump_relationship("elden", "mira", 0.1)
		"river_marking":
			GameState.add_history("The spiral links shrine and river — what offering will answer?", "mystery")
			if not v.is_empty():
				v["activity"] = "Pondering the mystery"
