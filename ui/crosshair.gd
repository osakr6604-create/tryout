class_name Crosshair
extends Node2D
## The pointer. The system cursor is hidden and this is drawn instead, so the
## crosshair can change with the drill and looks the same on every machine.

var style: StringName = &"menu"     ## "cross", "ring", "dot" or "menu"
var _click: float = 0.0


func press() -> void:
	_click = 1.0


func _process(delta: float) -> void:
	if _click > 0.0:
		_click = maxf(0.0, _click - delta * 6.0)
	queue_redraw()


func _draw() -> void:
	var ink := Look.INK
	var shade := Color(0, 0, 0, 0.55)
	match style:
		&"cross":
			var gap := 9.0 + 8.0 * _click
			var arm := 17.0
			for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				draw_line(dir * (gap - 2.0), dir * (gap + arm + 2.0), shade, 8.0, true)
				draw_line(dir * gap, dir * (gap + arm), ink, 4.0, true)
			Look.disc(self, Vector2.ZERO, 4.0, shade)
			Look.disc(self, Vector2.ZERO, 2.5, Look.accent())
		&"ring":
			Look.ring(self, Vector2.ZERO, 30.0, 8.0, shade)
			Look.ring(self, Vector2.ZERO, 30.0, 4.0, ink)
			Look.disc(self, Vector2.ZERO, 4.0, Look.accent())
		&"dot":
			Look.ring(self, Vector2.ZERO, 16.0 + 8.0 * _click, 7.0, shade)
			Look.ring(self, Vector2.ZERO, 16.0 + 8.0 * _click, 3.0, ink)
			Look.disc(self, Vector2.ZERO, 6.0, ink)
		_:
			Look.glow(self, Vector2.ZERO, 46.0, Color(Look.accent(), 0.35))
			Look.ring(self, Vector2.ZERO, 18.0 + 10.0 * _click, 3.0, Color(Look.accent(), 0.9))
			Look.disc(self, Vector2.ZERO, 8.0, ink)
