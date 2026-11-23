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

# The screens ask for the top of the board every frame. Sorting thousands of
# scores that often would cost frames late in a busy day, so the sorted lists
# are kept and only rebuilt when the board changes or the day rolls over.
var _sorted_ok: bool = false
var _sorted_day: String = ""
var _sorted_today: Array[Dictionary] = []
var _sorted_all: Array[Dictionary] = []
var _day_text: String = ""
var _day_checked_ms: int = -100000


func _ready() -> void:
	load_board()


func now() -> int:
	return int(Time.get_unix_time_from_system())


## The local calendar day. Looked up at most once a second.
func today() -> String:
	var ticks := Time.get_ticks_msec()
	if _day_text == "" or ticks - _day_checked_ms > 1000:
		_day_checked_ms = ticks
		var bias := int(Time.get_time_zone_from_system().get("bias", 0))
		_day_text = Leaderboard.day_key(now(), bias)
	return _day_text


## Call after changing [member data] directly, so the screens pick it up.
func touch() -> void:
	_sorted_ok = false


func _sort() -> void:
	var day := today()
	if _sorted_ok and day == _sorted_day:
		return
	_sorted_day = day
	_sorted_today = data.ranked(Leaderboard.Scope.TODAY, day)
	_sorted_all = data.ranked(Leaderboard.Scope.ALL)
	_sorted_ok = true


static func _head(list: Array[Dictionary], count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in mini(count, list.size()):
		out.append(list[i])
	return out


## Records a finished run and returns its entry.
func submit(tag: String, session: Session) -> Dictionary:
	last_entry = data.add(tag, session.total(), session.grade(), session.role(), session.attribute_list(), now(), today())
	touch()
	save()
	changed.emit()
	return last_entry


func rank_today(entry_id: int) -> int:
	_sort()
	for i in _sorted_today.size():
		if int(_sorted_today[i]["id"]) == entry_id:
			return i + 1
	return 0


func top_today(count: int) -> Array[Dictionary]:
	_sort()
	return _head(_sorted_today, count)


func top_all(count: int) -> Array[Dictionary]:
	_sort()
	return _head(_sorted_all, count)


func count_today() -> int:
	_sort()
	return _sorted_today.size()


func best_today() -> int:
	_sort()
	return int(_sorted_today[0]["score"]) if not _sorted_today.is_empty() else 0


func set_live(status: Dictionary) -> void:
	live = status
	live_changed.emit()


func reset_today() -> int:
	var removed := data.clear_day(today())
	touch()
	save()
	changed.emit()
	return removed


func reset_all() -> void:
	data.clear_all()
	touch()
	save()
	changed.emit()


func load_board() -> void:
	touch()
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
