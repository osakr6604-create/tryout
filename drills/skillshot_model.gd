class_name SkillshotModel
extends DrillModel
## SKILLSHOT: your shots take time to travel, so aim where the runner will be.
## Four runners, one at a time, on a fixed schedule. The last two change
## direction once, like a player dodging.

const BAND_TOP := 120.0

var caster: Vector2 = Vector2.ZERO
var shots: Array[Dictionary] = []    ## {pos, vel}
var runner: Dictionary = {}          ## {pos, vel, born, juke_at, juked} while one is out
var index: int = -1
var hits: int = 0
var fired: int = 0
var escaped: int = 0
var cool_until: float = 0.0

var _speeds: Array = []


func _setup() -> void:
	id = &"skillshot"
	title = "SKILLSHOT"
	hint = "Lead the runner. Shots take time."
	duration = Tuning.SKILL_SECONDS
	caster = Vector2(field.get_center().x, field.end.y - 70.0)
	shots.clear()
	runner = {}
	index = -1
	hits = 0
	fired = 0
	escaped = 0
	cool_until = 0.0
	_speeds = Tuning.SKILL_SPEEDS.duplicate()


func _spawn_runner() -> void:
	index += 1
	var dir := 1.0 if rng.randf() < 0.5 else -1.0
	var speed := float(_speeds[index])
	var y := rng.randf_range(field.position.y + BAND_TOP, field.position.y + field.size.y * 0.48)
	var offset := 170.0 + rng.randf_range(0.0, 280.0)
	var x := field.position.x + offset if dir > 0.0 else field.end.x - offset
	# The third and fourth runners turn around part way through.
	var juke_at := -1.0
	if index >= 2:
		juke_at = t + Tuning.SKILL_LIFE * rng.randf_range(0.42, 0.6)
	runner = {
		"pos": Vector2(x, y),
		"vel": Vector2(speed * dir, 0.0),
		"born": t,
		"juke_at": juke_at,
		"juked": false,
	}
	emit(&"spawn", {"pos": runner["pos"], "dir": dir})


func cooldown_left() -> float:
	return maxf(0.0, cool_until - t)


func _advance(dt: float) -> void:
	var next := index + 1
	if runner.is_empty() and next < Tuning.SKILL_RUNNERS and t >= float(Tuning.SKILL_STARTS[next]):
		_spawn_runner()

	if not runner.is_empty():
		if float(runner["juke_at"]) > 0.0 and not runner["juked"] and t >= float(runner["juke_at"]):
			runner["juked"] = true
			runner["vel"] = -(runner["vel"] as Vector2)
			emit(&"juke", {"pos": runner["pos"]})
		runner["pos"] = (runner["pos"] as Vector2) + (runner["vel"] as Vector2) * dt
		if t >= float(runner["born"]) + Tuning.SKILL_LIFE:
			escaped += 1
			emit(&"escaped", {"pos": runner["pos"]})
			runner = {}

	# Move the shots in small steps so a fast shot cannot skip over a runner.
	var reach := Tuning.SKILL_TARGET_RADIUS + Tuning.SKILL_SHOT_RADIUS
	var bounds := field.grow(120.0)
	var i := shots.size() - 1
	while i >= 0:
		var s := shots[i]
		var steps := maxi(1, int(ceil(Tuning.SKILL_SHOT_SPEED * dt / 12.0)))
		var step_dt := dt / float(steps)
		var gone := false
		for k in steps:
			s["pos"] = (s["pos"] as Vector2) + (s["vel"] as Vector2) * step_dt
			if not runner.is_empty() and (s["pos"] as Vector2).distance_to(runner["pos"]) <= reach:
				hits += 1
				emit(&"hit", {"pos": runner["pos"], "count": hits})
				runner = {}
				gone = true
				break
		if gone or not bounds.has_point(s["pos"]):
			shots.remove_at(i)
		i -= 1


func _press(pos: Vector2) -> void:
	if t < cool_until:
		return
	var dir := pos - caster
	if dir.y > -20.0 or dir.length() < 1.0:
		return   # shots only go up the field
	dir = dir.normalized()
	fired += 1
	cool_until = t + Tuning.SKILL_COOLDOWN
	shots.append({"pos": caster, "vel": dir * Tuning.SKILL_SHOT_SPEED})
	emit(&"shot", {"pos": caster, "dir": dir})


func live_stat() -> String:
	return "%d / %d HIT" % [hits, Tuning.SKILL_RUNNERS]


func result() -> DrillResult:
	var headline := "%d of %d runners, %d shots" % [hits, Tuning.SKILL_RUNNERS, fired]
	return DrillResult.make(id, title, Tuning.skillshot_score(hits, fired), headline, {
		"hits": hits,
		"fired": fired,
		"escaped": escaped,
	})
