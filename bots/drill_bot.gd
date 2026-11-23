class_name DrillBot
extends RefCounted
## A stand-in player. It plays any drill at a chosen skill level by doing what
## a person does: it needs time to notice things, it moves the pointer along a
## smooth path that takes longer for far or small targets, and it is a little
## off, more so at low skill.
##
## The game uses it for the demo reel on the attract screen. The tests use it
## to check that better play always scores higher, and the soak test uses it
## to run hundreds of sessions back to back.

var model: DrillModel
var skill: float = 0.7          ## 0 = first time holding a mouse, 1 = pro
var rng: RandomNumberGenerator
var cursor: Vector2 = Vector2.ZERO
var presses: int = 0

## Normally the bot tells the drill directly where the pointer is and when it
## clicks. Set these two and it hands both to the caller instead, which lets
## the game turn them into real mouse events and so test the same path a
## person's mouse takes.
var move_through: Callable = Callable()
var press_through: Callable = Callable()

# One planned move: where from, where to, when it starts and when it lands.
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _start: float = 0.0
var _land: float = 0.0
var _press_at: float = 0.0
var _has_move: bool = false
var _press_on_land: bool = false

# Per-drill memory.
var _seen: int = -1
var _retry_at: float = -1.0
var _noise: Vector2 = Vector2.ZERO
var _noise_goal: Vector2 = Vector2.ZERO
var _noise_in: float = 0.0
var _react_at: float = -1.0
var _false_start_at: float = -1.0
var _trial_seen: int = -1
var _thresholds: Dictionary = {}
var _memory: Array[int] = []
var _memory_done: bool = false
var _pick_at: float = -1.0
var _pick_queue: Array[int] = []
var _hold_decided: int = -1


static func create(p_model: DrillModel, p_skill: float, p_seed: int) -> DrillBot:
	var bot := DrillBot.new()
	bot.model = p_model
	bot.skill = clampf(p_skill, 0.0, 1.0)
	bot.rng = RandomNumberGenerator.new()
	bot.rng.seed = p_seed
	bot.cursor = p_model.field.get_center()
	return bot


## Call once per frame, before the model advances.
func step(dt: float) -> void:
	if model.done:
		return
	match model.id:
		&"flick":
			_flick()
		&"track":
			_track(dt)
		&"react":
			_react()
		&"holdfire":
			_holdfire()
		&"lasthit":
			_lasthit()
		&"skillshot":
			_skillshot()
		&"mapcheck":
			_mapcheck()
		&"clutch":
			_clutch()
	_motion()
	if move_through.is_valid():
		move_through.call(cursor)
	else:
		model.move(cursor)


func _click() -> void:
	presses += 1
	if press_through.is_valid():
		press_through.call(cursor)
	else:
		model.move(cursor)
		model.press(cursor)


# ---- how a person moves ----

## Simple reaction time: seeing one expected thing and clicking.
func reaction() -> float:
	return lerpf(0.36, 0.17, skill) * rng.randf_range(0.9, 1.16)


## Choice reaction: first deciding what the thing is.
func decision() -> float:
	return lerpf(0.5, 0.26, skill) * rng.randf_range(0.9, 1.15)


## Fitts's law: far and small takes longer.
func travel_time(distance: float, width: float) -> float:
	var a := lerpf(0.13, 0.05, skill)
	var b := lerpf(0.2, 0.085, skill)
	return a + b * (log(distance / maxf(width, 1.0) + 1.0) / log(2.0))


## How far off the click lands, scaled to the target.
func wobble(radius: float) -> Vector2:
	var spread := radius * lerpf(0.82, 0.2, skill)
	var angle := rng.randf() * TAU
	# Sum of two rolls: mostly near the middle, sometimes wide.
	var amount := (rng.randf() + rng.randf()) * 0.5 * spread * 1.6
	return Vector2.from_angle(angle) * amount


## Plans a move that starts after [param delay]. With [param press], it clicks
## on arrival, but never sooner than [param not_before] seconds from now: the
## hand can already be travelling while the head is still deciding.
func _plan(to: Vector2, delay: float, width: float, press: bool, not_before: float = 0.0) -> void:
	_from = cursor
	_to = to
	_start = model.t + delay
	_land = _start + travel_time(cursor.distance_to(to), width)
	_press_at = maxf(_land, model.t + not_before)
	_has_move = true
	_press_on_land = press


func _busy() -> bool:
	return _has_move


func _motion() -> void:
	if not _has_move:
		return
	if model.t < _start:
		return
	var span := maxf(_land - _start, 0.001)
	var k := clampf((model.t - _start) / span, 0.0, 1.0)
	# Minimum-jerk profile: slow out, fast middle, slow in, like a real hand.
	var eased := k * k * k * (10.0 + k * (-15.0 + 6.0 * k))
	cursor = _from.lerp(_to, eased)
	if k >= 1.0 and model.t >= _press_at:
		_has_move = false
		if _press_on_land and _still_worth_clicking():
			_click()


## The thing the click was meant for may have gone by the time the hand lands.
## A sharp player holds the click; a rattled one fires anyway.
func _still_worth_clicking() -> bool:
	var gone := false
	match model.id:
		&"holdfire":
			var m := model as HoldFireModel
			gone = m.current != _hold_decided or m.live().is_empty()
		&"clutch":
			gone = (model as ClutchModel).visible_foe().is_empty()
	if not gone:
		return true
	return rng.randf() < (1.0 - skill) * 0.5


# ---- one routine per drill ----

func _flick() -> void:
	var m := model as FlickModel
	if m.hits != _seen:
		_seen = m.hits
		_retry_at = -1.0
		_plan(m.target + wobble(Tuning.FLICK_RADIUS), reaction() * 0.75, Tuning.FLICK_RADIUS * 2.0, true)
	elif not _busy():
		# The click missed and the target is still there: correct and try again.
		if _retry_at < 0.0:
			_retry_at = m.t + lerpf(0.22, 0.1, skill)
		elif m.t >= _retry_at:
			_retry_at = -1.0
			_plan(m.target + wobble(Tuning.FLICK_RADIUS) * 0.5, 0.0, Tuning.FLICK_RADIUS * 2.0, true)


func _track(dt: float) -> void:
	var m := model as TrackModel
	_noise_in -= dt
	if _noise_in <= 0.0:
		_noise_in = rng.randf_range(0.2, 0.45)
		_noise_goal = Vector2.from_angle(rng.randf() * TAU) * rng.randf() * lerpf(90.0, 12.0, skill)
	_noise = _noise.lerp(_noise_goal, clampf(dt * 6.0, 0.0, 1.0))
	if m.t < reaction():
		return
	var lag := lerpf(0.19, 0.04, skill)
	cursor = cursor.lerp(m.pos + _noise, 1.0 - exp(-dt / lag))


func _react() -> void:
	var m := model as ReactModel
	if m.trial != _trial_seen:
		_trial_seen = m.trial
		_react_at = -1.0
		_false_start_at = -1.0
		# Now and then a jumpy player goes early.
		if rng.randf() < (1.0 - skill) * 0.1:
			_false_start_at = rng.randf_range(0.35, 0.8)
	match m.phase:
		ReactModel.Phase.WAIT:
			if _false_start_at > 0.0 and m.phase_t >= _false_start_at:
				_false_start_at = -1.0
				_click()
		ReactModel.Phase.GO:
			if _react_at < 0.0:
				_react_at = reaction()
			if m.phase_t >= _react_at:
				_react_at = 99.0
				_click()


func _holdfire() -> void:
	var m := model as HoldFireModel
	if m.current == _hold_decided or m.live().is_empty():
		return
	_hold_decided = m.current
	var s := m.live()
	var shoot: bool = s["enemy"]
	if not shoot and rng.randf() < lerpf(0.3, 0.01, skill):
		shoot = true   # trigger happy
	# The hand heads for the shape straight away; the click waits for the decision.
	_plan((s["pos"] as Vector2) + wobble(Tuning.HOLD_RADIUS) * 0.6, reaction() * 0.5, Tuning.HOLD_RADIUS * 2.0, shoot, decision())


func _lasthit() -> void:
	var m := model as LastHitModel
	# Watch the bar closest to its gold zone.
	var pick: Dictionary = {}
	for minion in m.minions:
		if minion["state"] != LastHitModel.ALIVE:
			continue
		if pick.is_empty() or float(minion["hp"]) < float(pick["hp"]):
			pick = minion
	if pick.is_empty():
		return
	var key := int(pick["lane"]) * 1000 + int(round(float(pick["spawn"]) * 100.0))
	if not _thresholds.has(key):
		_thresholds[key] = {
			# How long after the bar turns gold the click comes.
			"latency": lerpf(0.4, 0.1, skill) * rng.randf_range(0.7, 1.4),
			# A nervous player sometimes goes before it turns.
			"early": rng.randf() < (1.0 - skill) * 0.25,
		}
	var plan: Dictionary = _thresholds[key]
	if m.lane_at(cursor) != int(pick["lane"]):
		if not _busy():
			_plan(m.lane_rect(int(pick["lane"])).get_center() + wobble(60.0), 0.0, 220.0, false)
		return
	if _busy() or m.is_locked():
		return
	var hp := float(pick["hp"])
	var gold_for := (Tuning.LASTHIT_KILL_ZONE - hp) * float(pick["drain"])
	if plan["early"] and hp <= Tuning.LASTHIT_KILL_ZONE + 0.1 and hp > Tuning.LASTHIT_KILL_ZONE:
		plan["early"] = false
		_click()
	elif gold_for >= float(plan["latency"]):
		_click()
		_thresholds.erase(key)


func _skillshot() -> void:
	var m := model as SkillshotModel
	if m.runner.is_empty() or _busy() or m.cooldown_left() > 0.0:
		return
	if m.index != _seen:
		_seen = m.index
		_retry_at = m.t + reaction()
	if m.t < _retry_at:
		return
	var p: Vector2 = m.runner["pos"]
	var v: Vector2 = m.runner["vel"]
	# Where the runner will be when the hand gets there, then when the shot does.
	var hand := travel_time(cursor.distance_to(p), Tuning.SKILL_TARGET_RADIUS * 2.0)
	var at_fire := p + v * hand
	var flight := at_fire.distance_to(m.caster) / Tuning.SKILL_SHOT_SPEED
	var lead_error := rng.randf_range(-1.0, 1.0) * lerpf(0.75, 0.05, skill)
	var aim := at_fire + v * flight * (1.0 + lead_error)
	aim.y = minf(aim.y, m.caster.y - 60.0)
	_plan(aim + wobble(Tuning.SKILL_TARGET_RADIUS) * 0.5, 0.0, Tuning.SKILL_TARGET_RADIUS * 2.0, true)
	_retry_at = m.t + Tuning.SKILL_COOLDOWN + lerpf(0.2, 0.05, skill)


func _mapcheck() -> void:
	var m := model as MapCheckModel
	if m.phase == MapCheckModel.Phase.SHOW:
		# Each ping sticks with a chance that grows with skill.
		for cell in m.lit_cells():
			if not _memory.has(cell) and not _pick_queue.has(-cell - 1):
				if rng.randf() < lerpf(0.38, 0.985, skill):
					_memory.append(cell)
				else:
					_pick_queue.append(-cell - 1)   # seen, but forgotten
		return
	if m.phase != MapCheckModel.Phase.RECALL:
		return
	if not _memory_done:
		_memory_done = true
		_pick_queue.clear()
		for cell in _memory:
			_pick_queue.append(cell)
		# Fill the gaps with guesses.
		var all: Array[int] = []
		for i in Tuning.MAP_GRID * Tuning.MAP_GRID:
			if not _memory.has(i):
				all.append(i)
		while _pick_queue.size() < Tuning.MAP_PINGS and not all.is_empty():
			var guess := all[rng.randi_range(0, all.size() - 1)]
			all.erase(guess)
			_pick_queue.append(guess)
		_pick_at = m.t + reaction()
	if _busy() or _pick_queue.is_empty() or m.t < _pick_at:
		return
	var cell: int = _pick_queue.pop_front()
	var center := m.cell_rect(cell).get_center()
	_plan(center + wobble(30.0), 0.0, 110.0, true)
	_pick_at = m.t + lerpf(0.72, 0.36, skill)


func _clutch() -> void:
	var m := model as ClutchModel
	var foe := m.visible_foe()
	if foe.is_empty() or m.bullets <= 0:
		return
	var key := int(round(float(foe["start"]) * 1000.0))
	if key != _seen:
		_seen = key
		_retry_at = -1.0
		_plan((foe["pos"] as Vector2) + wobble(Tuning.CLUTCH_RADIUS), reaction(), Tuning.CLUTCH_RADIUS * 2.0, true)
	elif not _busy():
		if _retry_at < 0.0:
			_retry_at = m.t + lerpf(0.24, 0.12, skill)
		elif m.t >= _retry_at:
			_retry_at = -1.0
			_plan((foe["pos"] as Vector2) + wobble(Tuning.CLUTCH_RADIUS) * 0.5, 0.0, Tuning.CLUTCH_RADIUS * 2.0, true)
