class_name TagEntry
extends Node2D
## Name entry after the run. Works with a real keyboard, with the mouse on the
## on-screen keys, or with a finger on a touch screen. It closes itself after a
## while so one distracted player cannot hold up the line.

signal submitted(raw: String)

const ROWS: Array[String] = ["1234567890", "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM_-"]
const KEY := Vector2(112.0, 92.0)
const GAP := 12.0
const KEYS_TOP := 470.0
const BOX := Rect2(510.0, 300.0, 900.0, 130.0)

var text: String = ""
var seconds_left: float = 0.0

var _time: float = 0.0
var _keys: Array[Dictionary] = []     ## {rect, label, action}
var _score: int = 0
var _grade: String = ""
var _place: int = 0
var _open: bool = false
var _pressed: String = ""
var _pressed_for: float = 0.0
var _hover: Vector2 = Vector2.ZERO


func _ready() -> void:
	visible = false
	_build_keys()


func _build_keys() -> void:
	_keys.clear()
	for r in ROWS.size():
		var row := ROWS[r]
		var width := float(row.length()) * KEY.x + float(row.length() - 1) * GAP
		var x := 960.0 - width * 0.5
		var y := KEYS_TOP + float(r) * (KEY.y + GAP)
		for i in row.length():
			_keys.append({"rect": Rect2(x + float(i) * (KEY.x + GAP), y, KEY.x, KEY.y), "label": row[i], "action": row[i]})
	var y2 := KEYS_TOP + float(ROWS.size()) * (KEY.y + GAP) + 8.0
	_keys.append({"rect": Rect2(960.0 - 560.0, y2, 360.0, KEY.y), "label": "DELETE", "action": "back"})
	_keys.append({"rect": Rect2(960.0 - 180.0, y2, 740.0, KEY.y), "label": "DONE", "action": "done"})


func open(score: int, grade: String, place: int) -> void:
	text = ""
	_score = score
	_grade = grade
	_place = place
	seconds_left = Tuning.TAG_SECONDS
	_time = 0.0
	_open = true
	visible = true


func close() -> void:
	_open = false
	visible = false


func hover(pos: Vector2) -> void:
	_hover = pos


## Where an on-screen key is: a letter or digit, "back" or "done".
func key_rect(action: String) -> Rect2:
	for k in _keys:
		if str(k["action"]) == action:
			return k["rect"]
	return Rect2()


func press(pos: Vector2) -> void:
	if not _open:
		return
	for k in _keys:
		if (k["rect"] as Rect2).has_point(pos):
			_apply(str(k["action"]))
			return


func key(event: InputEventKey) -> void:
	if not _open:
		return
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_apply("done")
		KEY_BACKSPACE, KEY_DELETE:
			_apply("back")
		_:
			if event.unicode > 32:
				var ch := NameFilter.clean(String.chr(event.unicode))
				if ch != "":
					_apply(ch)
			elif event.keycode == KEY_SPACE:
				_apply("_")


func _apply(action: String) -> void:
	_pressed = action
	_pressed_for = 0.12
	match action:
		"back":
			text = text.substr(0, text.length() - 1)
			Sfx.play(&"empty", 1.2, -6.0)
		"done":
			_finish()
		_:
			if text.length() < NameFilter.MAX_LENGTH:
				text += action
				seconds_left = maxf(seconds_left, 6.0)   # still typing: give a little more time
				Sfx.play(&"tick", 1.0 + float(text.length()) * 0.04, -3.0)


func _finish() -> void:
	if not _open:
		return
	_open = false
	Sfx.play(&"good")
	submitted.emit(text)


func _process(delta: float) -> void:
	if not _open:
		return
	_time += delta
	_pressed_for = maxf(0.0, _pressed_for - delta)
	seconds_left -= delta
	if seconds_left <= 0.0:
		_finish()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0, 0, 0, 0.5))
	Look.text_shadow_c(self, &"display", Vector2(960.0, 130.0), "ENTER YOUR TAG", 130, Look.INK)
	var summary := "SCORE %s    GRADE %s    #%d TODAY" % [Rating.with_commas(_score), _grade, _place]
	Look.text_c(self, &"mono", Vector2(960.0, 236.0), summary, 44, Look.accent())

	# The box being typed into.
	Look.panel(self, BOX, Look.PANEL, 26, Color(Look.accent(), 0.9), 4)
	var caret := "_" if fmod(_time, 0.9) < 0.5 and text.length() < NameFilter.MAX_LENGTH else ""
	if text == "":
		Look.text_c(self, &"monox", BOX.get_center(), "YOUR TAG" + caret, 84, Look.FAINT.lightened(0.15))
	else:
		Look.text_c(self, &"monox", BOX.get_center(), text + caret, 92, Look.INK)

	for k in _keys:
		var rect: Rect2 = k["rect"]
		var action := str(k["action"])
		var down := action == _pressed and _pressed_for > 0.0
		var over := rect.has_point(_hover)
		var fill := Color(1, 1, 1, 0.07)
		var edge := Color(1, 1, 1, 0.16)
		var ink := Look.INK
		if action == "done":
			fill = Look.accent()
			edge = Look.INK
			ink = Look.BG
		elif action == "back":
			fill = Color(Look.HOT, 0.2)
			edge = Color(Look.HOT, 0.7)
		if over:
			fill = fill.lightened(0.18)
			edge = Look.INK
		if down:
			fill = Look.INK
			ink = Look.BG
		Look.panel(self, rect, fill, 16, edge, 3)
		var kind: StringName = &"mono" if action.length() == 1 else &"head"
		Look.text_c(self, kind, rect.get_center(), str(k["label"]), 52, ink)

	# Time left before it saves itself.
	var frac := clampf(seconds_left / Tuning.TAG_SECONDS, 0.0, 1.0)
	Look.bar(self, Rect2(610.0, 1010.0, 700.0, 12.0), frac, Look.accent())
	Look.text_c(self, &"body", Vector2(960.0, 1048.0), "Type or click the keys. Saves in %d" % int(ceil(seconds_left)), 34, Look.DIM)
