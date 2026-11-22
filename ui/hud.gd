class_name Hud
extends Node2D
## The band above the play area: which drill, how long is left, the score.
## Sized to be read from a few metres back.

var index: int = 0
var title: String = ""
var hint: String = ""
var live_stat: String = ""
var fraction_left: float = 1.0
var seconds_left: float = 0.0
var timed: bool = true
var running: bool = false       ## false while the command card is up

var _score_shown: float = 0.0
var _score_goal: int = 0
var _time: float = 0.0
var _bump: float = 0.0


func set_drill(p_index: int, p_title: String, p_hint: String) -> void:
	index = p_index
	title = p_title
	hint = p_hint
	live_stat = ""
	fraction_left = 1.0


func set_score(total: int, instant: bool = false) -> void:
	if total > _score_goal:
		_bump = 1.0
	_score_goal = total
	if instant:
		_score_shown = float(total)


func _process(delta: float) -> void:
	_time += delta
	_bump = maxf(0.0, _bump - delta * 2.5)
	if absf(_score_shown - float(_score_goal)) > 0.5:
		_score_shown = lerpf(_score_shown, float(_score_goal), clampf(delta * 7.0, 0.0, 1.0))
		if absf(_score_shown - float(_score_goal)) < 2.0:
			_score_shown = float(_score_goal)
	queue_redraw()


func _draw() -> void:
	var count := Session.drill_count()
	# Left: which drill.
	Look.text(self, &"ui", Vector2(112.0, 60.0), "DRILL %d / %d" % [index + 1, count], 36, Look.DIM)
	Look.text(self, &"display", Vector2(110.0, 136.0), title, 88, Look.INK)
	for i in count:
		var pip := Rect2(330.0 + float(i) * 44.0, 36.0, 34.0, 12.0)
		var color := Look.FAINT
		if i < index:
			color = Look.accent()
		elif i == index:
			color = Color(Look.INK, 0.6 + 0.4 * Look.pulse(_time, 6.0))
		Look.panel(self, pip, color, 6)

	# Middle: time left in this drill.
	if timed:
		var low := running and seconds_left < 1.5
		var color := Look.HOT if low else Look.INK
		Look.text_c(self, &"monox", Vector2(960.0, 62.0), "%.1f" % seconds_left, 76, color)
		Look.bar(self, Rect2(710.0, 116.0, 500.0, 16.0), fraction_left, Look.HOT if low else Look.accent())
	else:
		Look.text_c(self, &"head", Vector2(960.0, 76.0), "BEST OF %d" % Tuning.REACT_TRIALS, 56, Look.INK)

	# Right: the running score.
	Look.text_r(self, &"ui", Vector2(1810.0, 60.0), "SCORE", 36, Look.DIM)
	var size := int(84.0 + 14.0 * _bump)
	Look.text_r(self, &"monox", Vector2(1810.0, 136.0), Rating.with_commas(int(round(_score_shown))), size, Look.INK.lerp(Look.GOLD, _bump))

	# Under the play area: the rule in one line, and a live readout.
	Look.text(self, &"body", Vector2(112.0, 1046.0), hint, 42, Look.DIM)
	Look.text_r(self, &"mono", Vector2(1810.0, 1046.0), live_stat, 38, Look.accent())
