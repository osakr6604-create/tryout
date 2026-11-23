class_name Attract
extends Node2D
## What the booth shows between players: the pitch, a live demo played by the
## bot, today's top five and a big invitation to start.

const REEL_RECT := Rect2(1060.0, 150.0, 750.0, 362.0)
const START_RECT := Rect2(110.0, 690.0, 660.0, 140.0)
const DRILL_NAMES: Array[String] = ["FLICK", "TRACK", "REACT", "HOLD FIRE", "LAST HIT", "SKILLSHOT", "MAP CHECK", "CLUTCH"]

var board: BoardView

var _time: float = 0.0
var _clip: Control
var _holder: Node2D
var _fx: Fx
var _view: DrillView
var _model: DrillModel
var _bot: DrillBot
var _cursor: Crosshair
var _reel_index: int = 0
var _pause: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	board = BoardView.new()
	board.rect = Rect2(1060.0, 566.0, 750.0, 434.0)
	board.rows = 5
	add_child(board)

	# The demo is the real drill, drawn small inside a clipped frame.
	_clip = Control.new()
	_clip.position = REEL_RECT.position
	_clip.size = REEL_RECT.size
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_holder = Node2D.new()
	var scale_f := REEL_RECT.size.x / Tuning.FIELD.size.x
	_holder.scale = Vector2(scale_f, scale_f)
	_holder.position = -Tuning.FIELD.position * scale_f
	_clip.add_child(_holder)
	_fx = Fx.new()
	_fx.z_index = 5
	_holder.add_child(_fx)
	_cursor = Crosshair.new()
	_cursor.z_index = 6
	_cursor.scale = Vector2(1.6, 1.6)
	_holder.add_child(_cursor)


func open() -> void:
	visible = true
	set_process(true)
	_time = 0.0
	if _model == null:
		_next_demo()


func close() -> void:
	visible = false
	set_process(false)


func _next_demo() -> void:
	if _view != null:
		_view.queue_free()
	_fx.clear()
	var id: StringName = Tuning.DRILL_ORDER[_reel_index % Tuning.DRILL_ORDER.size()]
	_reel_index += 1
	_model = Session.make_model(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng.randi()
	_model.setup(rng, Tuning.FIELD)
	_view = DrillView.create(id)
	_view.silent = true
	_view.frozen = false
	_holder.add_child(_view)
	_holder.move_child(_view, 0)
	_view.bind(_model, _fx)
	_bot = DrillBot.create(_model, _rng.randf_range(0.6, 0.95), _rng.randi())
	_cursor.style = _view.crosshair()


func _process(delta: float) -> void:
	_time += delta
	if _model != null:
		if _model.done:
			_pause += delta
			if _pause > 0.9:
				_pause = 0.0
				_next_demo()
		else:
			_bot.step(delta)
			_model.advance(delta)
			_view.handle(_model.take_events())
			_cursor.position = _bot.cursor
	queue_redraw()


func start_hit(pos: Vector2) -> bool:
	return START_RECT.grow(24.0).has_point(pos)


func _draw() -> void:
	# ---- left: the pitch ----
	var label := Config.event_name.to_upper() if Config.event_name != "" else "OPEN TRYOUTS"
	var chip_w := Look.measure(&"ui", label, 38).x + 56.0
	Look.panel(self, Rect2(110.0, 112.0, chip_w, 62.0), Color(Look.accent(), 0.16), 31, Color(Look.accent(), 0.8), 2)
	Look.text(self, &"ui", Vector2(138.0, 157.0), label, 38, Look.accent())

	Look.logo(self, Rect2(660.0, 100.0, 350.0, 86.0))

	# The title, with a coloured echo behind it.
	Look.text(self, &"display", Vector2(121.0, 461.0), "TRYOUT", 330, Color(Look.PINK, 0.55))
	Look.text(self, &"display", Vector2(101.0, 447.0), "TRYOUT", 330, Color(Look.accent(), 0.7))
	Look.text(self, &"display", Vector2(110.0, 454.0), "TRYOUT", 330, Look.INK)

	Look.text(self, &"head", Vector2(114.0, 560.0), "THINK YOU COULD GO PRO?", 92, Look.INK)
	Look.text(self, &"body", Vector2(116.0, 628.0), "60 seconds. 8 drills. One scouting report.", 54, Look.DIM)

	# The start button.
	var beat := Look.pulse(_time, 3.2)
	var grow := START_RECT.grow(6.0 * beat)
	Look.glow(self, START_RECT.get_center(), 520.0, Color(Look.accent(), 0.14 + 0.1 * beat))
	Look.panel(self, grow, Look.accent(), 30, Color(Look.INK, 0.9), 4, 0.12)
	Look.text_c(self, &"display", grow.get_center() + Vector2(0.0, 2.0), "CLICK TO START", 92, Look.BG)
	Look.text(self, &"body", Vector2(118.0, 890.0), "Mouse only. No sign-up. Takes about a minute.", 40, Look.DIM)

	# The eight drills, with the one on the demo screen lit.
	var x := 116.0
	var showing := (_reel_index - 1 + DRILL_NAMES.size()) % DRILL_NAMES.size()
	for i in DRILL_NAMES.size():
		var name := DRILL_NAMES[i]
		var w := Look.measure(&"ui", name, 26).x + 22.0
		var on := i == showing
		Look.panel(self, Rect2(x, 950.0, w, 42.0), Color(Look.accent(), 0.22) if on else Color(1, 1, 1, 0.05), 21, Color(Look.accent(), 0.8) if on else Color(1, 1, 1, 0.12), 2)
		Look.text(self, &"ui", Vector2(x + 11.0, 981.0), name, 26, Look.INK if on else Look.DIM)
		x += w + 7.0

	# ---- right: the demo frame ----
	Look.panel(self, REEL_RECT.grow(10.0), Color(0, 0, 0, 0), 30, Color(Look.accent(), 0.5), 3)
	var tag := Rect2(REEL_RECT.position.x, REEL_RECT.position.y - 58.0, 420.0, 44.0)
	Look.disc(self, tag.position + Vector2(14.0, 22.0), 9.0, Color(Look.HOT, 0.5 + 0.5 * Look.pulse(_time, 4.0)))
	var demo_name := _model.title if _model != null else ""
	Look.text(self, &"ui", tag.position + Vector2(34.0, 35.0), "LIVE DEMO: %s" % demo_name, 36, Look.INK)
