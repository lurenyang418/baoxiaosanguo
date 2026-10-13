extends RefCounted

## ROM-backed campaign types and accumulated experience, independent of battle HP.
var records: Dictionary = {}
var seed: Array = []
var types: Array[int] = []
var experience: Array[int] = []

func ensure_loaded() -> void:
	if not records.is_empty(): return
	var file := FileAccess.open("res://data/rom_progression.json", FileAccess.READ)
	if file != null:
		var value: Variant = JSON.parse_string(file.get_as_text())
		if value is Dictionary:
			for row in value.get("records", []): records[int(row["unit_type_id"])] = row
	file = FileAccess.open("res://data/rom_campaign_roster_seed.json", FileAccess.READ)
	if file != null:
		var value: Variant = JSON.parse_string(file.get_as_text())
		if value is Dictionary: seed = value.get("entries", [])
	reset()

func reset() -> void:
	types.clear()
	experience.clear()
	for row in seed:
		types.append(int(row["unit_type_id"]))
		experience.append(int(row.get("experience", row.get("unknown_value_16bit", 0))))

func seed_snapshot() -> Dictionary:
	ensure_loaded()
	var initial_types := []
	var initial_xp := []
	for row in seed:
		initial_types.append(int(row["unit_type_id"]))
		initial_xp.append(int(row.get("experience", row.get("unknown_value_16bit", 0))))
	return {"types": initial_types, "experience": initial_xp}

func snapshot() -> Dictionary:
	ensure_loaded()
	return {"types": Array(types), "experience": Array(experience)}

func reachable_type(roster: int, target: int) -> bool:
	ensure_loaded()
	if roster < 0 or roster >= seed.size() or not records.has(target): return false
	var queue: Array[int] = [int(seed[roster]["unit_type_id"])]
	var seen := {}
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if current == target: return true
		if seen.has(current): continue
		seen[current] = true
		for next in records.get(current, {}).get("promotion_choices", []): queue.append(int(next))
	return false

func valid_snapshot(value: Variant) -> bool:
	ensure_loaded()
	if not value is Dictionary: return false
	var saved_types: Variant = value.get("types")
	var saved_xp: Variant = value.get("experience")
	if not saved_types is Array or not saved_xp is Array or saved_types.size() != seed.size() or saved_xp.size() != seed.size(): return false
	for index in seed.size():
		for field in [saved_types[index], saved_xp[index]]:
			if not (typeof(field) in [TYPE_INT, TYPE_FLOAT]) or float(field) != float(int(field)): return false
		if not reachable_type(index, int(saved_types[index])) or int(saved_xp[index]) < 0 or int(saved_xp[index]) > 65535: return false
	return true

func restore(value: Dictionary) -> bool:
	if not valid_snapshot(value): return false
	types.assign(value["types"])
	experience.assign(value["experience"])
	return true
