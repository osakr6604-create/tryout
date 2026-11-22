class_name Tuning
extends RefCounted
## Every number that shapes pacing, difficulty or scoring lives in this file,
## so the whole balance of a tryout can be read (and tested) in one place.

## The run, in order. Everyone gets the same eight drills in the same order,
## which keeps the leaderboard fair. What changes per run is the seed.
const DRILL_ORDER: Array[StringName] = [
	&"flick", &"track", &"react", &"holdfire",
	&"lasthit", &"skillshot", &"mapcheck", &"clutch",
]

## The play area inside the 1920 x 1080 frame. The band above it is the HUD.
const FIELD := Rect2(110.0, 160.0, 1700.0, 820.0)

# ---- Flow timing (seconds) ----
const BRIEFING_SECONDS := 3.2      ## "8 drills, 60 seconds" plus the 3-2-1
const CARD_SECONDS := 1.25         ## the one-word command before each drill
const FLASH_SECONDS := 0.9         ## the result stamp after each drill
const TAG_SECONDS := 20.0          ## time allowed to type a tag
const REPORT_HOLD_SECONDS := 22.0  ## the report stays up this long, then resets
const IDLE_ABORT_SECONDS := 12.0   ## no input mid-run for this long: abandon it

# ---- Flick ----
const FLICK_SECONDS := 6.0
const FLICK_RADIUS := 44.0
const FLICK_DISTANCES: Array[float] = [360.0, 500.0, 640.0, 780.0]
const FLICK_HITS_ZERO := 3.0       ## this many hits or fewer scores 0
const FLICK_HITS_FULL := 15.0      ## this many hits scores 100 (at 100% accuracy)

# ---- Track ----
const TRACK_SECONDS := 6.0
const TRACK_RADIUS := 62.0
const TRACK_GRACE := 0.55          ## time to find the target before it counts
const TRACK_SPEED_START := 360.0
const TRACK_SPEED_END := 640.0
const TRACK_FRAC_ZERO := 0.12
const TRACK_FRAC_FULL := 0.85

# ---- React ----
const REACT_TRIALS := 3
const REACT_DELAYS: Array[float] = [0.95, 1.5, 2.1]
const REACT_DELAY_JITTER := 0.22
const REACT_TIMEOUT := 0.9
const REACT_SHOW := 0.5
const REACT_MS_FULL := 165.0       ## this fast scores 100
const REACT_MS_ZERO := 430.0       ## this slow scores 0

# ---- Hold fire ----
const HOLD_COUNT := 8
const HOLD_ENEMIES := 5
const HOLD_RADIUS := 66.0
const HOLD_LIFE_START := 0.9       ## how long the first enemy stays up
const HOLD_LIFE_END := 0.62        ## and the last one
const HOLD_ALLY_LIFE := 0.62       ## teammates leave sooner, so holding does not drag
const HOLD_GAP := 0.12
const HOLD_RT_FAST := 0.38
const HOLD_RT_SLOW := 0.72
const HOLD_FRIENDLY_PENALTY := 30.0
const HOLD_WHIFF_PENALTY := 3.0

# ---- Last hit ----
const LASTHIT_SECONDS := 6.2
const LASTHIT_LANES := 4
const LASTHIT_TOTAL := 7
const LASTHIT_KILL_ZONE := 0.22    ## the bar turns gold below this share of HP
const LASTHIT_ZONE_STARTS: Array[float] = [1.0, 1.72, 2.42, 3.1, 3.76, 4.42, 5.05]
const LASTHIT_DRAINS: Array[float] = [1.3, 1.45, 1.6, 1.75, 1.9, 1.5, 1.7]
const LASTHIT_EARLY_LOCK := 0.45
const LASTHIT_EARLY_PENALTY := 4.0

# ---- Skillshot ----
const SKILL_SECONDS := 6.2
const SKILL_RUNNERS := 4
const SKILL_STARTS: Array[float] = [0.25, 1.7, 3.15, 4.6]
const SKILL_LIFE := 1.35
const SKILL_SPEEDS: Array[float] = [330.0, 390.0, 450.0, 510.0]   ## slowest first: the first runner teaches the lead
const SKILL_TARGET_RADIUS := 54.0
const SKILL_SHOT_RADIUS := 16.0
const SKILL_SHOT_SPEED := 1900.0
const SKILL_COOLDOWN := 0.4

# ---- Map check ----
const MAP_SECONDS := 6.4
const MAP_GRID := 5
const MAP_PINGS := 5
const MAP_FIRST_PING := 0.3
const MAP_PING_STEP := 0.24
const MAP_SHOW_UNTIL := 2.0
const MAP_RECALL_FAST := 1.6
const MAP_RECALL_SLOW := 4.2

# ---- Clutch ----
const CLUTCH_ENEMIES := 4
const CLUTCH_BULLETS := 5
const CLUTCH_RADIUS := 50.0
const CLUTCH_LEAD_IN := 0.9
const CLUTCH_WINDOWS: Array[float] = [1.05, 0.95, 0.85, 0.75]
const CLUTCH_GAPS: Array[float] = [0.35, 0.5, 0.65]
const CLUTCH_TTK_FAST := 0.32
const CLUTCH_TTK_SLOW := 0.64

# ---- Totals ----
const POINTS_PER_DRILL_POINT := 12.5   ## 8 drills x 100 x 12.5 = 10,000 max
const GRADES: Array[Dictionary] = [
	{"grade": "S+", "min": 9000},
	{"grade": "S", "min": 8000},
	{"grade": "A", "min": 6800},
	{"grade": "B", "min": 5400},
	{"grade": "C", "min": 3800},
	{"grade": "D", "min": 0},
]


## 0 at [param zero], 1 at [param full], clamped. Works in either direction.
static func lin(x: float, zero: float, full: float) -> float:
	if is_equal_approx(zero, full):
		return 1.0 if x >= full else 0.0
	return clampf((x - zero) / (full - zero), 0.0, 1.0)


static func flick_score(hits: int, misses: int) -> float:
	if hits <= 0:
		return 0.0
	var accuracy := float(hits) / float(hits + misses)
	return 100.0 * lin(float(hits), FLICK_HITS_ZERO, FLICK_HITS_FULL) * (0.55 + 0.45 * accuracy)


static func track_score(fraction_on_target: float) -> float:
	return 100.0 * lin(fraction_on_target, TRACK_FRAC_ZERO, TRACK_FRAC_FULL)


## One reaction trial. A false start or a timeout scores nothing.
static func react_trial_score(ms: int) -> float:
	if ms < 0:
		return 0.0
	return 100.0 * lin(float(ms), REACT_MS_ZERO, REACT_MS_FULL)


static func holdfire_score(hits: int, friendly: int, whiffs: int, avg_rt: float) -> float:
	var accuracy := minf(1.0, float(hits) / float(HOLD_ENEMIES))
	var speed := lin(avg_rt, HOLD_RT_SLOW, HOLD_RT_FAST) if hits > 0 else 0.0
	var raw := accuracy * (85.0 + 15.0 * speed)
	raw -= float(friendly) * HOLD_FRIENDLY_PENALTY
	raw -= float(whiffs) * HOLD_WHIFF_PENALTY
	return clampf(raw, 0.0, 100.0)


static func lasthit_score(hits: int, early: int) -> float:
	var raw := 100.0 * float(hits) / float(LASTHIT_TOTAL) - float(early) * LASTHIT_EARLY_PENALTY
	return clampf(raw, 0.0, 100.0)


static func skillshot_score(hits: int, fired: int) -> float:
	if hits <= 0 or fired <= 0:
		return 0.0
	var landed := float(hits) / float(SKILL_RUNNERS)
	var efficiency := minf(1.0, float(hits) / float(fired))
	return clampf(landed * (88.0 + 12.0 * efficiency), 0.0, 100.0)


static func mapcheck_score(correct: int, recall_seconds: float) -> float:
	if correct <= 0:
		return 0.0
	var speed := lin(recall_seconds, MAP_RECALL_SLOW, MAP_RECALL_FAST)
	return clampf(float(correct) / float(MAP_PINGS) * (86.0 + 14.0 * speed), 0.0, 100.0)


static func clutch_score(kills: int, avg_ttk: float) -> float:
	if kills <= 0:
		return 0.0
	var speed := lin(avg_ttk, CLUTCH_TTK_SLOW, CLUTCH_TTK_FAST)
	var raw := float(kills) / float(CLUTCH_ENEMIES) * 80.0 * (0.8 + 0.2 * speed)
	if kills >= CLUTCH_ENEMIES:
		raw += 20.0
	return clampf(raw, 0.0, 100.0)


static func grade_for(total: int) -> String:
	for row: Dictionary in GRADES:
		if total >= int(row["min"]):
			return str(row["grade"])
	return "D"
