class_name TrackModel
extends DrillModel
## TRACK: keep the pointer on a target that wanders and speeds up.
## No clicking. The score is the share of time spent on target.

const MARGIN := 150.0

var pos: Vector2 = Vector2.ZERO
var heading: float = 0.0
var on_target: bool = false
var on_time: float = 0.0
var counted: float = 0.0
var longest: float = 0.0

var _want_heading: float = 0.0
var _turn_in: float = 0.0
var _run: float = 0.0


func _setup() -> void:
	id = &"track"
	title = "TRACK"
	hint = "Stay on the target"
	duration = Tuning.TRACK_SECONDS
	pos = field.get_center()
	heading = rng.randf() * TAU
	_want_heading = heading
	_turn_in = 0.5
	on_target = false
	on_time = 0.0
	counted = 0.0
	longest = 0.0
	_run = 0.0


func _advance(dt: float) -> void:
	var speed := lerpf(Tuning.TRACK_SPEED_START, Tuning.TRACK_SPEED_END, progress())
	_turn_in -= dt
	if _turn_in <= 0.0:
		_turn_in = rng.randf_range(0.45, 0.95)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		_want_heading = heading + rng.randf_range(0.9, 2.4) * side
	heading = lerp_angle(heading, _want_heading, clampf(dt * 5.0, 0.0, 1.0))
	pos += Vector2.from_angle(heading) * speed * dt

	# Bounce off the edges of the play area.
	var area := inner(MARGIN)
	if pos.x < area.position.x or pos.x > area.end.x:
		pos.x = clampf(pos.x, area.position.x, area.end.x)
		heading = PI - heading
		_want_heading = heading
	if pos.y < area.position.y or pos.y > area.end.y:
		pos.y = clampf(pos.y, area.position.y, area.end.y)
		heading = -heading
		_want_heading = heading

	var was := on_target
	on_target = pointer.distance_to(pos) <= Tuning.TRACK_RADIUS
	if t >= Tuning.TRACK_GRACE:
		counted += dt
		if on_target:
			on_time += dt
			_run += dt
			longest = maxf(longest, _run)
		else:
			_run = 0.0
	if on_target != was:
		emit(&"lock" if on_target else &"slip", {"pos": pos})


func fraction() -> float:
	return on_time / counted if counted > 0.0 else 0.0


func live_stat() -> String:
	return "%d%% ON TARGET" % int(round(fraction() * 100.0))


func result() -> DrillResult:
	var headline := "%d%% on target" % int(round(fraction() * 100.0))
	return DrillResult.make(id, title, Tuning.track_score(fraction()), headline, {
		"fraction": fraction(),
		"longest": longest,
	})
