class_name MapCheckModel
extends DrillModel
## MAP CHECK: five pings light up on a radar grid, then vanish. Click the cells
## where they were. It measures the glance-and-remember habit good players
## build for the minimap.

enum Phase { SHOW, RECALL, END }

var phase: Phase = Phase.SHOW
var cells: Array[int] = []        ## the pinged cells, in the order they light up
var found: Array[int] = []
var wrong: Array[int] = []
var picks: int = 0
var recall_seconds: float = 0.0

var _recall_from: float = 0.0
var _end_at: float = 0.0


func _setup() -> void:
	id = &"mapcheck"
	title = "MAP CHECK"
	hint = "Remember the pings, then click them"
	duration = Tuning.MAP_SECONDS
	phase = Phase.SHOW
	found.clear()
	wrong.clear()
	picks = 0
	recall_seconds = 0.0
	var all: Array = []
	for i in Tuning.MAP_GRID * Tuning.MAP_GRID:
		all.append(i)
	all = shuffled(all)
	cells.clear()
	for i in Tuning.MAP_PINGS:
		cells.append(int(all[i]))


func grid_rect() -> Rect2:
	var side := minf(field.size.y - 30.0, 680.0)
	return Rect2(field.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))


func cell_rect(cell: int) -> Rect2:
	var g := grid_rect()
	var step := g.size.x / float(Tuning.MAP_GRID)
	var col := cell % Tuning.MAP_GRID
	var row := cell / Tuning.MAP_GRID
	return Rect2(g.position + Vector2(col, row) * step, Vector2(step, step))


func cell_at(pos: Vector2) -> int:
	var g := grid_rect()
	if not g.has_point(pos):
		return -1
	var step := g.size.x / float(Tuning.MAP_GRID)
	var col := clampi(int((pos.x - g.position.x) / step), 0, Tuning.MAP_GRID - 1)
	var row := clampi(int((pos.y - g.position.y) / step), 0, Tuning.MAP_GRID - 1)
	return row * Tuning.MAP_GRID + col


## When ping [param i] lights up.
func ping_time(i: int) -> float:
	return Tuning.MAP_FIRST_PING + float(i) * Tuning.MAP_PING_STEP


## Cells that are lit right now (only while the pings are being shown).
func lit_cells() -> Array[int]:
	var out: Array[int] = []
	if phase != Phase.SHOW:
		return out
	for i in cells.size():
		if t >= ping_time(i):
			out.append(cells[i])
	return out


func _advance(_dt: float) -> void:
	match phase:
		Phase.SHOW:
			if t >= Tuning.MAP_SHOW_UNTIL:
				phase = Phase.RECALL
				_recall_from = t
				emit(&"recall")
		Phase.RECALL:
			recall_seconds = t - _recall_from
		Phase.END:
			if t >= _end_at:
				done = true


func _press(pos: Vector2) -> void:
	if phase != Phase.RECALL:
		return
	var cell := cell_at(pos)
	if cell < 0 or found.has(cell) or wrong.has(cell):
		return
	picks += 1
	if cells.has(cell):
		found.append(cell)
		emit(&"correct", {"cell": cell, "count": found.size()})
	else:
		wrong.append(cell)
		emit(&"wrong", {"cell": cell})
	if picks >= Tuning.MAP_PINGS:
		recall_seconds = t - _recall_from
		phase = Phase.END
		_end_at = t + 0.55
		emit(&"reveal")


func _finish() -> void:
	if phase == Phase.RECALL:
		recall_seconds = t - _recall_from
		emit(&"reveal")


func live_stat() -> String:
	if phase == Phase.SHOW:
		return "WATCH"
	return "%d / %d FOUND" % [found.size(), Tuning.MAP_PINGS]


func result() -> DrillResult:
	var headline := "%d of %d pings" % [found.size(), Tuning.MAP_PINGS]
	return DrillResult.make(id, title, Tuning.mapcheck_score(found.size(), recall_seconds), headline, {
		"correct": found.size(),
		"wrong": wrong.size(),
		"recall_seconds": recall_seconds,
	})
