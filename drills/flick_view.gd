class_name FlickView
extends DrillView

var _spawned_at: float = 0.0
var _last_hit: Vector2 = Vector2.INF
var _last_hit_at: float = -9.0


func _on_event(e: Dictionary) -> void:
	match e["type"]:
		&"spawn":
			_spawned_at = time
		&"hit":
			var pos: Vector2 = e["pos"]
			var streak := int(e["streak"])
			_last_hit = pos
			_last_hit_at = time
			fx.burst(pos, Look.accent(), 16)
			fx.ring(pos, Look.INK, 30.0, 120.0, 0.3)
			fx.kick(4.0)
			if streak >= 3:
				fx.say(pos + Vector2(0.0, -76.0), "x%d" % streak, Look.GOLD, 44, &"mono")
			snd(&"hit", 1.0 + minf(float(streak), 14.0) * 0.045)
		&"miss":
			fx.ring(e["pos"], Look.HOT, 10.0, 54.0, 0.25, 5.0)
			snd(&"miss")


func _paint() -> void:
	var m := model as FlickModel
	# A fading line from the last hit to the new target helps spectators follow.
	var since := time - _last_hit_at
	if _last_hit != Vector2.INF and since < 0.22:
		draw_line(_last_hit, m.target, Color(Look.accent(), 0.35 * (1.0 - since / 0.22)), 3.0, true)
	_target(m.target, Tuning.FLICK_RADIUS, Look.accent(), _pop(time - _spawned_at))
