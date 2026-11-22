class_name TrackView
extends DrillView

const TRAIL := 26

var _trail: Array[Vector2] = []
var _tick_in: float = 0.0
var _locked_for: float = 0.0


func crosshair() -> StringName:
	return &"ring"


func _on_event(e: Dictionary) -> void:
	match e["type"]:
		&"lock":
			snd(&"lock")
			fx.ring(e["pos"], Look.GOOD, 60.0, 110.0, 0.25, 5.0)
		&"slip":
			snd(&"slip")


func _process(delta: float) -> void:
	super(delta)
	if model == null or frozen:
		return
	var m := model as TrackModel
	_trail.append(m.pos)
	if _trail.size() > TRAIL:
		_trail.pop_front()
	# A soft tick while locked on, rising the longer the lock holds.
	if m.on_target and not m.done:
		_locked_for += delta
		_tick_in -= delta
		if _tick_in <= 0.0:
			_tick_in = 0.16
			snd(&"tick", 1.0 + minf(_locked_for, 3.0) * 0.22, -9.0)
	else:
		_locked_for = 0.0
		_tick_in = 0.0


func _paint() -> void:
	var m := model as TrackModel
	var color := Look.GOOD if m.on_target else Look.accent()
	for i in _trail.size():
		var k := float(i) / float(TRAIL)
		Look.disc(self, _trail[i], Tuning.TRACK_RADIUS * 0.34 * k, Color(color, 0.12 * k))
	Look.glow(self, m.pos, Tuning.TRACK_RADIUS * 2.8, Color(color, 0.4))
	Look.disc(self, m.pos, Tuning.TRACK_RADIUS, Color(color.darkened(0.6), 0.9))
	Look.ring(self, m.pos, Tuning.TRACK_RADIUS - 3.0, 7.0 if m.on_target else 5.0, color)
	Look.disc(self, m.pos, 9.0, Look.INK)
	# How the lock is going, as a ring that fills.
	Look.arc(self, m.pos, Tuning.TRACK_RADIUS + 14.0, 6.0, m.fraction(), Color(Look.GOLD, 0.9))
	if m.t < Tuning.TRACK_GRACE and not frozen:
		Look.text_c(self, &"ui", m.pos + Vector2(0.0, -Tuning.TRACK_RADIUS - 46.0), "GET ON IT", 40, Color(Look.INK, 0.8))
