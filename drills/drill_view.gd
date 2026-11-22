class_name DrillView
extends Node2D
## Draws one drill and turns what happens in it into sound and effects.
## The rules live in the model; a view only reads it. One subclass per drill.

var model: DrillModel
var fx: Fx
var time: float = 0.0           ## seconds this view has been on screen
var frozen: bool = true         ## true while the command card is up: draw, but nothing moves yet
var silent: bool = false        ## the attract demo plays without sound effects


static func create(id: StringName) -> DrillView:
	match id:
		&"flick":
			return FlickView.new()
		&"track":
			return TrackView.new()
		&"react":
			return ReactView.new()
		&"holdfire":
			return HoldFireView.new()
		&"lasthit":
			return LastHitView.new()
		&"skillshot":
			return SkillshotView.new()
		&"mapcheck":
			return MapCheckView.new()
		&"clutch":
			return ClutchView.new()
	return DrillView.new()


func bind(p_model: DrillModel, p_fx: Fx) -> void:
	model = p_model
	fx = p_fx
	_bound()


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


## Called by the game each frame with everything the model reported.
func handle(events: Array[Dictionary]) -> void:
	for e in events:
		_on_event(e)


## A real click or tap. Most drills pass it straight to the model; the
## reaction drill overrides this to use its own high resolution clock.
func pointer_pressed(pos: Vector2) -> void:
	model.press(pos)


## The colour the background leans toward during this drill.
func mood() -> Color:
	return Look.accent()


## Which crosshair suits this drill: "cross", "ring" or "dot".
func crosshair() -> StringName:
	return &"cross"


func _draw() -> void:
	if model == null:
		return
	_frame()
	_paint()


## The outline of the play area, with corner brackets.
func _frame() -> void:
	var r := model.field
	var edge := Color(Look.accent(), 0.16)
	Look.panel(self, r, Color(0.03, 0.05, 0.11, 0.35), 26, edge, 2)
	var c := Color(Look.accent(), 0.55)
	var arm := 46.0
	for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx := 1.0 if corner.x < r.get_center().x else -1.0
		var sy := 1.0 if corner.y < r.get_center().y else -1.0
		draw_line(corner + Vector2(sx * 14.0, sy * 14.0), corner + Vector2(sx * (14.0 + arm), sy * 14.0), c, 4.0, true)
		draw_line(corner + Vector2(sx * 14.0, sy * 14.0), corner + Vector2(sx * 14.0, sy * (14.0 + arm)), c, 4.0, true)


## A target the way most drills show one: halo, ring, core.
func _target(pos: Vector2, radius: float, color: Color, pop: float = 1.0) -> void:
	var r := radius * pop
	Look.glow(self, pos, r * 2.6, Color(color, 0.38))
	Look.disc(self, pos, r, Color(color.darkened(0.55), 0.92))
	Look.ring(self, pos, r - 3.0, 6.0, color)
	Look.ring(self, pos, r * 0.56, 4.0, Color(Look.INK, 0.85))
	Look.disc(self, pos, r * 0.2, Look.INK)


## An opponent: a red diamond, so it never relies on colour alone.
func _enemy(pos: Vector2, radius: float, pop: float = 1.0) -> void:
	var r := radius * pop
	Look.glow(self, pos, r * 2.7, Color(Look.HOT, 0.42))
	Look.diamond(self, pos, r, Color(Look.HOT.darkened(0.5), 0.95))
	Look.diamond_outline(self, pos, r - 3.0, 6.0, Look.HOT)
	Look.diamond_outline(self, pos, r * 0.5, 4.0, Color(Look.INK, 0.9))
	Look.disc(self, pos, r * 0.13, Look.INK)


## A teammate: a blue circle with a plus.
func _ally(pos: Vector2, radius: float, pop: float = 1.0) -> void:
	var r := radius * pop
	var blue := Color("4D8DFF")
	Look.glow(self, pos, r * 2.5, Color(blue, 0.4))
	Look.disc(self, pos, r, Color(blue.darkened(0.5), 0.95))
	Look.ring(self, pos, r - 3.0, 6.0, blue)
	draw_line(pos + Vector2(-r * 0.36, 0.0), pos + Vector2(r * 0.36, 0.0), Look.INK, 8.0, true)
	draw_line(pos + Vector2(0.0, -r * 0.36), pos + Vector2(0.0, r * 0.36), Look.INK, 8.0, true)


func snd(sound: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not silent:
		Sfx.play(sound, pitch, volume_db)


func _pop(since: float, seconds: float = 0.14) -> float:
	return Look.ease_back(clampf(since / seconds, 0.0, 1.0))


# ---- for subclasses ----

func _bound() -> void:
	pass


func _on_event(_e: Dictionary) -> void:
	pass


func _paint() -> void:
	pass
