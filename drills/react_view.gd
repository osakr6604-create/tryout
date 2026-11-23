class_name ReactView
extends DrillView
## The reaction drill measures its own times: when the "go" reaches this view
## it notes the high resolution clock, and a click is timed against that
## instead of against whole frames.

const WALL := Vector2(230.0, 470.0)

var _go_usec: int = 0
var _go_at: float = -9.0
var _shown_at: float = -9.0
var _message: String = ""
var _message_color: Color = Look.INK


func mood() -> Color:
	return Look.HOT


func crosshair() -> StringName:
	return &"dot"


func pointer_pressed(pos: Vector2) -> void:
	var m := model as ReactModel
	if m.phase == ReactModel.Phase.GO and _go_usec > 0:
		m.pointer = pos
		m.press_measured(int(round(float(Time.get_ticks_usec() - _go_usec) / 1000.0)))
	else:
		m.press(pos)


func _on_event(e: Dictionary) -> void:
	match e["type"]:
		&"wait":
			_go_usec = 0
			_message = ""
		&"go":
			_go_usec = Time.get_ticks_usec()
			_go_at = time
			fx.flash_screen(Look.INK, 0.12)
			snd(&"go")
		&"reacted":
			var ms := int(e["ms"])
			_show("%d ms" % ms, Look.score_color(Tuning.react_trial_score(ms)))
			fx.burst(_target_pos(), Look.HOT, 22, 620.0)
			fx.ring(_target_pos(), Look.INK, 40.0, 190.0, 0.4)
			fx.kick(7.0)
			snd(&"hit", 1.2)
		&"false_start":
			_show("TOO EARLY", Look.HOT)
			fx.kick(12.0)
			fx.flash_screen(Look.HOT, 0.16)
			snd(&"bad")
		&"timeout":
			_show("TOO SLOW", Look.DIM)
			snd(&"miss")


func _show(text: String, color: Color) -> void:
	_message = text
	_message_color = color
	_shown_at = time


func _target_pos() -> Vector2:
	var m := model as ReactModel
	return model.field.get_center() + Vector2(float(m.side) * (WALL.x * 0.5 + 150.0), -20.0)


func _paint() -> void:
	var m := model as ReactModel
	var center := model.field.get_center()

	# The cover they peek around.
	var wall := Rect2(center - WALL * 0.5 + Vector2(0.0, -20.0), WALL)
	Look.panel(self, wall, Color(0.09, 0.13, 0.26, 0.96), 20, Color(Look.INK, 0.14), 3)
	for i in 4:
		var y := wall.position.y + 70.0 + float(i) * 110.0
		draw_line(Vector2(wall.position.x + 28.0, y), Vector2(wall.end.x - 28.0, y), Color(Look.INK, 0.06), 4.0)

	match m.phase:
		ReactModel.Phase.WAIT:
			if not frozen:
				var breathe := Look.pulse(time, 5.0)
				Look.text_c(self, &"display", center + Vector2(0.0, -330.0), "WAIT FOR IT", 96, Color(Look.INK, 0.55 + 0.35 * breathe))
		ReactModel.Phase.GO:
			_enemy(_target_pos(), 92.0, _pop(time - _go_at, 0.07))
			Look.text_c(self, &"display", center + Vector2(0.0, -330.0), "NOW!", 130, Look.HOT)
		ReactModel.Phase.SHOW:
			var pop := _pop(time - _shown_at, 0.16)
			Look.text_pop_c(self, &"monox", center + Vector2(0.0, -330.0), _message, 120, pop, _message_color, 4.0)

	# The trials so far, as chips along the bottom.
	var chip := Vector2(250.0, 74.0)
	var gap := 26.0
	var total := float(Tuning.REACT_TRIALS) * chip.x + float(Tuning.REACT_TRIALS - 1) * gap
	var x := center.x - total * 0.5
	var y := model.field.end.y - chip.y - 34.0
	for i in Tuning.REACT_TRIALS:
		var rect := Rect2(x + float(i) * (chip.x + gap), y, chip.x, chip.y)
		var label := "TRIAL %d" % (i + 1)
		var color := Look.FAINT
		if i < m.times_ms.size():
			var ms := m.times_ms[i]
			if ms == ReactModel.FALSE_START:
				label = "EARLY"
				color = Look.HOT
			elif ms == ReactModel.TIMEOUT:
				label = "SLOW"
				color = Look.DIM
			else:
				label = "%d ms" % ms
				color = Look.score_color(Tuning.react_trial_score(ms))
		elif i == m.trial:
			color = Look.INK
		Look.panel(self, rect, Look.PANEL, 16, Color(color, 0.7), 3)
		Look.text_c(self, &"mono", rect.get_center(), label, 38, color)
