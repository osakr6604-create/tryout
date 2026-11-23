extends SceneTree
## Writes docs/SCORING.md from the numbers in core/tuning.gd and core/rating.gd,
## so the published explanation of the scoring can never drift from the game.
##
##   godot --headless --path . --script res://dev/scoring_doc.gd
##   godot --headless --path . --script res://dev/scoring_doc.gd -- --check
##
## With --check it writes nothing and exits with 1 when the file is out of date.

const PATH := "res://docs/SCORING.md"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var text := _build()
	if OS.get_cmdline_user_args().has("--check"):
		var current := FileAccess.get_file_as_string(PATH).replace("\r\n", "\n")
		if current != text:
			print("docs/SCORING.md is out of date. Run dev/scoring_doc.gd to refresh it.")
			quit(1)
			return
		print("docs/SCORING.md matches the game.")
		quit(0)
		return
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print("wrote ", PATH)
	quit(0)


func _n(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else str(snappedf(value, 0.01))


func _build() -> String:
	var t := Tuning
	var lines: PackedStringArray = []
	lines.append("# How Tryout scores a run")
	lines.append("")
	lines.append("This page is written by `dev/scoring_doc.gd` from the numbers in `core/tuning.gd` and `core/rating.gd`. CI fails if it falls out of step with the game, so what you read here is what the game does.")
	lines.append("")
	lines.append("Each of the eight drills gives 0 to 100. The total is the sum times %s, so a run scores 0 to 10,000. \"From A to B\" below means a straight line: A scores 0, B scores 100, and anything past either end is capped." % _n(t.POINTS_PER_DRILL_POINT))
	lines.append("")
	lines.append("## The drills")
	lines.append("")
	lines.append("| Drill | Length | Score |")
	lines.append("| --- | --- | --- |")
	lines.append("| Flick | %s s | Hits from %s to %s, times (0.55 + 0.45 x accuracy). Targets are %s px across. |" % [_n(t.FLICK_SECONDS), _n(t.FLICK_HITS_ZERO), _n(t.FLICK_HITS_FULL), _n(t.FLICK_RADIUS * 2.0)])
	lines.append("| Track | %s s | Share of time on target from %s%% to %s%%. The first %s s do not count. The target speeds up from %s to %s px a second. |" % [_n(t.TRACK_SECONDS), _n(t.TRACK_FRAC_ZERO * 100.0), _n(t.TRACK_FRAC_FULL * 100.0), _n(t.TRACK_GRACE), _n(t.TRACK_SPEED_START), _n(t.TRACK_SPEED_END)])
	lines.append("| React | %d trials | Each trial from %s ms to %s ms; the drill is the average. An early click or no click within %s s scores 0 for that trial. |" % [t.REACT_TRIALS, _n(t.REACT_MS_ZERO), _n(t.REACT_MS_FULL), _n(t.REACT_TIMEOUT)])
	lines.append("| Hold fire | %d shapes | Enemies hit out of %d, times (70 + 30 x speed), where speed runs from %s s to %s s average. Minus %s for each teammate shot and %s for each click on nothing. |" % [t.HOLD_COUNT, t.HOLD_ENEMIES, _n(t.HOLD_RT_SLOW), _n(t.HOLD_RT_FAST), _n(t.HOLD_FRIENDLY_PENALTY), _n(t.HOLD_WHIFF_PENALTY)])
	lines.append("| Last hit | %s s | Last hits out of %d, as a percentage, minus %s for each early click. The bar is gold under %s%% health. |" % [_n(t.LASTHIT_SECONDS), t.LASTHIT_TOTAL, _n(t.LASTHIT_EARLY_PENALTY), _n(t.LASTHIT_KILL_ZONE * 100.0)])
	lines.append("| Skillshot | %s s | Runners hit out of %d, times (88 + 12 x hits per shot). Shots travel %s px a second. |" % [_n(t.SKILL_SECONDS), t.SKILL_RUNNERS, _n(t.SKILL_SHOT_SPEED)])
	lines.append("| Map check | %s s | Pings found out of %d, times (70 + 30 x speed), where speed runs from %s s to %s s of recall. |" % [_n(t.MAP_SECONDS), t.MAP_PINGS, _n(t.MAP_RECALL_SLOW), _n(t.MAP_RECALL_FAST)])
	lines.append("| Clutch | %d opponents, %d bullets | 80 x share downed x (0.8 + 0.2 x speed), where speed runs from %s s to %s s per opponent, plus 20 for all %d. |" % [t.CLUTCH_ENEMIES, t.CLUTCH_BULLETS, _n(t.CLUTCH_TTK_SLOW), _n(t.CLUTCH_TTK_FAST), t.CLUTCH_ENEMIES])
	lines.append("")
	lines.append("## Grades")
	lines.append("")
	lines.append("| Grade | Total at least |")
	lines.append("| --- | --- |")
	for row: Dictionary in t.GRADES:
		lines.append("| %s | %s |" % [row["grade"], Rating.with_commas(int(row["min"]))])
	lines.append("")
	lines.append("The two digit overall on the card is the total divided by 100.")
	lines.append("")
	lines.append("## Attributes and roles")
	lines.append("")
	lines.append("Each attribute is a weighted average of drill scores, shown as 0 to 99.")
	lines.append("")
	lines.append("| Attribute | Made from | Role when it is the strongest |")
	lines.append("| --- | --- | --- |")
	var titles := {&"flick": "Flick", &"track": "Track", &"react": "React", &"holdfire": "Hold fire", &"lasthit": "Last hit", &"skillshot": "Skillshot", &"mapcheck": "Map check", &"clutch": "Clutch"}
	for attr in Rating.ATTRS:
		var parts: PackedStringArray = []
		var weights: Dictionary = Rating.WEIGHTS[attr]
		for source: StringName in weights:
			parts.append("%s %s%%" % [titles[source], _n(float(weights[source]) * 100.0)])
		lines.append("| %s | %s | %s |" % [String(attr).capitalize(), ", ".join(parts), str(Rating.ROLES[attr]).capitalize()])
	lines.append("")
	lines.append("Each early click in the reaction drill also takes %d off Discipline. When all six attributes are within %d points of each other the role is Flex." % [Rating.FALSE_START_COST, Rating.FLEX_SPREAD])
	lines.append("")
	lines.append("## Fairness")
	lines.append("")
	lines.append("- Everyone plays the same eight drills in the same order, for the same lengths.")
	lines.append("- Layouts and delays come from a fresh seed each run, so watching the player ahead of you does not help. Within a run the hard parts are balanced: flick distances come from a shuffled set, reaction delays are the same three in a new order.")
	lines.append("- A tie keeps the earlier run ahead. A score has to be beaten, not matched.")
	lines.append("- Reaction times are measured from the frame the target is drawn to the frame the click arrives, so they include the screen's and the mouse's own delay. They are fair between players on the same station and are not lab measurements.")
	lines.append("- The balance was tuned against a simulated player at six skill levels (`dev/balance.gd`). It has not been tuned on a crowd yet.")
	lines.append("")
	return "\n".join(lines)
