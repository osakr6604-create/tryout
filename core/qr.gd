class_name QR
extends RefCounted
## A small QR code encoder: byte mode, error correction level M, versions 1 to
## 10 (up to 213 bytes). It exists so the booth can hand every player a link
## to their own card with no network at all: the code is drawn on screen and
## the player's phone does the rest.
##
## encode() returns the code as rows of bytes, 1 for a dark module. An empty
## array means the text was too long.

const MAX_VERSION := 10
const TOTAL_CODEWORDS: Array[int] = [0, 26, 44, 70, 100, 134, 172, 196, 242, 292, 346]
const ECC_PER_BLOCK: Array[int] = [0, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26]
const BLOCKS: Array[int] = [0, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5]
const ALIGNMENT: Array = [
	[], [], [6, 18], [6, 22], [6, 26], [6, 30], [6, 34],
	[6, 22, 38], [6, 24, 42], [6, 26, 46], [6, 28, 50],
]
const FORMAT_BITS_M := 0

const PENALTY_RUN := 3
const PENALTY_BLOCK := 3
const PENALTY_FINDER := 40
const PENALTY_BALANCE := 10


static func data_codewords(version: int) -> int:
	return TOTAL_CODEWORDS[version] - ECC_PER_BLOCK[version] * BLOCKS[version]


## How many bytes of text fit in a version.
static func capacity(version: int) -> int:
	var header_bits := 4 + (8 if version <= 9 else 16)
	return (data_codewords(version) * 8 - header_bits) / 8


## The smallest version that holds [param length] bytes, or 0 when none does.
static func version_for(length: int) -> int:
	for version in range(1, MAX_VERSION + 1):
		if length <= capacity(version):
			return version
	return 0


static func encode(text: String) -> Array:
	var bytes := text.to_utf8_buffer()
	var version := version_for(bytes.size())
	if version == 0:
		return []
	var codewords := _interleave(_data_codewords(bytes, version), version)
	var size := 17 + 4 * version
	# Both grids are flat, row after row. "reserved" marks the fixed patterns,
	# which data and masks must leave alone.
	var modules := PackedByteArray()
	modules.resize(size * size)
	var reserved := PackedByteArray()
	reserved.resize(size * size)
	_draw_function_patterns(modules, reserved, size, version)
	_draw_codewords(modules, reserved, size, codewords)

	# Try all eight masks and keep the one a scanner will find easiest.
	var best_mask := 0
	var best_penalty := -1
	for mask in 8:
		_apply_mask(modules, reserved, size, mask)
		_draw_format(modules, reserved, size, mask)
		var penalty := _penalty(modules, size)
		if best_penalty < 0 or penalty < best_penalty:
			best_penalty = penalty
			best_mask = mask
		_apply_mask(modules, reserved, size, mask)   # masking twice undoes it
	_apply_mask(modules, reserved, size, best_mask)
	_draw_format(modules, reserved, size, best_mask)

	var rows: Array = []
	for y in size:
		rows.append(modules.slice(y * size, (y + 1) * size))
	return rows


# ---- data ----

static func _data_codewords(bytes: PackedByteArray, version: int) -> PackedByteArray:
	var bits: Array[int] = []
	_push_bits(bits, 0b0100, 4)                                 # byte mode
	_push_bits(bits, bytes.size(), 8 if version <= 9 else 16)   # how many bytes follow
	for b in bytes:
		_push_bits(bits, b, 8)
	var capacity_bits := data_codewords(version) * 8
	_push_bits(bits, 0, mini(4, capacity_bits - bits.size()))   # terminator
	_push_bits(bits, 0, (8 - bits.size() % 8) % 8)              # to a whole byte
	var out := PackedByteArray()
	for i in range(0, bits.size(), 8):
		var value := 0
		for k in 8:
			value = (value << 1) | bits[i + k]
		out.append(value)
	var pad := 0xEC
	while out.size() < data_codewords(version):
		out.append(pad)
		pad = 0x11 if pad == 0xEC else 0xEC
	return out


static func _push_bits(bits: Array[int], value: int, count: int) -> void:
	for i in range(count - 1, -1, -1):
		bits.append((value >> i) & 1)


## Splits the data into blocks, adds Reed-Solomon codewords to each and
## weaves the blocks together, as the standard lays out.
static func _interleave(data: PackedByteArray, version: int) -> PackedByteArray:
	var block_count := BLOCKS[version]
	var ecc_len := ECC_PER_BLOCK[version]
	var raw := TOTAL_CODEWORDS[version]
	var short_blocks := block_count - raw % block_count
	var short_len := raw / block_count
	var divisor := _rs_divisor(ecc_len)
	var blocks: Array[PackedByteArray] = []
	var k := 0
	for i in block_count:
		var data_len := short_len - ecc_len + (0 if i < short_blocks else 1)
		var block := data.slice(k, k + data_len)
		k += data_len
		var ecc := _rs_remainder(block, divisor)
		if i < short_blocks:
			block.append(0)   # placeholder so every block has the same length
		block.append_array(ecc)
		blocks.append(block)
	var out := PackedByteArray()
	for i in blocks[0].size():
		for j in block_count:
			if i != short_len - ecc_len or j >= short_blocks:
				out.append(blocks[j][i])
	return out


static func _gf_multiply(x: int, y: int) -> int:
	var z := 0
	for i in range(7, -1, -1):
		z = ((z << 1) ^ ((z >> 7) * 0x11D)) & 0xFF
		z ^= ((y >> i) & 1) * x
	return z


static func _rs_divisor(degree: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(degree)
	result[degree - 1] = 1
	var root := 1
	for i in degree:
		for j in degree:
			result[j] = _gf_multiply(result[j], root)
			if j + 1 < degree:
				result[j] = result[j] ^ result[j + 1]
		root = _gf_multiply(root, 0x02)
	return result


static func _rs_remainder(data: PackedByteArray, divisor: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(divisor.size())
	for b in data:
		var factor := b ^ result[0]
		for i in range(0, result.size() - 1):
			result[i] = result[i + 1]
		result[result.size() - 1] = 0
		for i in result.size():
			result[i] = result[i] ^ _gf_multiply(divisor[i], factor)
	return result


# ---- the grid ----

static func _put(modules: PackedByteArray, reserved: PackedByteArray, size: int, x: int, y: int, dark: bool) -> void:
	modules[y * size + x] = 1 if dark else 0
	reserved[y * size + x] = 1


static func _draw_function_patterns(modules: PackedByteArray, reserved: PackedByteArray, size: int, version: int) -> void:
	for i in size:
		_put(modules, reserved, size, 6, i, i % 2 == 0)
		_put(modules, reserved, size, i, 6, i % 2 == 0)
	_draw_finder(modules, reserved, size, 3, 3)
	_draw_finder(modules, reserved, size, size - 4, 3)
	_draw_finder(modules, reserved, size, 3, size - 4)
	var centers: Array = ALIGNMENT[version]
	var last := centers.size() - 1
	for i in centers.size():
		for j in centers.size():
			# The three corners with finder patterns do not get one.
			if (i == 0 and j == 0) or (i == 0 and j == last) or (i == last and j == 0):
				continue
			_draw_alignment(modules, reserved, size, int(centers[i]), int(centers[j]))
	_draw_format(modules, reserved, size, 0)
	_draw_version(modules, reserved, size, version)


static func _draw_finder(modules: PackedByteArray, reserved: PackedByteArray, size: int, cx: int, cy: int) -> void:
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var x := cx + dx
			var y := cy + dy
			if x < 0 or x >= size or y < 0 or y >= size:
				continue
			var dist := maxi(absi(dx), absi(dy))
			_put(modules, reserved, size, x, y, dist != 2 and dist != 4)


static func _draw_alignment(modules: PackedByteArray, reserved: PackedByteArray, size: int, cx: int, cy: int) -> void:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			_put(modules, reserved, size, cx + dx, cy + dy, maxi(absi(dx), absi(dy)) != 1)


static func _format_bits(mask: int) -> int:
	var data := (FORMAT_BITS_M << 3) | mask
	var rem := data
	for i in 10:
		rem = (rem << 1) ^ ((rem >> 9) * 0x537)
	return ((data << 10) | rem) ^ 0x5412


static func _draw_format(modules: PackedByteArray, reserved: PackedByteArray, size: int, mask: int) -> void:
	var bits := _format_bits(mask)
	for i in range(0, 6):
		_put(modules, reserved, size, 8, i, ((bits >> i) & 1) != 0)
	_put(modules, reserved, size, 8, 7, ((bits >> 6) & 1) != 0)
	_put(modules, reserved, size, 8, 8, ((bits >> 7) & 1) != 0)
	_put(modules, reserved, size, 7, 8, ((bits >> 8) & 1) != 0)
	for i in range(9, 15):
		_put(modules, reserved, size, 14 - i, 8, ((bits >> i) & 1) != 0)
	for i in range(0, 8):
		_put(modules, reserved, size, size - 1 - i, 8, ((bits >> i) & 1) != 0)
	for i in range(8, 15):
		_put(modules, reserved, size, 8, size - 15 + i, ((bits >> i) & 1) != 0)
	_put(modules, reserved, size, 8, size - 8, true)


static func _version_bits(version: int) -> int:
	var rem := version
	for i in 12:
		rem = (rem << 1) ^ ((rem >> 11) * 0x1F25)
	return (version << 12) | rem


static func _draw_version(modules: PackedByteArray, reserved: PackedByteArray, size: int, version: int) -> void:
	if version < 7:
		return
	var bits := _version_bits(version)
	for i in 18:
		var dark := ((bits >> i) & 1) != 0
		var a := size - 11 + i % 3
		var b := i / 3
		_put(modules, reserved, size, a, b, dark)
		_put(modules, reserved, size, b, a, dark)


## Lays the codewords down in the zigzag the standard asks for: two columns at
## a time from the right edge, going up, then down, skipping the timing column.
static func _draw_codewords(modules: PackedByteArray, reserved: PackedByteArray, size: int, data: PackedByteArray) -> void:
	var i := 0
	var total := data.size() * 8
	var right := size - 1
	while right >= 1:
		if right == 6:
			right = 5
		for vert in size:
			for j in 2:
				var x := right - j
				var upward := ((right + 1) & 2) == 0
				var y := size - 1 - vert if upward else vert
				if reserved[y * size + x] == 0 and i < total:
					modules[y * size + x] = (data[i >> 3] >> (7 - (i & 7))) & 1
					i += 1
		right -= 2


static func _mask_hits(mask: int, x: int, y: int) -> bool:
	match mask:
		0:
			return (x + y) % 2 == 0
		1:
			return y % 2 == 0
		2:
			return x % 3 == 0
		3:
			return (x + y) % 3 == 0
		4:
			return (x / 3 + y / 2) % 2 == 0
		5:
			return x * y % 2 + x * y % 3 == 0
		6:
			return (x * y % 2 + x * y % 3) % 2 == 0
	return ((x + y) % 2 + x * y % 3) % 2 == 0


static func _apply_mask(modules: PackedByteArray, reserved: PackedByteArray, size: int, mask: int) -> void:
	for y in size:
		for x in size:
			var at := y * size + x
			if reserved[at] == 0 and _mask_hits(mask, x, y):
				modules[at] = modules[at] ^ 1


## The standard's scoring of how hard a pattern is to scan. Lower is better.
static func _penalty(modules: PackedByteArray, size: int) -> int:
	var result := 0
	var dark := 0
	for y in size:
		result += _line_penalty(modules.slice(y * size, (y + 1) * size))
	for x in size:
		var column := PackedByteArray()
		column.resize(size)
		for y in size:
			column[y] = modules[y * size + x]
		result += _line_penalty(column)
	for at in modules.size():
		dark += modules[at]
	for y in size - 1:
		for x in size - 1:
			var v := modules[y * size + x]
			if v == modules[y * size + x + 1] and v == modules[(y + 1) * size + x] and v == modules[(y + 1) * size + x + 1]:
				result += PENALTY_BLOCK
	var total := size * size
	var k := int(ceil(absf(float(dark) * 20.0 - float(total) * 10.0) / float(total))) - 1
	result += maxi(k, 0) * PENALTY_BALANCE
	return result


static func _line_penalty(line: PackedByteArray) -> int:
	var result := 0
	var run := 1
	for i in range(1, line.size()):
		if line[i] == line[i - 1]:
			run += 1
		else:
			if run >= 5:
				result += PENALTY_RUN + run - 5
			run = 1
	if run >= 5:
		result += PENALTY_RUN + run - 5
	# Anything that looks like a finder pattern in the data area confuses scanners.
	var pattern: Array[int] = [1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0]
	for start in range(0, line.size() - 10):
		var forward := true
		var backward := true
		for k in 11:
			if line[start + k] != pattern[k]:
				forward = false
			if line[start + k] != pattern[10 - k]:
				backward = false
		if forward:
			result += PENALTY_FINDER
		if backward:
			result += PENALTY_FINDER
	return result
