class_name BoardView
extends Node2D
## Draws the leaderboard into a rectangle. Used small on the attract screen
## and full size on the second monitor.

var rect: Rect2 = Rect2(0, 0, 800, 600)
var rows: int = 10
var title: String = "TODAY'S TOP PROSPECTS"
var scope: Leaderboard.Scope = Leaderboard.Scope.TODAY
var highlight_id: int = -1
var show_roles: bool = true

var _time: float = 0.0
var _flash: float = 0.0


func _ready() -> void:
	Board.changed.connect(_on_changed)


func _on_changed() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 0.8)
	queue_redraw()


func _entries() -> Array[Dictionary]:
	if scope == Leaderboard.Scope.TODAY:
		return Board.top_today(rows)
	return Board.top_all(rows)


func _draw() -> void:
	Look.panel(self, rect, Look.PANEL, 28, Look.PANEL_EDGE, 2)
	var pad := 34.0
	var x0 := rect.position.x + pad
	var x1 := rect.end.x - pad
	var head_h := rect.size.y * 0.14
	var title_size := int(clampf(head_h * 0.62, 34.0, 84.0))
	Look.text(self, &"display", Vector2(x0, rect.position.y + head_h * 0.8), title, title_size, Look.INK)
	draw_line(Vector2(x0, rect.position.y + head_h + 4.0), Vector2(x1, rect.position.y + head_h + 4.0), Color(Look.accent(), 0.7), 4.0)

	var list := _entries()
	var top := rect.position.y + head_h + 18.0
	var row_h := (rect.end.y - 18.0 - top) / float(rows)
	if list.is_empty():
		Look.text_c(self, &"head", Vector2(rect.get_center().x, top + (rect.end.y - top) * 0.42), "NO SCORES YET", int(row_h * 0.9), Look.DIM)
		Look.text_c(self, &"body", Vector2(rect.get_center().x, top + (rect.end.y - top) * 0.42 + row_h * 0.9), "Be the first on the board.", int(row_h * 0.6), Look.FAINT.lightened(0.3))
		return

	var size := int(clampf(row_h * 0.62, 22.0, 64.0))
	var width := rect.size.x - pad * 2.0
	for i in list.size():
		var e := list[i]
		var y := top + float(i) * row_h
		var row := Rect2(x0 - 12.0, y + 3.0, width + 24.0, row_h - 6.0)
		var mine := int(e["id"]) == highlight_id
		var newest := not Board.last_entry.is_empty() and int(e["id"]) == int(Board.last_entry["id"]) and _flash > 0.0
		if mine or newest:
			var glow := 0.5 + 0.5 * Look.pulse(_time, 5.0)
			Look.panel(self, row, Color(Look.accent(), 0.16 + 0.1 * glow), 14, Color(Look.accent(), 0.9), 3)
		elif i % 2 == 0:
			Look.panel(self, row, Color(1, 1, 1, 0.035), 14)
		var base := y + row_h * 0.5 + float(size) * 0.34
		var rank_color := Look.GOLD if i == 0 else (Look.INK if i < 3 else Look.DIM)
		Look.text(self, &"monox", Vector2(x0, base), "%2d" % (i + 1), size, rank_color)
		Look.text(self, &"head", Vector2(x0 + width * 0.12, base), str(e["tag"]), size, Look.INK)
		if show_roles:
			Look.text(self, &"ui", Vector2(x0 + width * 0.47, base), str(e["role"]), int(float(size) * 0.68), Look.DIM)
		var grade := str(e["grade"])
		Look.text(self, &"display", Vector2(x0 + width * 0.73, base), grade, size, Look.grade_color(grade))
		Look.text_r(self, &"monox", Vector2(x1, base), Rating.with_commas(int(e["score"])), size, Look.INK)
