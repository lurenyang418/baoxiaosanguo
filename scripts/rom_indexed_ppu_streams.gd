extends Control

const MANIFEST_PATH := "res://assets/rom_reference/rom_bank22_indexed_ppu_streams.json"


func _ready() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if typeof(manifest) != TYPE_DICTIONARY:
		push_error("Could not read indexed PPU stream manifest")
		return
	var items: VBoxContainer = $Scroll/Items
	for entry: Dictionary in manifest["records"]:
		var label := Label.new()
		label.custom_minimum_size = Vector2(256, 18)
		label.text = "Record %02d · PRG %d $%s -> PPU %s · %d bytes" % [
			entry["record_index"],
			entry["starting_prg_bank"],
			entry["source_pointer_cpu"].trim_prefix("$"),
			entry["ppu_start_address"],
			entry["payload_bytes"],
		]
		items.add_child(label)

		var texture_rect := TextureRect.new()
		var texture_path: String = "res://assets/rom_reference/" + str(entry["files"][1])
		var preview: Texture2D = load(texture_path)
		if preview == null:
			push_error("Could not load indexed PPU preview: " + texture_path)
			continue
		texture_rect.texture = preview
		texture_rect.custom_minimum_size = Vector2(256, preview.get_height() * 0.5)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
		texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		items.add_child(texture_rect)
