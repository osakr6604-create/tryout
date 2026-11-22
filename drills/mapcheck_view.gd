class_name MapCheckView
extends DrillView

var _lit_seen: int = 0
var _lit_at: Dictionary = {}      ## cell -> when it lit, for the ping ripple
var _picked_at: Dictionary = {}   ## cell -> when it was clicked
var _revealed_at: float = -1.0


func mood() -> Color:
	return Look.GOOD


func crosshair() -> StringName:
	return &"dot"


func _on_event(e: Dictionary) -> void:
	var m := model as MapCheckModel
	match e["type"]:
		&"recall":
			snd(&"go", 0.8)
		&"correct":
			var c := m.cell_rect(int(e["cell"])).get_center()
			_picked_at[int(e["cell"])] = time
			fx.burst(c, Look.GOOD, 14, 380.0)
			fx.ring(c, Look.GOOD, 30.0, 110.0, 0.3)
			snd(&"good", 1.0 + float(int(e["count"])) * 0.08)
		&"wrong":
			_picked_at[int(e["cell"])] = time
			fx.kick(6.0)
			snd(&"bad", 1.3, -4.0)
		&"reveal":
			_revealed_at = time


func _process(delta: float) -> void:
	super(delta)
	if model == null:
		return
	# A blip for each ping as it lights.
	var lit := (model as MapCheckModel).lit_cells()
	if lit.size() > _lit_seen:
		for i in range(_lit_seen, lit.size()):
			_lit_at[lit[i]] = time
			snd(&"ping", 1.0 + float(i) * 0.09)
		_lit_seen = lit.size()


func _paint() -> void:
	var m := model as MapCheckModel
	var g := m.grid_rect()
	var step := g.size.x / float(Tuning.MAP_GRID)

	Look.panel(self, g.grow(18.0), Color(0.03, 0.08, 0.1, 0.9), 26, Color(Look.GOOD, 0.3), 3)
	for i in range(1, Tuning.MAP_GRID):
		var o := float(i) * step
		draw_line(g.position + Vector2(o, 0.0), g.position + Vector2(o, g.size.y), Color(Look.GOOD, 0.14), 2.0)
		draw_line(g.position + Vector2(0.0, o), g.position + Vector2(g.size.x, o), Color(Look.GOOD, 0.14), 2.0)
	# Radar rings and a sweep while the pings are showing.
	var center := g.get_center()
	for i in 3:
		Look.ring(self, center, g.size.x * (0.17 + 0.16 * float(i)), 2.0, Color(Look.GOOD, 0.1))
	if m.phase == MapCheckModel.Phase.SHOW and not frozen:
		var angle := time * 3.4
		for k in 14:
			var a := angle - float(k) * 0.05
			draw_line(center, center + Vector2.from_angle(a) * g.size.x * 0.49, Color(Look.GOOD, 0.3 * (1.0 - float(k) / 14.0)), 5.0, true)

	var lit := m.lit_cells()
	for cell in Tuning.MAP_GRID * Tuning.MAP_GRID:
		var rect := m.cell_rect(cell).grow(-7.0)
		var c := rect.get_center()
		if lit.has(cell):
			var age := time - float(_lit_at.get(cell, time))
			Look.panel(self, rect, Color(Look.HOT, 0.22), 14, Color(Look.HOT, 0.7), 3)
			_enemy(c, step * 0.27, _pop(age, 0.12))
			if age < 0.5:
				Look.ring(self, c, lerpf(20.0, step * 0.75, age / 0.5), 5.0, Color(Look.HOT, 1.0 - age / 0.5))
		elif m.found.has(cell):
			var pop := _pop(time - float(_picked_at.get(cell, 0.0)), 0.14)
			Look.panel(self, rect, Color(Look.GOOD, 0.3), 14, Look.GOOD, 4)
			var s := step * 0.2 * pop
			draw_polyline(PackedVector2Array([c + Vector2(-s, 0.0), c + Vector2(-s * 0.25, s * 0.7), c + Vector2(s, -s * 0.7)]), Look.GOOD, 10.0, true)
		elif m.wrong.has(cell):
			Look.panel(self, rect, Color(Look.HOT, 0.2), 14, Color(Look.HOT, 0.8), 4)
			var s := step * 0.17
			draw_line(c + Vector2(-s, -s), c + Vector2(s, s), Look.HOT, 9.0, true)
			draw_line(c + Vector2(-s, s), c + Vector2(s, -s), Look.HOT, 9.0, true)
		elif m.phase == MapCheckModel.Phase.RECALL and m.cell_at(m.pointer) == cell:
			Look.panel(self, rect, Color(Look.INK, 0.12), 14, Color(Look.INK, 0.6), 3)
		elif _revealed_at >= 0.0 and m.cells.has(cell):
			# The ones that were missed, shown at the end.
			Look.diamond_outline(self, c, step * 0.24, 5.0, Color(Look.HOT, 0.8))

	# What to do right now, to the left of the grid.
	var label_at := Vector2(g.position.x - 290.0, center.y)
	if m.phase == MapCheckModel.Phase.SHOW:
		Look.text_c(self, &"display", label_at + Vector2(0.0, -40.0), "MEMORIZE", 84, Look.INK)
		var left := 1.0 - clampf(m.t / Tuning.MAP_SHOW_UNTIL, 0.0, 1.0)
		Look.bar(self, Rect2(label_at.x - 160.0, label_at.y + 30.0, 320.0, 16.0), left, Look.HOT)
	else:
		Look.text_c(self, &"display", label_at + Vector2(0.0, -70.0), "WHERE", 84, Look.GOOD)
		Look.text_c(self, &"display", label_at + Vector2(0.0, 10.0), "WERE THEY?", 84, Look.GOOD)
		for i in Tuning.MAP_PINGS:
			var dot := label_at + Vector2((float(i) - float(Tuning.MAP_PINGS - 1) * 0.5) * 52.0, 100.0)
			if i < m.picks:
				Look.disc(self, dot, 15.0, Look.GOOD if i < m.found.size() + m.wrong.size() else Look.DIM)
			else:
				Look.ring(self, dot, 15.0, 4.0, Color(Look.INK, 0.5))
