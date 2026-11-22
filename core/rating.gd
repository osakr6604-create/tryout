class_name Rating
extends RefCounted
## Turns eight drill results into the scouting report: a total, six attributes,
## a grade, a role and a one-line scout's note. Pure functions, no state.

const ATTRS: Array[StringName] = [
	&"REFLEX", &"PRECISION", &"TRACKING", &"TIMING", &"DISCIPLINE", &"AWARENESS",
]

## Which drills feed which attribute, and how much. "react_clean" is not a
## drill: it is 100 when the reaction drill had no false starts.
const WEIGHTS: Dictionary = {
	&"REFLEX": {&"react": 0.75, &"clutch": 0.25},
	&"PRECISION": {&"flick": 0.7, &"clutch": 0.3},
	&"TRACKING": {&"track": 0.8, &"skillshot": 0.2},
	&"TIMING": {&"lasthit": 0.65, &"skillshot": 0.35},
	&"DISCIPLINE": {&"holdfire": 0.8, &"react_clean": 0.2},
	&"AWARENESS": {&"mapcheck": 0.75, &"lasthit": 0.25},
}

const ROLES: Dictionary = {
	&"REFLEX": "ENTRY",
	&"PRECISION": "MARKSMAN",
	&"TRACKING": "RIFLER",
	&"TIMING": "PLAYMAKER",
	&"DISCIPLINE": "ANCHOR",
	&"AWARENESS": "SHOTCALLER",
}
const FLEX_ROLE := "FLEX"
const FLEX_SPREAD := 10       ## all six attributes this close together reads as a flex player

const STRENGTHS: Dictionary = {
	&"REFLEX": "Lightning first shot.",
	&"PRECISION": "Clean, confident aim.",
	&"TRACKING": "Glued to moving targets.",
	&"TIMING": "Reads the tempo of a fight.",
	&"DISCIPLINE": "Ice cold under pressure.",
	&"AWARENESS": "Sees the whole map.",
}
const WEAKNESSES: Dictionary = {
	&"REFLEX": "Needs a faster trigger.",
	&"PRECISION": "Aim needs reps.",
	&"TRACKING": "Loses moving targets.",
	&"TIMING": "Timing is a beat off.",
	&"DISCIPLINE": "Trigger discipline needs work.",
	&"AWARENESS": "Tunnel vision on the map.",
}
const VERDICTS: Dictionary = {
	"S+": "Sign immediately.",
	"S": "Starter material.",
	"A": "Call them back.",
	"B": "Academy prospect.",
	"C": "Keep grinding.",
	"D": "Great attitude.",
}
const WEAK_BELOW := 55


## Total points, 0 to 10,000.
static func total(results: Array[DrillResult]) -> int:
	var sum := 0.0
	for r in results:
		sum += r.score
	return clampi(int(round(sum * Tuning.POINTS_PER_DRILL_POINT)), 0, 10000)


## The two digit overall number on the card.
static func overall(total_points: int) -> int:
	return clampi(int(round(float(total_points) / 100.0)), 0, 99)


static func _scores(results: Array[DrillResult]) -> Dictionary:
	var by_id: Dictionary = {}
	for r in results:
		by_id[r.id] = r.score
		if r.id == &"react":
			var early := int(r.metrics.get("false_starts", 0))
			by_id[&"react_clean"] = clampf(100.0 - 50.0 * float(early), 0.0, 100.0)
	return by_id


## Attribute name to a 0..99 value.
static func attributes(results: Array[DrillResult]) -> Dictionary:
	var by_id := _scores(results)
	var out: Dictionary = {}
	for attr in ATTRS:
		var weights: Dictionary = WEIGHTS[attr]
		var sum := 0.0
		var weight_sum := 0.0
		for source: StringName in weights:
			if by_id.has(source):
				sum += float(by_id[source]) * float(weights[source])
				weight_sum += float(weights[source])
		var value := sum / weight_sum if weight_sum > 0.0 else 0.0
		out[attr] = clampi(int(round(value)), 0, 99)
	return out


static func strongest(attrs: Dictionary) -> StringName:
	var best: StringName = ATTRS[0]
	for attr in ATTRS:
		if int(attrs.get(attr, 0)) > int(attrs.get(best, 0)):
			best = attr
	return best


static func weakest(attrs: Dictionary) -> StringName:
	var worst: StringName = ATTRS[0]
	for attr in ATTRS:
		if int(attrs.get(attr, 0)) < int(attrs.get(worst, 0)):
			worst = attr
	return worst


static func role(attrs: Dictionary) -> String:
	var hi := int(attrs.get(strongest(attrs), 0))
	var lo := int(attrs.get(weakest(attrs), 0))
	if hi - lo <= FLEX_SPREAD:
		return FLEX_ROLE
	return str(ROLES[strongest(attrs)])


static func scout_note(attrs: Dictionary, grade: String) -> String:
	var parts: PackedStringArray = []
	if role(attrs) == FLEX_ROLE:
		parts.append("Balanced toolkit, no clear weakness.")
	else:
		parts.append(str(STRENGTHS[strongest(attrs)]))
		var worst := weakest(attrs)
		if int(attrs.get(worst, 0)) < WEAK_BELOW:
			parts.append(str(WEAKNESSES[worst]))
	parts.append(str(VERDICTS.get(grade, "")))
	return " ".join(parts)


## "7,412" style.
static func with_commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return "-" + out if n < 0 else out
