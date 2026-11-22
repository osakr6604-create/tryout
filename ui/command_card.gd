class_name CommandCard
extends Node2D
## The one-word command before each drill, and the result stamp after it.
## Both are a leaning band across the middle of the screen that slides in,
## holds, and slides out.

enum Mode { HIDDEN, COMMAND, STAMP, BRIEFING }

var mode: Mode = Mode.HIDDEN
var t: float = 0.0
var length: float = 1.0

var _over: String = ""
var _word: String = ""
var _under: String = ""
var _color: Color = Look.INK
var _points: int = 0
var _last_count: int = -1


func show_command(index: int, title: String, hint: String, seconds: float) -> void:
	mode = Mode.COMMAND
	t = 0.0
	length = seconds
	_over = "DRILL %d / %d" % [index + 1, Session.drill_count()]
	_word = title
	_under = hint
	_color = Look.accent()
	Sfx.play(&"card")
	queue_redraw()


func show_stamp(result: DrillResult, points: int, seconds: float) -> void:
	mode = Mode.STAMP
	t = 0.0
	length = seconds
	_over = result.title
	_word = result.stamp()
	_under = result.headline
	_color = Look.score_color(result.score)
	_points = points
	Sfx.play(&"stamp", 0.8 + result.score / 250.0)
	queue_redraw()


func show_briefing(seconds: float) -> void:
	mode = Mode.BRIEFING
	t = 0.0
	length = seconds
	_last_count = -1
	queue_redraw()


func hide_card() -> void:
	mode = Mode.HIDDEN
	queue_redraw()


func finished() -> bool:
	return mode == Mode.HIDDEN or t >= length


func _process(delta: float) -> void:
	if mode == Mode.HIDDEN:
		return
	t += delta
	if mode == Mode.BRIEFING:
		# Beep on 3, 2, 1.
		var count := _countdown()
		if count != _last_count:
			_last_count = count
			if count > 0:
				Sfx.play(&"count")
	queue_redraw()


## 3, 2, 1 over the last part of the briefing; 0 before it starts.
func _countdown() -> int:
	var start := length - 2.1
	if t < start:
		return 0
	return clampi(3 - int((t - start) / 0.7), 1, 3)


func _draw() -> void:
	match mode:
		Mode.COMMAND, Mode.STAMP:
			_draw_band()
		Mode.BRIEFING:
			_draw_briefing()


func _slide() -> float:
	# -1 off to the left, 0 in place, 1 off to the right.
	var enter := 0.16
	var leave := 0.16
	if t < enter:
		return -(1.0 - Look.ease_out(t / enter))
	if t > length - leave:
		return Look.ease_out((t - (length - leave)) / leave)
	return 0.0


func _draw_band() -> void:
	var slide := _slide()
	var alpha := 1.0 - absf(slide)
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0, 0, 0, 0.5 * alpha))
	var x := slide * 700.0
	var band := Rect2(-80.0 + x, 360.0, 2080.0, 360.0)
	Look.panel(self, band, Color(0.04, 0.07, 0.16, 0.96), 0)
	draw_rect(Rect2(band.position.x, band.position.y, band.size.x, 12.0), Color(_color, 0.95))
	draw_rect(Rect2(band.position.x, band.end.y - 4.0, band.size.x, 4.0), Color(_color, 0.6))
	var c := Vector2(960.0 + x, 540.0)
	Look.text_c(self, &"ui", c + Vector2(0.0, -132.0), _over, 44, Color(Look.DIM, alpha))
	if mode == Mode.STAMP:
		var pop := Look.ease_back(clampf(t / 0.2, 0.0, 1.0))
		Look.text_shadow_c(self, &"display", c + Vector2(0.0, -24.0), _word, int(190.0 * (0.7 + 0.3 * pop)), Color(_color, alpha), 6.0)
		Look.text_c(self, &"head", c + Vector2(-150.0, 112.0), _under, 52, Color(Look.INK, alpha))
		Look.text(self, &"monox", c + Vector2(Look.measure(&"head", _under, 52).x * 0.5 - 110.0, 132.0), "+%s" % Rating.with_commas(_points), 60, Color(Look.GOLD, alpha))
	else:
		Look.text_shadow_c(self, &"display", c + Vector2(0.0, -20.0), _word, 210, Color(Look.INK, alpha), 6.0)
		Look.text_c(self, &"head", c + Vector2(0.0, 118.0), _under, 58, Color(_color, alpha))


func _draw_briefing() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0, 0, 0, 0.55))
	var lines: Array[String] = ["8 DRILLS", "60 SECONDS", "ONE SCOUTING REPORT"]
	for i in lines.size():
		var at := 0.1 + float(i) * 0.3
		if t < at:
			continue
		var pop := Look.ease_back(clampf((t - at) / 0.2, 0.0, 1.0))
		var color := Look.INK if i < 2 else Look.accent()
		Look.text_shadow_c(self, &"display", Vector2(960.0, 250.0 + float(i) * 130.0), lines[i], int(124.0 * (0.75 + 0.25 * pop)), color)
	if t > 0.95:
		Look.text_c(self, &"body", Vector2(960.0, 640.0), "Mouse only. Do what the screen says.", 48, Look.DIM)
	var count := _countdown()
	if count > 0:
		var start := length - 2.1
		var phase := fmod(t - start, 0.7) / 0.7
		var size := int(lerpf(300.0, 210.0, Look.ease_out(phase)))
		Look.ring(self, Vector2(960.0, 850.0), 150.0, 8.0, Color(Look.accent(), 0.25))
		Look.arc(self, Vector2(960.0, 850.0), 150.0, 8.0, 1.0 - phase, Look.accent())
		Look.text_shadow_c(self, &"monox", Vector2(960.0, 850.0), str(count), size, Look.INK)
