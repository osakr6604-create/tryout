class_name Look
extends RefCounted
## The game's look in one place: colours, fonts and a few drawing helpers.
## Everything on screen is drawn from code with these, so there are no image
## assets to license or to keep in sync.

# ---- palette ----
const BG := Color("070B17")
const BG_LIFT := Color("0E1630")
const INK := Color("F4F8FF")
const DIM := Color("8FA3C8")
const FAINT := Color("3A4A72")
const SKY := Color("2EC5FF")       ## the lead colour; a booth can override it in booth.cfg
const VIOLET := Color("9B6BFF")
const PINK := Color("FF4FA3")
const HOT := Color("FF5A4D")       ## opponents
const GOLD := Color("FFC83D")
const GOOD := Color("3DFFB0")
const PANEL := Color(0.055, 0.086, 0.18, 0.9)
const PANEL_EDGE := Color(0.18, 0.77, 1.0, 0.28)

const FONT_FILES: Dictionary = {
	&"display": "res://assets/fonts/BarlowCondensed-ExtraBoldItalic.ttf",
	&"head": "res://assets/fonts/BarlowCondensed-Bold.ttf",
	&"ui": "res://assets/fonts/BarlowCondensed-SemiBold.ttf",
	&"body": "res://assets/fonts/BarlowCondensed-Medium.ttf",
	&"mono": "res://assets/fonts/JetBrainsMono-Bold.ttf",
	&"monox": "res://assets/fonts/JetBrainsMono-ExtraBold.ttf",
	&"monom": "res://assets/fonts/JetBrainsMono-Medium.ttf",
}

static var _fonts: Dictionary = {}
static var _soft: Texture2D
static var _box: StyleBoxFlat


static func accent() -> Color:
	return Config.accent


static func font(kind: StringName) -> Font:
	if not _fonts.has(kind):
		_fonts[kind] = load(str(FONT_FILES[kind]))
	return _fonts[kind]


static func measure(kind: StringName, text: String, size: int) -> Vector2:
	return font(kind).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)


## Text with its left edge at [param pos].x and its baseline at [param pos].y.
static func text(ci: CanvasItem, kind: StringName, pos: Vector2, s: String, size: int, color: Color) -> void:
	ci.draw_string(font(kind), pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


## Text centred on [param center], both ways.
static func text_c(ci: CanvasItem, kind: StringName, center: Vector2, s: String, size: int, color: Color) -> void:
	var f := font(kind)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	var y := center.y + (f.get_ascent(size) - f.get_descent(size)) * 0.5
	ci.draw_string(f, Vector2(center.x - w * 0.5, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


## Text whose right edge sits at [param pos].x.
static func text_r(ci: CanvasItem, kind: StringName, pos: Vector2, s: String, size: int, color: Color) -> void:
	var w := measure(kind, s, size).x
	ci.draw_string(font(kind), Vector2(pos.x - w, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


## Centred text with a dark offset copy behind it, for words over busy scenes.
static func text_shadow_c(ci: CanvasItem, kind: StringName, center: Vector2, s: String, size: int, color: Color, depth: float = 4.0) -> void:
	text_c(ci, kind, center + Vector2(depth, depth), s, size, Color(0, 0, 0, 0.55 * color.a))
	text_c(ci, kind, center, s, size, color)


## Wraps [param s] to [param width] and draws it from the top-left corner down.
## Returns the height used.
static func paragraph(ci: CanvasItem, kind: StringName, top_left: Vector2, width: float, s: String, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> float:
	var f := font(kind)
	var pos := top_left + Vector2(0.0, f.get_ascent(size))
	ci.draw_multiline_string(f, pos, s, align, width, size, -1, color)
	return f.get_multiline_string_size(s, align, width, size).y


static func soft() -> Texture2D:
	if _soft == null:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.42), Color(1, 1, 1, 0)])
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 128
		tex.height = 128
		_soft = tex
	return _soft


## A soft round light, used for halos behind targets and for particles.
static func glow(ci: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	ci.draw_texture_rect(soft(), Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


static func ring(ci: CanvasItem, pos: Vector2, radius: float, width: float, color: Color) -> void:
	ci.draw_arc(pos, radius, 0.0, TAU, 64, color, width, true)


## Part of a ring, starting at 12 o'clock and running clockwise.
static func arc(ci: CanvasItem, pos: Vector2, radius: float, width: float, fraction: float, color: Color) -> void:
	if fraction <= 0.0:
		return
	var points := maxi(8, int(72.0 * fraction))
	ci.draw_arc(pos, radius, -PI * 0.5, -PI * 0.5 + TAU * clampf(fraction, 0.0, 1.0), points, color, width, true)


static func disc(ci: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	ci.draw_circle(pos, radius, color, true, -1.0, true)


static func diamond(ci: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array([
		pos + Vector2(0, -radius), pos + Vector2(radius, 0), pos + Vector2(0, radius), pos + Vector2(-radius, 0),
	])
	ci.draw_colored_polygon(pts, color)


static func diamond_outline(ci: CanvasItem, pos: Vector2, radius: float, width: float, color: Color) -> void:
	var pts := PackedVector2Array([
		pos + Vector2(0, -radius), pos + Vector2(radius, 0), pos + Vector2(0, radius), pos + Vector2(-radius, 0), pos + Vector2(0, -radius),
	])
	ci.draw_polyline(pts, color, width, true)


## A rounded panel. [param skew] leans it like a broadcast lower-third.
static func panel(ci: CanvasItem, rect: Rect2, fill: Color, radius: int = 18, edge: Color = Color(0, 0, 0, 0), edge_width: int = 2, skew: float = 0.0) -> void:
	if _box == null:
		_box = StyleBoxFlat.new()
		_box.anti_aliasing = true
	_box.bg_color = fill
	_box.set_corner_radius_all(radius)
	_box.border_color = edge
	_box.set_border_width_all(edge_width if edge.a > 0.0 else 0)
	_box.skew = Vector2(skew, 0.0)
	ci.draw_style_box(_box, rect)


## A filled bar with a track behind it.
static func bar(ci: CanvasItem, rect: Rect2, fraction: float, fill: Color, track: Color = Color(1, 1, 1, 0.09)) -> void:
	var r := int(rect.size.y * 0.5)
	panel(ci, rect, track, r)
	var w := rect.size.x * clampf(fraction, 0.0, 1.0)
	if w >= rect.size.y:
		panel(ci, Rect2(rect.position, Vector2(w, rect.size.y)), fill, r)
	elif w > 1.0:
		panel(ci, Rect2(rect.position, Vector2(rect.size.y, rect.size.y)), Color(fill, fill.a * w / rect.size.y), r)


## Colour for a 0..100 score: red, amber, sky, mint as it climbs.
static func score_color(score: float) -> Color:
	if score >= 92.0:
		return GOOD
	if score >= 78.0:
		return SKY
	if score >= 58.0:
		return Color("7FD9FF")
	if score >= 35.0:
		return GOLD
	return HOT


static func grade_color(grade: String) -> Color:
	match grade:
		"S+":
			return GOLD
		"S":
			return GOOD
		"A":
			return SKY
		"B":
			return VIOLET
		"C":
			return DIM
	return HOT


## Eases for hand-rolled animation.
static func ease_out(k: float) -> float:
	var c := clampf(k, 0.0, 1.0)
	return 1.0 - pow(1.0 - c, 3.0)


static func ease_back(k: float) -> float:
	var c := clampf(k, 0.0, 1.0) - 1.0
	return 1.0 + 2.70158 * c * c * c + 1.70158 * c * c


static func pulse(time: float, speed: float = 3.0) -> float:
	return 0.5 + 0.5 * sin(time * speed)
