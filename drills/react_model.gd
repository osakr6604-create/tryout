class_name ReactModel
extends DrillModel
## REACT: wait for the peek, then click. Three trials with shuffled delays,
## so nobody can time the next one by watching the player before them.
## Clicking early is a false start and that trial scores nothing.

enum Phase { WAIT, GO, SHOW }

const FALSE_START := -1
const TIMEOUT := -2

var trial: int = 0
var phase: Phase = Phase.WAIT
var phase_t: float = 0.0
var wait_for: float = 0.0
var side: int = 1                    ## which side of cover the target peeks from
var times_ms: Array[int] = []        ## one entry per finished trial
var last_ms: int = 0

var _delays: Array = []


func _setup() -> void:
	id = &"react"
	title = "REACT"
	hint = "Wait for the peek, then click"
	# The length depends on the delays and on how fast the player is.
	# This is only a ceiling; the drill ends after the third trial.
	duration = 14.0
	timed = false
	trial = 0
	times_ms.clear()
	last_ms = 0
	_delays = shuffled(Tuning.REACT_DELAYS)
	_begin_trial()


func _begin_trial() -> void:
	phase = Phase.WAIT
	phase_t = 0.0
	var jitter := rng.randf_range(-Tuning.REACT_DELAY_JITTER, Tuning.REACT_DELAY_JITTER)
	wait_for = float(_delays[trial]) + jitter
	side = 1 if rng.randf() < 0.5 else -1
	emit(&"wait", {"trial": trial})


func _advance(dt: float) -> void:
	phase_t += dt
	match phase:
		Phase.WAIT:
			if phase_t >= wait_for:
				phase = Phase.GO
				phase_t = 0.0
				emit(&"go", {"trial": trial, "side": side})
		Phase.GO:
			if phase_t >= Tuning.REACT_TIMEOUT:
				_record(TIMEOUT)
		Phase.SHOW:
			if phase_t >= Tuning.REACT_SHOW:
				trial += 1
				if trial >= Tuning.REACT_TRIALS:
					done = true
				else:
					_begin_trial()


func _press(_pos: Vector2) -> void:
	match phase:
		Phase.WAIT:
			_record(FALSE_START)
		Phase.GO:
			_record(int(round(phase_t * 1000.0)))


## The view calls this instead of press() with a time it measured itself from
## the high resolution clock, which is tighter than whole frames.
func press_measured(ms: int) -> void:
	if done:
		return
	match phase:
		Phase.WAIT:
			_record(FALSE_START)
		Phase.GO:
			_record(maxi(1, ms))


func _record(ms: int) -> void:
	times_ms.append(ms)
	last_ms = ms
	phase = Phase.SHOW
	phase_t = 0.0
	if ms == FALSE_START:
		emit(&"false_start", {"trial": trial})
	elif ms == TIMEOUT:
		emit(&"timeout", {"trial": trial})
	else:
		emit(&"reacted", {"trial": trial, "ms": ms})


func false_starts() -> int:
	return times_ms.count(FALSE_START)


func best_ms() -> int:
	var best := 0
	for ms in times_ms:
		if ms > 0 and (best == 0 or ms < best):
			best = ms
	return best


func average_ms() -> int:
	var sum := 0
	var n := 0
	for ms in times_ms:
		if ms > 0:
			sum += ms
			n += 1
	return int(round(float(sum) / float(n))) if n > 0 else 0


func live_stat() -> String:
	return "%d / %d" % [mini(trial + 1, Tuning.REACT_TRIALS), Tuning.REACT_TRIALS]


func result() -> DrillResult:
	var total := 0.0
	for ms in times_ms:
		total += Tuning.react_trial_score(ms)
	var score := total / float(Tuning.REACT_TRIALS)
	var headline := "no clean reaction"
	if best_ms() > 0:
		headline = "%d ms best, %d ms average" % [best_ms(), average_ms()]
	if false_starts() > 0:
		headline += ", %d early" % false_starts()
	return DrillResult.make(id, title, score, headline, {
		"best_ms": best_ms(),
		"avg_ms": average_ms(),
		"false_starts": false_starts(),
		"times_ms": times_ms.duplicate(),
	})
