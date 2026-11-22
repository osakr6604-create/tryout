class_name HoldFireView
extends DrillView

var _spawned_at: float = 0.0


func mood() -> Color:
	return Look.VIOLET


func _on_event(e: Dictionary) -> void:
	match e["type"]:
		&"spawn":
			_spawned_at = time
			snd(&"pop", 1.15 if e["enemy"] else 0.8, -6.0)
		&"hit":
			fx.burst(e["pos"], Look.HOT, 18, 520.0)
			fx.ring(e["pos"], Look.GOLD, 40.0, 150.0, 0.32)
			fx.kick(5.0)
			snd(&"hit", 1.1)
		&"friendly":
			fx.burst(e["pos"], Color("4D8DFF"), 26, 640.0, 9.0)
			fx.say((e["pos"] as Vector2) + Vector2(0.0, -100.0), "FRIENDLY FIRE!", Look.HOT, 64, &"display")
			fx.kick(16.0)
			fx.flash_screen(Look.HOT, 0.26)
			snd(&"bad")
		&"escaped":
			fx.say((e["pos"] as Vector2) + Vector2(0.0, -80.0), "MISSED", Look.DIM, 44)
			snd(&"miss", 0.9, -4.0)
		&"held":
			fx.say((e["pos"] as Vector2) + Vector2(0.0, -80.0), "GOOD HOLD", Look.GOOD, 44)
			fx.ring(e["pos"], Look.GOOD, 50.0, 110.0, 0.3, 4.0)
			snd(&"good", 1.0, -5.0)
		&"whiff":
			fx.ring(e["pos"], Look.DIM, 10.0, 50.0, 0.22, 4.0)
			snd(&"miss", 1.2, -8.0)


func _paint() -> void:
	var m := model as HoldFireModel
	_legend()
	var s := m.live()
	if s.is_empty():
		return
	var pos: Vector2 = s["pos"]
	var pop := _pop(time - _spawned_at, 0.1)
	var left := 1.0 - clampf((m.t - float(s["start"])) / float(s["life"]), 0.0, 1.0)
	if s["enemy"]:
		_enemy(pos, Tuning.HOLD_RADIUS, pop)
		Look.arc(self, pos, Tuning.HOLD_RADIUS + 26.0, 7.0, left, Color(Look.HOT, 0.85))
	else:
		_ally(pos, Tuning.HOLD_RADIUS, pop)
		Look.arc(self, pos, Tuning.HOLD_RADIUS + 26.0, 7.0, left, Color("4D8DFF", 0.85))


## Always on screen, so nobody needs the rule explained twice.
func _legend() -> void:
	var y := model.field.end.y - 62.0
	var cx := model.field.get_center().x
	Look.panel(self, Rect2(cx - 330.0, y - 38.0, 660.0, 76.0), Look.PANEL, 38, Color(Look.INK, 0.1), 2)
	_enemy(Vector2(cx - 270.0, y), 24.0)
	Look.text(self, &"head", Vector2(cx - 230.0, y + 15.0), "SHOOT", 44, Look.HOT)
	_ally(Vector2(cx + 60.0, y), 24.0)
	Look.text(self, &"head", Vector2(cx + 100.0, y + 15.0), "HOLD FIRE", 44, Color("7AAEFF"))
