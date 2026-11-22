class_name Fx
extends Node2D
## Juice: particle bursts, expanding rings, floating words, screen flash and
## shake. Everything lives in plain arrays that are reused and capped, so an
## all-day booth session never grows the scene tree.

const MAX_PARTICLES := 420
const MAX_RINGS := 40
const MAX_WORDS := 24

var shake: float = 0.0
var flash: float = 0.0
var flash_color: Color = Color.WHITE

var _parts: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _words: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func clear() -> void:
	_parts.clear()
	_rings.clear()
	_words.clear()
	shake = 0.0
	flash = 0.0
	queue_redraw()


func burst(pos: Vector2, color: Color, count: int = 14, speed: float = 460.0, size: float = 7.0) -> void:
	for i in count:
		if _parts.size() >= MAX_PARTICLES:
			_parts.pop_front()
		var dir := Vector2.from_angle(_rng.randf() * TAU)
		var life := _rng.randf_range(0.28, 0.62)
		_parts.append({
			"pos": pos,
			"vel": dir * speed * _rng.randf_range(0.25, 1.0),
			"life": life,
			"max": life,
			"color": color,
			"size": size * _rng.randf_range(0.5, 1.2),
		})


## A spray in one direction, for shots and near misses.
func spray(pos: Vector2, dir: Vector2, color: Color, count: int = 8, speed: float = 520.0) -> void:
	for i in count:
		if _parts.size() >= MAX_PARTICLES:
			_parts.pop_front()
		var life := _rng.randf_range(0.2, 0.45)
		_parts.append({
			"pos": pos,
			"vel": dir.rotated(_rng.randf_range(-0.5, 0.5)) * speed * _rng.randf_range(0.3, 1.0),
			"life": life,
			"max": life,
			"color": color,
			"size": _rng.randf_range(3.0, 7.0),
		})


func ring(pos: Vector2, color: Color, from: float = 24.0, to: float = 130.0, seconds: float = 0.36, width: float = 7.0) -> void:
	if _rings.size() >= MAX_RINGS:
		_rings.pop_front()
	_rings.append({"pos": pos, "from": from, "to": to, "life": seconds, "max": seconds, "color": color, "width": width})


## A word that pops at [param pos] and drifts up.
func say(pos: Vector2, text: String, color: Color, size: int = 46, kind: StringName = &"head") -> void:
	if _words.size() >= MAX_WORDS:
		_words.pop_front()
	_words.append({"pos": pos, "text": text, "color": color, "size": size, "kind": kind, "life": 0.75, "max": 0.75})


func kick(amount: float) -> void:
	shake = maxf(shake, amount)


func flash_screen(color: Color, strength: float = 0.22) -> void:
	flash_color = color
	flash = maxf(flash, strength)


## Where to offset the stage this frame.
func offset() -> Vector2:
	if shake <= 0.05:
		return Vector2.ZERO
	return Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * shake


func _process(delta: float) -> void:
	if _parts.is_empty() and _rings.is_empty() and _words.is_empty() and shake <= 0.0 and flash <= 0.0:
		return
	shake = maxf(0.0, shake - delta * 60.0)
	flash = maxf(0.0, flash - delta * 0.9)
	var i := _parts.size() - 1
	while i >= 0:
		var p := _parts[i]
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			_parts.remove_at(i)
		else:
			p["vel"] = (p["vel"] as Vector2) * (1.0 - minf(1.0, delta * 3.2))
			p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		i -= 1
	i = _rings.size() - 1
	while i >= 0:
		_rings[i]["life"] = float(_rings[i]["life"]) - delta
		if float(_rings[i]["life"]) <= 0.0:
			_rings.remove_at(i)
		i -= 1
	i = _words.size() - 1
	while i >= 0:
		var w := _words[i]
		w["life"] = float(w["life"]) - delta
		w["pos"] = (w["pos"] as Vector2) + Vector2(0.0, -70.0) * delta
		if float(w["life"]) <= 0.0:
			_words.remove_at(i)
		i -= 1
	queue_redraw()


func _draw() -> void:
	for r in _rings:
		var k := 1.0 - float(r["life"]) / float(r["max"])
		var radius := lerpf(float(r["from"]), float(r["to"]), Look.ease_out(k))
		var c: Color = r["color"]
		Look.ring(self, r["pos"], radius, float(r["width"]) * (1.0 - k * 0.7), Color(c, c.a * (1.0 - k)))
	for p in _parts:
		var k := float(p["life"]) / float(p["max"])
		var c: Color = p["color"]
		var size := float(p["size"]) * (0.4 + 0.6 * k)
		Look.glow(self, p["pos"], size * 2.6, Color(c, 0.5 * k))
		Look.disc(self, p["pos"], size * 0.55, Color(c.lightened(0.35), k))
	for w in _words:
		var k := float(w["life"]) / float(w["max"])
		var pop := Look.ease_back(minf(1.0, (1.0 - k) * 5.0))
		var c: Color = w["color"]
		Look.text_shadow_c(self, w["kind"], w["pos"], w["text"], int(float(w["size"]) * (0.6 + 0.4 * pop)), Color(c, minf(1.0, k * 2.2)))
	if flash > 0.0:
		draw_rect(Rect2(-200, -200, 2320, 1480), Color(flash_color, flash))
