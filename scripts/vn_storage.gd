extends RefCounted

const SLOTS := ["1", "2", "3", "quick", "resume"]
var directory := "user://"
var preferences := {"speed": 30.0, "delay": 1.6, "volume": 1.0}

func slot_path(slot: String) -> String:
	if slot == "1":
		return directory.path_join("vn-slot.json")
	return directory.path_join("vn-%s.json" % slot)

func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) == OK and parser.data is Dictionary:
		return parser.data
	return {}

func write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var err := file.get_error()
	file.close()
	return err == OK and DirAccess.rename_absolute(path + ".tmp", path) == OK

func read_slot(slot: String) -> Dictionary:
	return read_json(slot_path(slot)) if slot in SLOTS else {}

func write_slot(slot: String, state: Dictionary) -> bool:
	return slot in SLOTS and not state.is_empty() and write_json(slot_path(slot), state)

func configure(key: String, value: float) -> bool:
	if not preferences.has(key) or not is_finite(value):
		return false
	var limits: Array = {"speed": [0, 100], "delay": [0.2, 5.0], "volume": [0, 1]}[key]
	preferences[key] = clampf(value, limits[0], limits[1])
	if key == "volume":
		AudioServer.set_bus_mute(0, preferences.volume <= 0)
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(preferences.volume, 0.0001)))
	return true

func load_settings() -> void:
	var saved := read_json(directory.path_join("vn-settings.json"))
	for key in preferences:
		var value = saved.get(key, preferences[key])
		if value is float or value is int:
			configure(key, value)

func save_settings() -> bool:
	return write_json(directory.path_join("vn-settings.json"), preferences)
