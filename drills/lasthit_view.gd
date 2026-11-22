class_name LastHitView
extends DrillView

const BAR_WIDTH := 120.0

var _lane_flash: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _lane_flash_color: Array[Color] = [Look.HOT, Look.HOT, Look.HOT, Look.HOT]


func mood() -> Color:
	return Look.GOLD


func _on_event(e: Dictionary) -> void:
	var lane := int(e.get("lane", 0))
	var m := model as LastHitModel
	var center := m.lane_rect(lane).get_center()
	match e["type"]:
		&"spawn":
			snd(&"pop", 0.9, -8.0)
		&"hit":
			_flash(lane, Look.GOLD)
			fx.burst(center + Vector2(0.0, 120.0), Look.GOLD, 26, 620.0, 8.0)
			fx.ring(center + Vector2(0.0, 120.0), Look.GOLD, 40.0, 190.0, 0.4)
			fx.say(center + Vector2(0.0, -40.0), "LAST HIT!", Look.GOLD, 60, &"display")
			fx.kick(6.0)
			snd(&"coin", 1.0 + float(int(e["count"])) * 0.06)
		&"early":
			_flash(lane, Look.HOT)
			fx.say(center + Vector2(0.0, -40.0), "TOO EARLY", Look.HOT, 52, &"display")
			fx.kick(8.0)
			snd(&"bad", 1.2, -3.0)
		&"lost":
			fx.say(center + Vector2(0.0, -40.0), "MISSED", Look.DIM, 46)
			snd(&"miss", 0.8, -4.0)
		&"whiff", &"locked":
			snd(&"empty", 1.0, -6.0)


func _flash(lane: int, color: Color) -> void:
	_lane_flash[lane] = 1.0
	_lane_flash_color[lane] = color


func _process(delta: float) -> void:
	super(delta)
	for i in _lane_flash.size():
		_lane_flash[i] = maxf(0.0, _lane_flash[i] - delta * 3.0)


func _paint() -> void:
	var m := model as LastHitModel
	for lane in Tuning.LASTHIT_LANES:
		var rect := m.lane_rect(lane)
		var minion := m.in_lane(lane)
		var in_zone := not minion.is_empty() and float(minion["hp"]) <= Tuning.LASTHIT_KILL_ZONE
		var edge := Color(Look.INK, 0.1)
		var fill := Color(0.06, 0.09, 0.19, 0.7)
		if in_zone:
			edge = Color(Look.GOLD, 0.6 + 0.4 * Look.pulse(time, 18.0))
			fill = Color(0.2, 0.15, 0.03, 0.75)
		Look.panel(self, rect, fill, 24, edge, 4 if in_zone else 2)
		if _lane_flash[lane] > 0.0:
			Look.panel(self, rect, Color(_lane_flash_color[lane], 0.3 * _lane_flash[lane]), 24)

		# The bar: a track with the gold zone marked at the bottom.
		var bar := Rect2(rect.get_center().x - BAR_WIDTH * 0.5, rect.position.y + 150.0, BAR_WIDTH, rect.size.y - 250.0)
		Look.panel(self, bar, Color(1, 1, 1, 0.07), 18)
		var zone_h := bar.size.y * Tuning.LASTHIT_KILL_ZONE
		Look.panel(self, Rect2(bar.position.x, bar.end.y - zone_h, bar.size.x, zone_h), Color(Look.GOLD, 0.2), 18)
		draw_line(Vector2(bar.position.x - 16.0, bar.end.y - zone_h), Vector2(bar.end.x + 16.0, bar.end.y - zone_h), Color(Look.GOLD, 0.75), 4.0)

		if minion.is_empty():
			Look.text_c(self, &"ui", rect.get_center() + Vector2(0.0, -rect.size.y * 0.5 + 84.0), "LANE %d" % (lane + 1), 36, Color(Look.INK, 0.2))
			continue

		var hp := float(minion["hp"])
		var h := maxf(bar.size.y * hp, 10.0)
		var color := Look.GOLD if in_zone else Color("9FB6E8")
		Look.panel(self, Rect2(bar.position.x, bar.end.y - h, bar.size.x, h), color, 18)
		if in_zone:
			Look.glow(self, Vector2(bar.get_center().x, bar.end.y - h * 0.5), 240.0, Color(Look.GOLD, 0.3))
			Look.text_c(self, &"display", Vector2(rect.get_center().x, rect.end.y - 52.0), "NOW!", 70, Look.GOLD)
		# The thing being hit: a small red diamond that shivers as it weakens.
		var wobble := Vector2(sin(time * 40.0), cos(time * 33.0)) * (1.0 - hp) * 5.0
		_enemy(Vector2(rect.get_center().x, rect.position.y + 84.0) + wobble, 44.0)

	if m.is_locked() and not m.done:
		var w := 520.0
		var rect := Rect2(model.field.get_center().x - w * 0.5, model.field.position.y + 6.0, w, 54.0)
		Look.panel(self, rect, Color(Look.HOT, 0.22), 27, Color(Look.HOT, 0.7), 2)
		Look.text_c(self, &"ui", rect.get_center(), "ATTACK RECOVERING", 34, Look.HOT)
