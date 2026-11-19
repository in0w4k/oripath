class_name SaveSystem
extends RefCounted

const SAVE_PATH: String = "user://save.json"
const TMP_PATH: String = "user://save.tmp"
const BAK_PATH: String = "user://save.bak"
const LEGACY_SETTINGS_PATH: String = "user://settings.cfg"

static func get_absolute_save_path() -> String:
	return ProjectSettings.globalize_path(SAVE_PATH)

static func save(data: SaveData) -> bool:
	if not data:
		return false

	var json_text := JSON.stringify(data.to_dict(), "  ")
	var tmp_file := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if not tmp_file:
		push_warning("SaveSystem: failed to open temp save file")
		return false

	tmp_file.store_string(json_text)
	tmp_file.flush()
	tmp_file.close()

	var abs_tmp := ProjectSettings.globalize_path(TMP_PATH)
	var abs_save := ProjectSettings.globalize_path(SAVE_PATH)
	var abs_bak := ProjectSettings.globalize_path(BAK_PATH)

	if FileAccess.file_exists(BAK_PATH):
		DirAccess.remove_absolute(abs_bak)

	var had_prev := FileAccess.file_exists(SAVE_PATH)
	if had_prev:
		var bak_err := DirAccess.rename_absolute(abs_save, abs_bak)
		if bak_err != OK:
			DirAccess.remove_absolute(abs_save)
			had_prev = false

	var swap_err := DirAccess.rename_absolute(abs_tmp, abs_save)
	if swap_err != OK:
		if had_prev and FileAccess.file_exists(BAK_PATH):
			DirAccess.rename_absolute(abs_bak, abs_save)
		var direct := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if not direct:
			push_warning("SaveSystem: failed to finalize save.json")
			return false
		direct.store_string(json_text)
		direct.flush()
		direct.close()
		if FileAccess.file_exists(TMP_PATH):
			DirAccess.remove_absolute(abs_tmp)

	if FileAccess.file_exists(BAK_PATH):
		DirAccess.remove_absolute(abs_bak)
	return true

static func load_save() -> SaveData:
	if not FileAccess.file_exists(SAVE_PATH):
		return SaveData.new()

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_warning("SaveSystem: could not read save.json, falling back to defaults")
		return SaveData.new()

	var text := file.get_as_text().strip_edges()
	file.close()

	if text.is_empty():
		push_warning("SaveSystem: save.json is empty, falling back to defaults")
		return SaveData.new()

	var parser := JSON.new()
	var err := parser.parse(text)
	if err != OK or not (parser.data is Dictionary):
		push_warning("SaveSystem: corrupted save.json (%s), falling back to defaults" % parser.get_error_message())
		return SaveData.new()

	return SaveData.from_dict(parser.data)

static func delete_save() -> void:
	for path in [SAVE_PATH, TMP_PATH, BAK_PATH, LEGACY_SETTINGS_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
