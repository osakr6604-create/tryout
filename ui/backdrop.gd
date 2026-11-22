class_name Backdrop
extends Node2D
## The moving background behind every screen: a dark gradient, two slow
## washes of colour, a drifting grid and a few motes. Cheap to draw and never
## the same twice, so an idle booth still looks alive from across the hall.

const SIZE := Vector2(1920.0, 1080.0)
const GRID := 120.0
const MOTES := 26

var time: float = 0.0
var mood: Color = Look.SKY          ## tint, eased toward [member want_mood]
var want_mood: Color = Look.SKY
var energy: float = 0.0             ## 0 calm, 1 mid-drill
var want_energy: float = 0.0


func set_mood(color: Color, level: float) -> void:
	want_mood = color
	want_energy = level


func _process(delta: float) -> void:
	time += delta
	mood = mood.lerp(want_mood, clampf(delta * 2.0, 0.0, 1.0))
	energy = lerpf(energy, want_energy, clampf(delta * 2.0, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	var top := Look.BG
	var bottom := Look.BG_LIFT.lerp(mood, 0.05 + 0.05 * energy)
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(SIZE.x, 0.0), SIZE, Vector2(0.0, SIZE.y)]),
		PackedColorArray([top, top, bottom, bottom]))

	# Two big slow washes of colour.
	var a := Vector2(420.0 + sin(time * 0.13) * 260.0, 260.0 + cos(time * 0.11) * 140.0)
	var b := Vector2(1500.0 + cos(time * 0.09) * 240.0, 820.0 + sin(time * 0.12) * 150.0)
	Look.glow(self, a, 900.0, Color(mood, 0.10 + 0.05 * energy))
	Look.glow(self, b, 1000.0, Color(Look.VIOLET, 0.09))
	Look.glow(self, Vector2(960.0, 1250.0), 900.0, Color(Look.PINK, 0.04 + 0.03 * energy))

	# A grid that drifts down and to the right.
	var shift := fmod(time * (10.0 + 22.0 * energy), GRID)
	var line := Color(1, 1, 1, 0.028 + 0.014 * energy)
	var x := -GRID + shift
	while x < SIZE.x + GRID:
		draw_line(Vector2(x, 0.0), Vector2(x, SIZE.y), line, 2.0)
		x += GRID
	var y := -GRID + shift
	while y < SIZE.y + GRID:
		draw_line(Vector2(0.0, y), Vector2(SIZE.x, y), line, 2.0)
		y += GRID

	# Motes rising at different speeds. Positions come from the index, so
	# nothing needs storing.
	for i in MOTES:
		var seed_f := float(i) * 12.9898
		var px := fposmod(sin(seed_f) * 43758.5453, 1.0) * SIZE.x
		var speed := 14.0 + fposmod(sin(seed_f * 1.7) * 9631.17, 1.0) * 40.0
		var py := SIZE.y - fposmod(time * speed + fposmod(sin(seed_f * 2.3) * 5183.3, 1.0) * SIZE.y, SIZE.y + 80.0)
		var size := 3.0 + fposmod(sin(seed_f * 3.1) * 771.1, 1.0) * 5.0
		Look.glow(self, Vector2(px + sin(time * 0.6 + seed_f) * 24.0, py), size * 3.0, Color(mood.lerp(Look.INK, 0.4), 0.22))
