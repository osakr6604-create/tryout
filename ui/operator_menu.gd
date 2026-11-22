class_name OperatorMenu
extends Node2D
## The booth staff menu. Opens with F1 or Esc. Everything a booth needs during
## a long day without touching a file: sound, screens, export, resets.
## Destructive buttons need a second click within a few seconds.

signal closed
signal display_changed
signal quit_requested

const WIDTH := 980.0
const ROW := 74.0

var is_open: bool = false

var _buttons: Array[Dictionary] = []    ## {rect, id}
var _confirm: String = ""
var _confirm_left: float = 0.0
var _message: String = ""
var _message_left: float = 0.0
var _hover: Vector2 = Vector2.ZERO


func _ready() -> void:
	visible = false
	z_index = 50


func open() -> void:
	is_open = true
	visible = true
	_confirm = ""
	_message = ""
	queue_redraw()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	Config.save()
	closed.emit()


func hover(pos: Vector2) -> void:
	_hover = pos


func _items() -> Array[Dictionary]:
	var items: Array[Dictionary] = [
		{"id": "resume", "label": "BACK TO THE GAME", "value": ""},
		{"id": "sound", "label": "SOUND", "value": "%d%%" % int(round(Config.master_volume * 100.0))},
		{"id": "music", "label": "MUSIC", "value": "%d%%" % int(round(Config.music_volume * 100.0))},
		{"id": "fullscreen", "label": "FULL SCREEN", "value": "ON" if Config.fullscreen else "OFF"},
		{"id": "board", "label": "LEADERBOARD WINDOW", "value": _board_label()},
		{"id": "timing", "label": "LOW LATENCY MODE", "value": "ON" if Config.low_latency else "OFF"},
		{"id": "export", "label": "EXPORT SCORES TO A SPREADSHEET", "value": ""},
		{"id": "reset_today", "label": "CLEAR TODAY'S BOARD", "value": "%d scores" % Board.count_today(), "danger": true},
		{"id": "reset_all", "label": "CLEAR EVERY SCORE", "value": "%d scores" % Board.data.entries.size(), "danger": true},
	]
	if not Config.kiosk and not OS.has_feature("web"):
		items.append({"id": "quit", "label": "QUIT", "value": "", "danger": true})
	return items


func _board_label() -> String:
	match Config.board_screen:
		-2:
			return "OFF"
		-1:
			return "AUTO (2ND SCREEN)"
	return "SCREEN %d" % (Config.board_screen + 1)


func press(pos: Vector2) -> void:
	if not is_open:
		return
	for b in _buttons:
		if (b["rect"] as Rect2).has_point(pos):
			_do(str(b["id"]))
			return


func _needs_confirm(id: String) -> bool:
	return id in ["reset_today", "reset_all", "quit"]


func _do(id: String) -> void:
	if _needs_confirm(id) and _confirm != id:
		_confirm = id
		_confirm_left = 4.0
		Sfx.play(&"empty")
		queue_redraw()
		return
	_confirm = ""
	Sfx.play(&"tick")
	match id:
		"resume":
			close()
		"sound":
			Config.master_volume = _cycle(Config.master_volume, [1.0, 0.7, 0.4, 0.0])
			Sfx.apply_volume()
		"music":
			Config.music_volume = _cycle(Config.music_volume, [0.5, 0.25, 0.0, 0.8])
			Sfx.apply_volume()
		"fullscreen":
			Config.fullscreen = not Config.fullscreen
			display_changed.emit()
		"board":
			var screens := DisplayServer.get_screen_count()
			var next := Config.board_screen + 1
			if Config.board_screen == -2:
				next = -1
			elif next >= screens:
				next = -2
			Config.board_screen = next
			display_changed.emit()
		"timing":
			Config.low_latency = not Config.low_latency
			display_changed.emit()
		"export":
			var path := Board.export_csv()
			_say("Saved to %s" % path if path != "" else "Could not write the file")
		"reset_today":
			_say("Removed %d scores from today" % Board.reset_today())
		"reset_all":
			Board.reset_all()
			_say("The board is empty")
		"quit":
			quit_requested.emit()
	queue_redraw()


func _cycle(current: float, steps: Array) -> float:
	for i in steps.size():
		if absf(float(steps[i]) - current) < 0.05:
			return float(steps[(i + 1) % steps.size()])
	return float(steps[0])


func _say(text: String) -> void:
	_message = text
	_message_left = 6.0


func _process(delta: float) -> void:
	if not is_open:
		return
	if _confirm != "":
		_confirm_left -= delta
		if _confirm_left <= 0.0:
			_confirm = ""
	_message_left = maxf(0.0, _message_left - delta)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0, 0, 0, 0.72))
	var items := _items()
	var height := 160.0 + float(items.size()) * ROW + 64.0
	var panel := Rect2(960.0 - WIDTH * 0.5, 540.0 - height * 0.5, WIDTH, height)
	Look.panel(self, panel, Color(0.05, 0.08, 0.17, 0.98), 30, Color(Look.accent(), 0.7), 3)
	Look.text(self, &"display", panel.position + Vector2(44.0, 86.0), "BOOTH MENU", 76, Look.INK)
	var info := "Tryout %s" % str(ProjectSettings.get_setting("application/config/version"))
	Look.text_r(self, &"body", Vector2(panel.end.x - 44.0, panel.position.y + 60.0), info, 32, Look.DIM)
	Look.text_r(self, &"body", Vector2(panel.end.x - 44.0, panel.position.y + 98.0), "F1 or Esc closes this menu", 30, Look.DIM)

	_buttons.clear()
	for i in items.size():
		var item := items[i]
		var id := str(item["id"])
		var rect := Rect2(panel.position.x + 36.0, panel.position.y + 120.0 + float(i) * ROW, WIDTH - 72.0, ROW - 10.0)
		_buttons.append({"rect": rect, "id": id})
		var danger := bool(item.get("danger", false))
		var confirming := _confirm == id
		var over := rect.has_point(_hover)
		var fill := Color(1, 1, 1, 0.05)
		var edge := Color(1, 1, 1, 0.12)
		var ink := Look.INK
		if id == "resume":
			fill = Color(Look.accent(), 0.2)
			edge = Color(Look.accent(), 0.9)
		if danger:
			ink = Color("FF9A90")
		if confirming:
			fill = Color(Look.HOT, 0.55)
			edge = Look.INK
			ink = Look.INK
		if over:
			fill = fill.lightened(0.12)
			edge = Look.INK
		Look.panel(self, rect, fill, 16, edge, 2)
		var label := str(item["label"])
		if confirming:
			label = "CLICK AGAIN TO CONFIRM: " + label
		Look.text(self, &"head", rect.position + Vector2(26.0, 46.0), label, 40, ink)
		Look.text_r(self, &"mono", Vector2(rect.end.x - 26.0, rect.position.y + 44.0), str(item["value"]), 32, Look.accent())

	if _message_left > 0.0:
		Look.text_c(self, &"body", Vector2(960.0, panel.end.y - 34.0), _message, 28, Look.GOOD)
