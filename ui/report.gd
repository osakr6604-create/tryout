class_name Report
extends Node2D
## The scouting report: the payoff of the run. It reveals in a fixed order
## (attributes, overall, grade stamp, role, note) so the crowd gets a small
## show, then stays up until the next player clicks or the booth timer resets.

const RADAR_CENTER := Vector2(1056.0, 480.0)
const RADAR_RADIUS := 205.0
const NEXT_RECT := Rect2(1250.0, 916.0, 560.0, 110.0)
const STAMP_CENTER := Vector2(548.0, 470.0)

# When each part appears, in seconds.
const T_ATTRS := 0.35
const T_ATTR_STEP := 0.16
const T_OVERALL := 1.55
const T_GRADE := 2.5
const T_ROLE := 2.95
const T_NOTE := 3.3
const T_READY := 3.9

var t: float = 0.0
var hold_seconds: float = 22.0

var _open: bool = false
var _tag: String = ""
var _total: int = 0
var _grade: String = ""
var _role: String = ""
var _note: String = ""
var _attrs: Array = []
var _results: Array[DrillResult] = []
var _place: int = 0
var _of: int = 0
var _qr: Array = []
var _stamped: bool = false
var _ticked: int = 0
var _fx: Fx


func _ready() -> void:
	visible = false
	_fx = Fx.new()
	_fx.z_index = 5
	add_child(_fx)


func open(session: Session, entry: Dictionary, place: int, of_total: int) -> void:
	_tag = str(entry.get("tag", ""))
	_total = session.total()
	_grade = session.grade()
	_role = session.role()
	_note = session.note()
	_attrs = session.attribute_list()
	_results = session.results.duplicate()
	_place = place
	_of = of_total
	_qr = []
	if Config.show_qr and Config.card_url != "":
		_qr = QR.encode(CardLink.build(Config.card_url, _tag, _total, _grade, _role, _attrs))
	hold_seconds = maxf(Config.idle_seconds, T_READY + 4.0)
	t = 0.0
	_stamped = false
	_ticked = 0
	_fx.clear()
	_open = true
	visible = true
	Sfx.play(&"reveal")


func close() -> void:
	_open = false
	visible = false


func ready_for_next() -> bool:
	return _open and t >= T_READY


func expired() -> bool:
	return _open and t >= hold_seconds


func next_hit(pos: Vector2) -> bool:
	return ready_for_next() and NEXT_RECT.grow(20.0).has_point(pos)


func _process(delta: float) -> void:
	if not _open:
		return
	t += delta
	# One tick per attribute as it fills in.
	var shown := clampi(int((t - T_ATTRS) / T_ATTR_STEP) + 1, 0, 6) if t >= T_ATTRS else 0
	if shown > _ticked:
		_ticked = shown
		Sfx.play(&"tick", 0.9 + float(shown) * 0.1)
	if not _stamped and t >= T_GRADE:
		_stamped = true
		_fx.kick(16.0)
		_fx.burst(STAMP_CENTER, Look.grade_color(_grade), 40, 900.0, 10.0)
		_fx.ring(STAMP_CENTER, Look.grade_color(_grade), 60.0, 380.0, 0.5, 10.0)
		Sfx.play(&"stamp", 0.75)
		if _total >= 6800:
			Sfx.play(&"cheer")
	position = _fx.offset()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-40, -40, 2000, 1160), Color(0, 0, 0, 0.42))
	_draw_identity()
	_draw_radar()
	_draw_drills()
	_draw_footer()


func _draw_identity() -> void:
	Look.text(self, &"ui", Vector2(112.0, 112.0), "SCOUTING REPORT", 44, Look.accent())
	draw_line(Vector2(112.0, 128.0), Vector2(700.0, 128.0), Color(Look.accent(), 0.7), 4.0)
	var tag_size := 150
	while tag_size > 70 and Look.measure(&"display", _tag, tag_size).x > 640.0:
		tag_size -= 6
	Look.text(self, &"display", Vector2(108.0, 280.0), _tag, tag_size, Look.INK)

	# Overall: a two digit number that counts up.
	if t >= T_OVERALL:
		var k := Look.ease_out((t - T_OVERALL) / 0.8)
		var shown := int(round(float(Rating.overall(_total)) * k))
		Look.text(self, &"ui", Vector2(114.0, 372.0), "OVERALL", 38, Look.DIM)
		Look.text(self, &"monox", Vector2(104.0, 540.0), "%02d" % shown, 200, Look.INK)
		Look.text(self, &"ui", Vector2(114.0, 606.0), "SCORE", 38, Look.DIM)
		Look.text(self, &"monox", Vector2(108.0, 690.0), Rating.with_commas(int(round(float(_total) * k))), 84, Look.GOLD)

	# The grade, stamped on at an angle.
	if t >= T_GRADE:
		var pop := Look.ease_back(clampf((t - T_GRADE) / 0.22, 0.0, 1.0))
		var color := Look.grade_color(_grade)
		draw_set_transform(STAMP_CENTER, -0.16, Vector2(pop, pop) * lerpf(1.7, 1.0, pop))
		Look.panel(self, Rect2(-128.0, -128.0, 256.0, 256.0), Color(color, 0.14), 36, color, 9)
		Look.text_c(self, &"display", Vector2(0.0, -10.0), _grade, 200 if _grade.length() == 1 else 156, color)
		Look.text_c(self, &"ui", Vector2(0.0, 94.0), "GRADE", 30, color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if t >= T_ROLE:
		var pop := Look.ease_back(clampf((t - T_ROLE) / 0.2, 0.0, 1.0))
		var w := Look.measure(&"display", _role, 60).x + 230.0
		var rect := Rect2(108.0, 730.0, w * pop, 104.0)
		Look.panel(self, rect, Look.accent(), 22, Color(Look.INK, 0.9), 3, 0.14)
		if pop > 0.9:
			Look.text(self, &"ui", Vector2(138.0, 770.0), "ROLE FIT", 28, Color(Look.BG, 0.75))
			Look.text(self, &"display", Vector2(136.0, 824.0), _role, 60, Look.BG)
			if _place > 0:
				Look.text_r(self, &"monox", Vector2(rect.end.x - 26.0, 800.0), "#%d" % _place, 56, Look.BG)
				Look.text_r(self, &"ui", Vector2(rect.end.x - 26.0, 826.0), "OF %d TODAY" % _of, 22, Color(Look.BG, 0.75))


func _draw_radar() -> void:
	var names := Rating.ATTRS
	# Web.
	for ring_i in range(1, 5):
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(RADAR_CENTER + Vector2.from_angle(-PI * 0.5 + TAU * float(i % 6) / 6.0) * RADAR_RADIUS * float(ring_i) / 4.0)
		draw_polyline(pts, Color(Look.INK, 0.1 if ring_i < 4 else 0.3), 2.0, true)
	var shape := PackedVector2Array()
	for i in 6:
		var dir := Vector2.from_angle(-PI * 0.5 + TAU * float(i) / 6.0)
		draw_line(RADAR_CENTER, RADAR_CENTER + dir * RADAR_RADIUS, Color(Look.INK, 0.1), 2.0)
		var at := T_ATTRS + float(i) * T_ATTR_STEP
		var k := Look.ease_out((t - at) / 0.45) if t >= at else 0.0
		var value := float(_attrs[i]) if i < _attrs.size() else 0.0
		shape.append(RADAR_CENTER + dir * RADAR_RADIUS * maxf(0.04, value / 99.0 * k))
		# Label and number at each corner.
		var label_at := RADAR_CENTER + dir * (RADAR_RADIUS + 64.0)
		var alpha := clampf((t - at) / 0.25, 0.0, 1.0) if t >= at else 0.0
		Look.text_c(self, &"ui", label_at + Vector2(0.0, -20.0), String(names[i]), 32, Color(Look.DIM, alpha))
		Look.text_c(self, &"monox", label_at + Vector2(0.0, 22.0), str(int(round(value * k))), 46, Color(Look.score_color(value), alpha))
	draw_colored_polygon(shape, Color(Look.accent(), 0.3))
	shape.append(shape[0])
	draw_polyline(shape, Look.accent(), 5.0, true)
	for i in 6:
		Look.disc(self, shape[i], 8.0, Look.INK)


func _draw_drills() -> void:
	var x := 1360.0
	var w := 450.0
	Look.text(self, &"ui", Vector2(x, 112.0), "DRILL BY DRILL", 44, Look.accent())
	draw_line(Vector2(x, 128.0), Vector2(x + w, 128.0), Color(Look.accent(), 0.7), 4.0)
	for i in _results.size():
		var at := 0.3 + float(i) * 0.12
		if t < at:
			continue
		var k := Look.ease_out((t - at) / 0.4)
		var r := _results[i]
		var y := 182.0 + float(i) * 90.0
		Look.text(self, &"head", Vector2(x, y), r.title, 36, Color(Look.INK, k))
		Look.text_r(self, &"monox", Vector2(x + w, y), str(int(round(r.score * k))), 36, Color(Look.score_color(r.score), k))
		Look.bar(self, Rect2(x, y + 10.0, w, 9.0), r.score / 100.0 * k, Look.score_color(r.score))
		Look.text(self, &"body", Vector2(x, y + 46.0), r.headline, 25, Color(Look.DIM, k))


func _draw_footer() -> void:
	if t >= T_NOTE:
		# The note types itself out.
		var chars := int((t - T_NOTE) * 60.0)
		var shown := _note.substr(0, chars)
		Look.text(self, &"ui", Vector2(112.0, 896.0), "SCOUT'S NOTE", 30, Look.accent())
		Look.paragraph(self, &"head", Vector2(112.0, 906.0), 640.0, shown, 40, Look.INK)

	if t >= T_READY and not _qr.is_empty():
		var side := 200.0
		var origin := Vector2(800.0, 836.0)
		_draw_qr(Rect2(origin, Vector2(side, side)))
		Look.text(self, &"ui", origin + Vector2(side + 24.0, 70.0), "SCAN TO KEEP", 34, Look.INK)
		Look.text(self, &"ui", origin + Vector2(side + 24.0, 112.0), "YOUR CARD", 34, Look.INK)
		Look.text(self, &"body", origin + Vector2(side + 24.0, 152.0), "No app. No sign-up.", 26, Look.DIM)

	if t >= T_READY:
		var beat := Look.pulse(t, 3.4)
		Look.panel(self, NEXT_RECT.grow(4.0 * beat), Look.accent(), 26, Color(Look.INK, 0.9), 3, 0.12)
		Look.text_c(self, &"display", NEXT_RECT.get_center() + Vector2(0.0, -12.0), "NEXT PLAYER", 60, Look.BG)
		Look.text_c(self, &"ui", NEXT_RECT.get_center() + Vector2(0.0, 32.0), "CLICK TO START", 30, Color(Look.BG, 0.8))
		var left := 1.0 - clampf((t - T_READY) / maxf(hold_seconds - T_READY, 0.1), 0.0, 1.0)
		Look.bar(self, Rect2(NEXT_RECT.position.x, NEXT_RECT.end.y + 14.0, NEXT_RECT.size.x, 8.0), left, Color(Look.INK, 0.6))


func _draw_qr(rect: Rect2) -> void:
	var n := _qr.size()
	if n == 0:
		return
	var quiet := 2
	var cell := rect.size.x / float(n + quiet * 2)
	Look.panel(self, rect, Look.INK, 10)
	for y in n:
		var row: PackedByteArray = _qr[y]
		for x in n:
			if row[x] != 0:
				draw_rect(Rect2(rect.position + Vector2(float(x + quiet), float(y + quiet)) * cell, Vector2(cell + 0.5, cell + 0.5)), Look.BG)
