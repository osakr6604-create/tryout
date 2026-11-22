class_name Leaderboard
extends RefCounted
## The scores, as plain data: add, rank, filter by day, save to text, load back.
## It never touches the disk itself (app/board.gd does that), which keeps it
## easy to test and impossible to corrupt from a half-written file.

const VERSION := 1
const MAX_ENTRIES := 5000     ## far more than a booth sees in a weekend

enum Scope { TODAY, ALL }

var entries: Array[Dictionary] = []
var next_id: int = 1


## Adds a finished run and returns its entry (with its id filled in).
func add(tag: String, score: int, grade: String, role: String, attrs: Array, unix_time: int, day: String) -> Dictionary:
	var entry := {
		"id": next_id,
		"tag": tag,
		"score": score,
		"grade": grade,
		"role": role,
		"attrs": attrs.duplicate(),
		"ts": unix_time,
		"day": day,
	}
	next_id += 1
	entries.append(entry)
	if entries.size() > MAX_ENTRIES:
		_trim()
	return entry


## Highest score first. On a tie the earlier run stays ahead, so a score has
## to be beaten, not matched, to take a place.
func ranked(scope: Scope, day: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in entries:
		if scope == Scope.ALL or str(e["day"]) == day:
			out.append(e)
	out.sort_custom(_before)
	return out


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["score"]) != int(b["score"]):
		return int(a["score"]) > int(b["score"])
	if int(a["ts"]) != int(b["ts"]):
		return int(a["ts"]) < int(b["ts"])
	return int(a["id"]) < int(b["id"])


func top(count: int, scope: Scope, day: String = "") -> Array[Dictionary]:
	var all := ranked(scope, day)
	if all.size() > count:
		all.resize(count)
	return all


## 1-based place of an entry, or 0 when it is not in that scope.
func rank_of(entry_id: int, scope: Scope, day: String = "") -> int:
	var all := ranked(scope, day)
	for i in all.size():
		if int(all[i]["id"]) == entry_id:
			return i + 1
	return 0


## The place a score would take without adding it.
func rank_for_score(score: int, scope: Scope, day: String = "") -> int:
	var place := 1
	for e in entries:
		if (scope == Scope.ALL or str(e["day"]) == day) and int(e["score"]) >= score:
			place += 1
	return place


func count(scope: Scope, day: String = "") -> int:
	if scope == Scope.ALL:
		return entries.size()
	var n := 0
	for e in entries:
		if str(e["day"]) == day:
			n += 1
	return n


func best_score(scope: Scope, day: String = "") -> int:
	var best := 0
	for e in entries:
		if scope == Scope.ALL or str(e["day"]) == day:
			best = maxi(best, int(e["score"]))
	return best


func clear_day(day: String) -> int:
	var kept: Array[Dictionary] = []
	for e in entries:
		if str(e["day"]) != day:
			kept.append(e)
	var removed := entries.size() - kept.size()
	entries = kept
	return removed


func clear_all() -> void:
	entries.clear()


func remove(entry_id: int) -> bool:
	for i in entries.size():
		if int(entries[i]["id"]) == entry_id:
			entries.remove_at(i)
			return true
	return false


## Drops the lowest scores once the list passes MAX_ENTRIES.
func _trim() -> void:
	var all := ranked(Scope.ALL)
	all.resize(MAX_ENTRIES)
	entries = all


func to_text() -> String:
	return JSON.stringify({"version": VERSION, "next_id": next_id, "entries": entries}, "\t")


## Loads from saved text. Returns false and leaves the board empty when the
## text is not a board, so a damaged file can never take the game down.
func from_text(text: String) -> bool:
	entries.clear()
	next_id = 1
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = json.data
	if typeof(data.get("entries")) != TYPE_ARRAY:
		return false
	var highest := 0
	for raw: Variant in data["entries"]:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = raw
		if not (e.has("tag") and e.has("score")):
			continue
		# JSON numbers come back as floats; put the whole numbers back.
		var attrs: Array = []
		if typeof(e.get("attrs")) == TYPE_ARRAY:
			for v: Variant in e["attrs"]:
				attrs.append(int(v))
		var entry := {
			"id": int(e.get("id", 0)),
			"tag": str(e["tag"]),
			"score": clampi(int(e["score"]), 0, 10000),
			"grade": str(e.get("grade", "")),
			"role": str(e.get("role", "")),
			"attrs": attrs,
			"ts": int(e.get("ts", 0)),
			"day": str(e.get("day", "")),
		}
		if int(entry["id"]) <= 0:
			entry["id"] = highest + 1
		highest = maxi(highest, int(entry["id"]))
		entries.append(entry)
	next_id = maxi(int(data.get("next_id", 1)), highest + 1)
	return true


## Spreadsheet export for the events team (prize draws, daily winners).
func to_csv() -> String:
	var lines: PackedStringArray = ["rank,tag,score,grade,role,reflex,precision,tracking,timing,discipline,awareness,day,time_utc"]
	var all := ranked(Scope.ALL)
	for i in all.size():
		var e := all[i]
		var attrs: Array = e["attrs"]
		var cols: PackedStringArray = [str(i + 1), _csv(str(e["tag"])), str(e["score"]), str(e["grade"]), str(e["role"])]
		for k in 6:
			cols.append(str(attrs[k]) if k < attrs.size() else "")
		cols.append(str(e["day"]))
		cols.append(Time.get_datetime_string_from_unix_time(int(e["ts"])))
		lines.append(",".join(cols))
	return "\n".join(lines) + "\n"


static func _csv(value: String) -> String:
	# A tag that starts like a formula must not run when the sheet is opened.
	var safe := value
	if safe.begins_with("=") or safe.begins_with("+") or safe.begins_with("-") or safe.begins_with("@"):
		safe = "'" + safe
	if safe.contains(",") or safe.contains("\"") or safe.contains("\n"):
		safe = "\"" + safe.replace("\"", "\"\"") + "\""
	return safe


## Local calendar day for a UTC timestamp, as YYYY-MM-DD.
static func day_key(unix_time: int, utc_offset_minutes: int) -> String:
	return Time.get_date_string_from_unix_time(unix_time + utc_offset_minutes * 60)
