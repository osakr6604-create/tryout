class_name BoardScreen
extends Node2D
## The full leaderboard screen for a second monitor facing the crowd: the top
## ten, what the current player is doing right now, and the last report.
## It only reads from Board, so it updates the moment a run ends.

var board: BoardView
var backdrop: Backdrop

var _time: float = 0.0
var _scope_for: float = 0.0


func _ready() -> void:
	backdrop = Backdrop.new()
	backdrop.show_behind_parent = true
	add_child(backdrop)
	board = BoardView.new()
	board.rect = Rect2(70.0, 200.0, 1190.0, 810.0)
	board.rows = 10
	add_child(board)
	Board.live_changed.connect(queue_redraw)


func _process(delta: float) -> void:
	_time += delta
	# Swap between today and all-time when both have something to show.
	_scope_for += delta
	if _scope_for > 14.0:
		_scope_for = 0.0
		var has_older := Board.data.entries.size() > Board.count_today()
		if board.scope == Leaderboard.Scope.TODAY and has_older:
			board.scope = Leaderboard.Scope.ALL
			board.title = "ALL-TIME TOP PROSPECTS"
		else:
			board.scope = Leaderboard.Scope.TODAY
			board.title = "TODAY'S TOP PROSPECTS"
	queue_redraw()


func _draw() -> void:
	Look.text(self, &"display", Vector2(70.0, 150.0), "TRYOUT", 150, Look.INK)
	var sub := Config.event_name.to_upper() if Config.event_name != "" else "THINK YOU COULD GO PRO?"
	Look.text(self, &"head", Vector2(480.0, 104.0), sub, 60, Look.accent())
	Look.text(self, &"body", Vector2(482.0, 150.0), "60 seconds. 8 drills. One scouting report.", 40, Look.DIM)

	var side := Rect2(1300.0, 200.0, 550.0, 810.0)
	_draw_live(Rect2(side.position, Vector2(side.size.x, 380.0)))
	_draw_last(Rect2(side.position + Vector2(0.0, 410.0), Vector2(side.size.x, 400.0)))


func _draw_live(rect: Rect2) -> void:
	Look.panel(self, rect, Look.PANEL, 28, Look.PANEL_EDGE, 2)
	var x := rect.position.x + 34.0
	var live := Board.live
	var playing := str(live.get("state", "idle")) == "playing"
	Look.disc(self, Vector2(x + 12.0, rect.position.y + 52.0), 11.0, Color(Look.HOT if playing else Look.FAINT, 0.5 + 0.5 * Look.pulse(_time, 5.0)))
	Look.text(self, &"display", Vector2(x + 38.0, rect.position.y + 72.0), "NOW PLAYING" if playing else "STATION OPEN", 58, Look.INK)
	if not playing:
		Look.text(self, &"head", Vector2(x, rect.position.y + 190.0), "YOU'RE UP.", 96, Look.accent())
		Look.text(self, &"body", Vector2(x, rect.position.y + 250.0), "Step up and click to start.", 42, Look.DIM)
		var best := Board.data.best_score(Leaderboard.Scope.TODAY, Board.today())
		if best > 0:
			Look.text(self, &"body", Vector2(x, rect.position.y + 322.0), "Score to beat today: %s" % Rating.with_commas(best), 42, Look.GOLD)
		return
	var index := int(live.get("drill", 0))
	Look.text(self, &"head", Vector2(x, rect.position.y + 158.0), "DRILL %d / %d: %s" % [index + 1, Session.drill_count(), str(live.get("title", ""))], 50, Look.accent())
	for i in Session.drill_count():
		var pip := Rect2(x + float(i) * 58.0, rect.position.y + 184.0, 46.0, 16.0)
		Look.panel(self, pip, Look.accent() if i < index else (Look.INK if i == index else Look.FAINT), 8)
	Look.text(self, &"ui", Vector2(x, rect.position.y + 262.0), "SCORE SO FAR", 34, Look.DIM)
	Look.text(self, &"monox", Vector2(x, rect.position.y + 344.0), Rating.with_commas(int(live.get("score", 0))), 92, Look.INK)
	var best := Board.data.best_score(Leaderboard.Scope.TODAY, Board.today())
	if best > 0:
		Look.text_r(self, &"body", Vector2(rect.end.x - 34.0, rect.position.y + 340.0), "to beat: %s" % Rating.with_commas(best), 36, Look.GOLD)


func _draw_last(rect: Rect2) -> void:
	Look.panel(self, rect, Look.PANEL, 28, Look.PANEL_EDGE, 2)
	var x := rect.position.x + 34.0
	Look.text(self, &"display", Vector2(x, rect.position.y + 72.0), "LATEST REPORT", 58, Look.INK)
	var e := Board.last_entry
	if e.is_empty():
		var all := Board.top_today(1)
		if not all.is_empty():
			e = all[0]
	if e.is_empty():
		Look.text(self, &"body", Vector2(x, rect.position.y + 180.0), "No reports yet today.", 42, Look.DIM)
		return
	var grade := str(e["grade"])
	Look.text(self, &"display", Vector2(x, rect.position.y + 190.0), str(e["tag"]), 100, Look.INK)
	Look.text(self, &"head", Vector2(x, rect.position.y + 250.0), "%s    %s PTS" % [str(e["role"]), Rating.with_commas(int(e["score"]))], 46, Look.accent())
	Look.text_r(self, &"display", Vector2(rect.end.x - 40.0, rect.position.y + 200.0), grade, 150, Look.grade_color(grade))
	var attrs: Array = e["attrs"]
	for i in mini(6, attrs.size()):
		var col := i % 2
		var row := i / 2
		var at := Vector2(x + float(col) * 250.0, rect.position.y + 300.0 + float(row) * 34.0)
		Look.text(self, &"ui", at, String(Rating.ATTRS[i]), 26, Look.DIM)
		Look.text_r(self, &"mono", at + Vector2(220.0, 0.0), str(int(attrs[i])), 28, Look.score_color(float(attrs[i])))
