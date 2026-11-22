class_name ClutchView
extends DrillView

const WORDS: Array[String] = ["ONE!", "TWO!", "THREE!", "CLUTCH!"]

var _peeked_at: float = 0.0
var _beat_in: float = 0.0
var _beat: float = 0.0


func mood() -> Color:
	return Look.HOT


func _on_event(e: Dictionary) -> void:
	match e["type"]:
		&"peek":
			_peeked_at = time
			snd(&"pop", 1.3)
		&"kill":
			var n := int(e["count"])
			var pos: Vector2 = e["pos"]
			fx.burst(pos, Look.HOT, 30, 760.0, 9.0)
			fx.ring(pos, Look.INK, 40.0, 220.0, 0.42)
			fx.say(pos + Vector2(0.0, -100.0), WORDS[clampi(n - 1, 0, 3)], Look.GOLD, 84, &"display")
			fx.kick(10.0)
			snd(&"boom", 0.9 + float(n) * 0.1)
		&"clutch":
			fx.flash_screen(Look.GOLD, 0.3)
			fx.kick(18.0)
			for i in 5:
				fx.ring(model.field.get_center(), Look.GOLD, 60.0 + float(i) * 60.0, 620.0 + float(i) * 90.0, 0.7 + float(i) * 0.08, 9.0)
			snd(&"cheer")
		&"miss":
			fx.ring(e["pos"], Look.DIM, 12.0, 60.0, 0.24, 5.0)
			snd(&"shot", 1.2)
		&"shot_back":
			fx.say((e["pos"] as Vector2) + Vector2(0.0, -90.0), "TOO SLOW", Look.HOT, 56, &"display")
			fx.flash_screen(Look.HOT, 0.24)
			fx.kick(14.0)
			snd(&"bad")
		&"empty":
			snd(&"empty")


func _process(delta: float) -> void:
	super(delta)
	if model == null or frozen or model.done:
		return
	# A heartbeat that speeds up as the round goes on.
	_beat = maxf(0.0, _beat - delta * 3.0)
	_beat_in -= delta
	if _beat_in <= 0.0:
		_beat_in = lerpf(0.72, 0.42, model.progress())
		_beat = 1.0
		snd(&"heart", 1.0, -3.0)


func _paint() -> void:
	var m := model as ClutchModel
	var f := model.field
	# Lights down, with a red pulse on each heartbeat.
	Look.panel(self, f, Color(0, 0, 0, 0.3), 26)
	Look.glow(self, Vector2(f.position.x, f.get_center().y), 700.0, Color(Look.HOT, 0.1 * _beat))
	Look.glow(self, Vector2(f.end.x, f.get_center().y), 700.0, Color(Look.HOT, 0.1 * _beat))

	# Who is left.
	var top := Vector2(f.get_center().x, f.position.y + 54.0)
	Look.text_r(self, &"display", top + Vector2(-90.0, 22.0), "1 V 4", 64, Look.INK)
	for i in m.foes.size():
		var dot := top + Vector2(-40.0 + float(i) * 58.0, 0.0)
		match int(m.foes[i]["state"]):
			ClutchModel.DOWN:
				Look.diamond(self, dot, 22.0, Look.GOOD)
			ClutchModel.ESCAPED:
				Look.diamond_outline(self, dot, 20.0, 5.0, Color(Look.HOT, 0.9))
				draw_line(dot + Vector2(-12, -12), dot + Vector2(12, 12), Look.HOT, 5.0, true)
			ClutchModel.VISIBLE:
				Look.diamond(self, dot, 22.0, Look.HOT)
			_:
				Look.diamond_outline(self, dot, 20.0, 4.0, Color(Look.INK, 0.4))

	# The magazine.
	var mag := Vector2(f.get_center().x - float(Tuning.CLUTCH_BULLETS - 1) * 23.0, f.end.y - 60.0)
	for i in Tuning.CLUTCH_BULLETS:
		var rect := Rect2(mag.x + float(i) * 46.0 - 13.0, mag.y - 30.0, 26.0, 60.0)
		if i < m.bullets:
			Look.panel(self, rect, Look.GOLD, 10)
		else:
			Look.panel(self, rect, Color(0, 0, 0, 0), 10, Color(Look.INK, 0.3), 3)

	var foe := m.visible_foe()
	if not foe.is_empty():
		var pos: Vector2 = foe["pos"]
		_enemy(pos, Tuning.CLUTCH_RADIUS, _pop(time - _peeked_at, 0.08))
		var left := 1.0 - clampf((m.t - float(foe["start"])) / float(foe["window"]), 0.0, 1.0)
		Look.arc(self, pos, Tuning.CLUTCH_RADIUS + 24.0, 8.0, left, Look.HOT)
	elif m.kills == 0 and m.t < Tuning.CLUTCH_LEAD_IN and not frozen:
		Look.text_c(self, &"display", f.get_center(), "HOLD...", 120, Color(Look.INK, 0.4 + 0.4 * Look.pulse(time, 9.0)))
