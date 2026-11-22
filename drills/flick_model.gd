class_name FlickModel
extends DrillModel
## FLICK: one target at a time. Hit it and the next appears a set distance away.
## Distances come from a shuffled bag, so every player travels the same total
## distance over a run of the same length.

const MARGIN := 110.0

var target: Vector2 = Vector2.ZERO
var born: float = 0.0
var hits: int = 0
var misses: int = 0
var streak: int = 0
var best_streak: int = 0
var hit_times: Array[float] = []

var _bag: Array = []


func _setup() -> void:
	id = &"flick"
	title = "FLICK"
	hint = "Click every target"
	duration = Tuning.FLICK_SECONDS
	hits = 0
	misses = 0
	streak = 0
	best_streak = 0
	hit_times.clear()
	_bag.clear()
	target = field.get_center()
	born = 0.0
	emit(&"spawn", {"pos": target})


func _press(pos: Vector2) -> void:
	if pos.distance_to(target) <= Tuning.FLICK_RADIUS:
		hits += 1
		streak += 1
		best_streak = maxi(best_streak, streak)
		hit_times.append(t - born)
		emit(&"hit", {"pos": target, "ms": int(round((t - born) * 1000.0)), "streak": streak})
		_spawn()
	else:
		misses += 1
		streak = 0
		emit(&"miss", {"pos": pos})


func _spawn() -> void:
	if _bag.is_empty():
		_bag = shuffled(Tuning.FLICK_DISTANCES)
	var want: float = _bag.pop_back()
	var area := inner(MARGIN)
	var next := Vector2.INF
	for i in 32:
		var cand := target + Vector2.from_angle(rng.randf() * TAU) * want
		if area.has_point(cand):
			next = cand
			break
	if next == Vector2.INF:
		next = rand_point_away(target, 300.0, MARGIN)
	target = next
	born = t
	emit(&"spawn", {"pos": target})


func accuracy() -> float:
	var shots := hits + misses
	return float(hits) / float(shots) if shots > 0 else 0.0


func average_ms() -> int:
	if hit_times.is_empty():
		return 0
	var sum := 0.0
	for v in hit_times:
		sum += v
	return int(round(sum / hit_times.size() * 1000.0))


func live_stat() -> String:
	return "%d HITS" % hits


func result() -> DrillResult:
	var headline := "%d hits, %d%% accuracy" % [hits, int(round(accuracy() * 100.0))]
	return DrillResult.make(id, title, Tuning.flick_score(hits, misses), headline, {
		"hits": hits,
		"misses": misses,
		"accuracy": accuracy(),
		"avg_ms": average_ms(),
		"best_streak": best_streak,
	})
