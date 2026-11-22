class_name SkillshotView
extends DrillView

var _spawned_at: float = 0.0


func mood() -> Color:
	return Look.PINK


func _on_event(e: Dictionary) -> void:
	match e["type"]:
		&"spawn":
			_spawned_at = time
			snd(&"pop", 1.0, -6.0)
		&"shot":
			fx.spray(e["pos"], e["dir"], Look.accent(), 8)
			snd(&"shot")
		&"hit":
			fx.burst(e["pos"], Look.HOT, 26, 680.0, 9.0)
			fx.ring(e["pos"], Look.INK, 40.0, 200.0, 0.42)
			fx.say((e["pos"] as Vector2) + Vector2(0.0, -90.0), "HIT!", Look.GOLD, 70, &"display")
			fx.kick(9.0)
			snd(&"boom", 1.0 + float(int(e["count"])) * 0.05)
		&"escaped":
			fx.say((e["pos"] as Vector2) + Vector2(0.0, -80.0), "GOT AWAY", Look.DIM, 44)
			snd(&"miss", 0.85, -4.0)
		&"juke":
			fx.say((e["pos"] as Vector2) + Vector2(0.0, -86.0), "JUKE!", Look.PINK, 48, &"display")
			snd(&"slip", 1.3)


## Where a shot fired now would meet the runner.
func _meeting_point(m: SkillshotModel) -> Vector2:
	var p: Vector2 = m.runner["pos"]
	var v: Vector2 = m.runner["vel"]
	var aim := p
	for i in 5:
		aim = p + v * (aim.distance_to(m.caster) / Tuning.SKILL_SHOT_SPEED)
	return aim


func _paint() -> void:
	var m := model as SkillshotModel

	# Aim line from the caster through the pointer.
	var dir := m.pointer - m.caster
	if dir.y < -20.0:
		var far := m.caster + dir.normalized() * 1400.0
		draw_dashed_line(m.caster, far, Color(Look.accent(), 0.22), 3.0, 18.0, true)

	# The caster, with its cooldown as a ring.
	Look.glow(self, m.caster, 110.0, Color(Look.accent(), 0.3))
	Look.diamond(self, m.caster, 34.0, Color(Look.accent().darkened(0.5), 0.95))
	Look.diamond_outline(self, m.caster, 31.0, 5.0, Look.accent())
	var ready := 1.0 - m.cooldown_left() / Tuning.SKILL_COOLDOWN
	Look.arc(self, m.caster, 52.0, 6.0, ready, Color(Look.GOOD if ready >= 1.0 else Look.GOLD, 0.9))

	if not m.runner.is_empty():
		var pos: Vector2 = m.runner["pos"]
		var vel: Vector2 = m.runner["vel"]
		# Speed streaks behind the runner.
		var back := -vel.normalized()
		for i in 5:
			var off := back * (30.0 + float(i) * 26.0)
			Look.disc(self, pos + off, Tuning.SKILL_TARGET_RADIUS * (0.7 - float(i) * 0.1), Color(Look.HOT, 0.16 - float(i) * 0.025))
		_enemy(pos, Tuning.SKILL_TARGET_RADIUS, _pop(time - _spawned_at, 0.1))
		var left := 1.0 - clampf((m.t - float(m.runner["born"])) / Tuning.SKILL_LIFE, 0.0, 1.0)
		Look.arc(self, pos, Tuning.SKILL_TARGET_RADIUS + 22.0, 6.0, left, Color(Look.HOT, 0.8))
		# The first runner shows where to aim, which teaches the lead without a tutorial.
		if m.index == 0:
			var meet := _meeting_point(m)
			var blink := 0.55 + 0.45 * Look.pulse(time, 10.0)
			Look.ring(self, meet, 40.0, 5.0, Color(Look.GOLD, blink))
			draw_dashed_line(pos, meet, Color(Look.GOLD, 0.5), 3.0, 12.0, true)
			Look.text_c(self, &"ui", meet + Vector2(0.0, -70.0), "AIM HERE", 38, Color(Look.GOLD, blink))

	for s in m.shots:
		var pos: Vector2 = s["pos"]
		var tail := pos - (s["vel"] as Vector2).normalized() * 70.0
		draw_line(tail, pos, Color(Look.accent(), 0.55), 9.0, true)
		Look.glow(self, pos, 56.0, Color(Look.accent(), 0.6))
		Look.disc(self, pos, Tuning.SKILL_SHOT_RADIUS, Look.INK)
