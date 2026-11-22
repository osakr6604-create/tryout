class_name LastHitModel
extends DrillModel
## LAST HIT: four lanes, each with a health bar that drains on its own. Click a
## lane while its bar is in the gold zone to take the last hit. Click too early
## and your attack is locked for a moment. Let it reach zero and it is gone.

enum { PENDING, ALIVE, KILLED, LOST }

const LANE_GAP := 36.0
const LANE_INSET_Y := 40.0

var minions: Array[Dictionary] = []  ## {lane, spawn, drain, hp, state}
var hits: int = 0
var early: int = 0
var lost: int = 0
var lock_until: float = 0.0


func _setup() -> void:
	id = &"lasthit"
	title = "LAST HIT"
	hint = "Click a bar when it turns gold"
	duration = Tuning.LASTHIT_SECONDS
	hits = 0
	early = 0
	lost = 0
	lock_until = 0.0
	minions.clear()

	var drains := shuffled(Tuning.LASTHIT_DRAINS)
	var lane_free: Array[float] = []
	for l in Tuning.LASTHIT_LANES:
		lane_free.append(0.0)
	var lead := 1.0 - Tuning.LASTHIT_KILL_ZONE
	for i in Tuning.LASTHIT_TOTAL:
		var zone := float(Tuning.LASTHIT_ZONE_STARTS[i]) + rng.randf_range(-0.08, 0.08)
		# Early bars must not need to start before the drill does.
		var drain := minf(float(drains[i]), (zone - 0.1) / lead)
		var spawn := zone - lead * drain
		var free: Array[int] = []
		for l in Tuning.LASTHIT_LANES:
			if lane_free[l] + 0.2 <= spawn:
				free.append(l)
		var lane := 0
		if free.is_empty():
			# Should not happen with four lanes; take whichever frees first.
			for l in Tuning.LASTHIT_LANES:
				if lane_free[l] < lane_free[lane]:
					lane = l
			spawn = lane_free[lane] + 0.2
		else:
			lane = free[rng.randi_range(0, free.size() - 1)]
		lane_free[lane] = spawn + drain
		minions.append({"lane": lane, "spawn": spawn, "drain": drain, "hp": 1.0, "state": PENDING})


func lane_rect(lane: int) -> Rect2:
	var n := Tuning.LASTHIT_LANES
	var w := (field.size.x - LANE_GAP * float(n + 1)) / float(n)
	var x := field.position.x + LANE_GAP + float(lane) * (w + LANE_GAP)
	return Rect2(x, field.position.y + LANE_INSET_Y, w, field.size.y - LANE_INSET_Y * 2.0)


func lane_at(pos: Vector2) -> int:
	for l in Tuning.LASTHIT_LANES:
		if lane_rect(l).has_point(pos):
			return l
	return -1


## The live bar in a lane, or an empty dictionary.
func in_lane(lane: int) -> Dictionary:
	for m in minions:
		if m["lane"] == lane and m["state"] == ALIVE:
			return m
	return {}


func is_locked() -> bool:
	return t < lock_until


func _advance(_dt: float) -> void:
	for m in minions:
		if m["state"] == PENDING and t >= float(m["spawn"]):
			m["state"] = ALIVE
			emit(&"spawn", {"lane": m["lane"]})
		if m["state"] == ALIVE:
			m["hp"] = 1.0 - (t - float(m["spawn"])) / float(m["drain"])
			if float(m["hp"]) <= 0.0:
				m["hp"] = 0.0
				m["state"] = LOST
				lost += 1
				emit(&"lost", {"lane": m["lane"]})


func _press(pos: Vector2) -> void:
	var lane := lane_at(pos)
	if lane < 0:
		return
	if is_locked():
		emit(&"locked", {"lane": lane})
		return
	var m := in_lane(lane)
	if m.is_empty():
		lock_until = t + Tuning.LASTHIT_EARLY_LOCK * 0.6
		emit(&"whiff", {"lane": lane})
	elif float(m["hp"]) <= Tuning.LASTHIT_KILL_ZONE:
		m["state"] = KILLED
		hits += 1
		emit(&"hit", {"lane": lane, "count": hits})
	else:
		early += 1
		lock_until = t + Tuning.LASTHIT_EARLY_LOCK
		emit(&"early", {"lane": lane})


func live_stat() -> String:
	return "%d / %d LAST HITS" % [hits, Tuning.LASTHIT_TOTAL]


func result() -> DrillResult:
	var headline := "%d of %d last hits" % [hits, Tuning.LASTHIT_TOTAL]
	if early > 0:
		headline += ", %d early" % early
	return DrillResult.make(id, title, Tuning.lasthit_score(hits, early), headline, {
		"hits": hits,
		"early": early,
		"lost": lost,
	})
