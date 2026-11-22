class_name DrillModel
extends RefCounted
## The rules of one drill, with no nodes, no rendering and no clock of its own.
##
## Whoever owns the model feeds it time with advance() and input with move()
## and press(). The game's view does that from real frames and real clicks;
## the tests and the demo bot do it from a loop. Because of that split, a full
## run can be simulated thousands of times a second, which is how the scoring
## and the long-session soak test are checked.

var id: StringName = &"drill"
var title: String = "DRILL"
var hint: String = ""
var duration: float = 6.0
var field: Rect2 = Rect2(0, 0, 1920, 1080)
var rng: RandomNumberGenerator
var t: float = 0.0
var done: bool = false
var pointer: Vector2 = Vector2.ZERO

var _events: Array[Dictionary] = []
var _finished: bool = false


func setup(p_rng: RandomNumberGenerator, p_field: Rect2) -> void:
	rng = p_rng
	field = p_field
	pointer = field.get_center()
	t = 0.0
	done = false
	_finished = false
	_events.clear()
	_setup()


func advance(dt: float) -> void:
	if done:
		return
	t += dt
	_advance(dt)
	if not done and t >= duration:
		done = true
	if done and not _finished:
		_finished = true
		_finish()
		emit(&"done")


func move(pos: Vector2) -> void:
	pointer = pos
	if not done:
		_move(pos)


func press(pos: Vector2) -> void:
	pointer = pos
	if not done:
		_press(pos)


func time_left() -> float:
	return maxf(0.0, duration - t)


func progress() -> float:
	return clampf(t / maxf(duration, 0.001), 0.0, 1.0)


## Queues something that happened, for the view to turn into sound and effects.
func emit(type: StringName, data: Dictionary = {}) -> void:
	data["type"] = type
	_events.append(data)


## Hands over everything queued since the last call.
func take_events() -> Array[Dictionary]:
	var out := _events
	_events = []
	return out


func result() -> DrillResult:
	return DrillResult.make(id, title, 0.0, "")


## A short readout for the HUD while the drill runs.
func live_stat() -> String:
	return ""


# ---- helpers shared by the drills ----

func inner(margin: float) -> Rect2:
	return field.grow(-margin)


func rand_point(margin: float) -> Vector2:
	var r := inner(margin)
	return Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))


## A random point at least [param min_dist] from [param from]. Falls back to the
## farthest candidate it saw, so it always returns something usable.
func rand_point_away(from: Vector2, min_dist: float, margin: float) -> Vector2:
	var best := rand_point(margin)
	var best_d := best.distance_to(from)
	for i in 24:
		if best_d >= min_dist:
			break
		var cand := rand_point(margin)
		var d := cand.distance_to(from)
		if d > best_d:
			best = cand
			best_d = d
	return best


## Fisher-Yates with the drill's own generator, so a seed replays exactly.
func shuffled(items: Array) -> Array:
	var out := items.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


# ---- for subclasses ----

func _setup() -> void:
	pass


func _advance(_dt: float) -> void:
	pass


func _move(_pos: Vector2) -> void:
	pass


func _press(_pos: Vector2) -> void:
	pass


func _finish() -> void:
	pass
