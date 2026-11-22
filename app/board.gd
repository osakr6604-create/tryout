extends Node
## The saved leaderboard. Autoloaded as "Board".
##
## Everything stays on this machine: one small JSON file in the user folder,
## no network. Saves go through a temporary file and keep the previous copy,
## so pulling the plug mid-save cannot lose the board.

signal changed                       ## an entry was added or the board was cleared
signal live_changed                  ## the "now playing" status moved on

const PATH := "user://leaderboard.json"
const TEMP := "user://leaderboard.json.tmp"
const BACKUP := "user://leaderboard.json.bak"

var data: Leaderboard = Leaderboard.new()
var live: Dictionary = {}            ## what the second screen shows about the run in progress
var last_entry: Dictionary = {}


func _ready() -> void:
	load_board()


func now() -> int:
	return int(Time.get_unix_time_from_system())


func today() -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	return Leaderboard.day_key(now(), bias)


## Records a finished run and returns its entry.
func submit(tag: String, session: Session) -> Dictionary:
	last_entry = data.add(tag, session.total(), session.grade(), session.role(), session.attribute_list(), now(), today())
	save()
	changed.emit()
	return last_entry


func rank_today(entry_id: int) -> int:
	return data.rank_of(entry_id, Leaderboard.Scope.TODAY, today())


func top_today(count: int) -> Array[Dictionary]:
	return data.top(count, Leaderboard.Scope.TODAY, today())


func top_all(count: int) -> Array[Dictionary]:
	return data.top(count, Leaderboard.Scope.ALL)


func count_today() -> int:
	return data.count(Leaderboard.Scope.TODAY, today())


func set_live(status: Dictionary) -> void:
	live = status
	live_changed.emit()


func reset_today() -> int:
	var removed := data.clear_day(today())
	save()
	changed.emit()
	return removed


func reset_all() -> void:
	data.clear_all()
	save()
	changed.emit()


func load_board() -> void:
	for path: String in [PATH, BACKUP]:
		if not FileAccess.file_exists(path):
			continue
		var text := FileAccess.get_file_as_string(path)
		if data.from_text(text):
			return
		# Keep the unreadable file for a person to look at, and carry on.
		var aside := "user://leaderboard.unreadable-%d.json" % now()
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(aside))
		push_warning("Leaderboard file could not be read and was set aside: %s" % aside)
	data = Leaderboard.new()


func save() -> bool:
	var file := FileAccess.open(TEMP, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write the leaderboard (%s)." % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(data.to_text())
	file.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	if dir.file_exists("leaderboard.json"):
		if dir.file_exists("leaderboard.json.bak"):
			dir.remove("leaderboard.json.bak")
		dir.rename("leaderboard.json", "leaderboard.json.bak")
	return dir.rename("leaderboard.json.tmp", "leaderboard.json") == OK


## Writes the whole board as a spreadsheet file and returns where it went.
func export_csv() -> String:
	var folder := "user://exports"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "-")
	var path := "%s/tryout-scores-%s.csv" % [folder, stamp]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(data.to_csv())
	file.close()
	return ProjectSettings.globalize_path(path)
