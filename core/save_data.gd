class_name SaveData
extends RefCounted

const CURRENT_VERSION: int = 1

var version: int = CURRENT_VERSION
var best_score: int = 0
var unlocked_levels: Array[int] = [1]
var completed_levels: Array[int] = []
var level_best_scores: Array[int] = [0, 0, 0]
var player_name: String = "Игрок"
var music_volume: float = 1.0
var is_fullscreen: bool = false
var is_music_on: bool = true

func to_dict() -> Dictionary:
	return {
		"version": version,
		"bestScore": best_score,
		"unlockedLevels": unlocked_levels.duplicate(),
		"completedLevels": completed_levels.duplicate(),
		"levelBestScores": level_best_scores.duplicate(),
		"playerName": player_name,
		"musicVolume": snappedf(music_volume, 0.01),
		"isFullscreen": is_fullscreen,
		"isMusicOn": is_music_on
	}

static func from_dict(raw: Variant) -> SaveData:
	var data := SaveData.new()
	if not (raw is Dictionary):
		return data
	var dict := raw as Dictionary

	if dict.has("version") and (dict["version"] is int or dict["version"] is float):
		data.version = int(dict["version"])
	if dict.has("bestScore") and (dict["bestScore"] is int or dict["bestScore"] is float):
		data.best_score = maxi(0, int(dict["bestScore"]))

	if dict.has("unlockedLevels") and dict["unlockedLevels"] is Array:
		var loaded_unlocked: Array[int] = []
		for item in dict["unlockedLevels"]:
			if item is int or item is float:
				var lvl := int(item)
				if lvl >= 1 and not loaded_unlocked.has(lvl):
					loaded_unlocked.append(lvl)
		if not loaded_unlocked.has(1):
			loaded_unlocked.append(1)
		loaded_unlocked.sort()
		data.unlocked_levels = loaded_unlocked

	if dict.has("completedLevels") and dict["completedLevels"] is Array:
		var loaded_completed: Array[int] = []
		for item in dict["completedLevels"]:
			if item is int or item is float:
				var lvl := int(item)
				if lvl >= 1 and not loaded_completed.has(lvl):
					loaded_completed.append(lvl)
		loaded_completed.sort()
		data.completed_levels = loaded_completed

	if dict.has("levelBestScores") and dict["levelBestScores"] is Array:
		var scores: Array[int] = []
		for item in dict["levelBestScores"]:
			if item is int or item is float:
				scores.append(maxi(0, int(item)))
			else:
				scores.append(0)
		while scores.size() < 3:
			scores.append(0)
		data.level_best_scores = scores

	if dict.has("playerName") and dict["playerName"] is String:
		var clean := (dict["playerName"] as String).strip_edges()
		if clean != "":
			data.player_name = clean

	if dict.has("musicVolume") and (dict["musicVolume"] is int or dict["musicVolume"] is float):
		data.music_volume = clampf(float(dict["musicVolume"]), 0.0, 1.0)
	if dict.has("isFullscreen") and dict["isFullscreen"] is bool:
		data.is_fullscreen = bool(dict["isFullscreen"])
	if dict.has("isMusicOn") and dict["isMusicOn"] is bool:
		data.is_music_on = bool(dict["isMusicOn"])

	return data

func is_level_unlocked(level_id: int) -> bool:
	return level_id == 1 or unlocked_levels.has(level_id)

func is_level_completed(level_id: int) -> bool:
	return completed_levels.has(level_id)

func get_level_best_score(level_id: int) -> int:
	var idx := level_id - 1
	if idx >= 0 and idx < level_best_scores.size():
		return level_best_scores[idx]
	return 0

func record_level_complete(level_id: int, run_score: int, total_levels: int = 3) -> void:
	if not unlocked_levels.has(level_id):
		unlocked_levels.append(level_id)
	if not completed_levels.has(level_id):
		completed_levels.append(level_id)
	if level_id < total_levels and not unlocked_levels.has(level_id + 1):
		unlocked_levels.append(level_id + 1)
	unlocked_levels.sort()
	completed_levels.sort()

	var idx := level_id - 1
	while level_best_scores.size() <= idx:
		level_best_scores.append(0)
	if idx >= 0 and run_score > level_best_scores[idx]:
		level_best_scores[idx] = run_score
	if run_score > best_score:
		best_score = run_score
