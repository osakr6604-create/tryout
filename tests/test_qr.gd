extends TestCase
## The QR code on the report screen. The pinned fingerprints below belong to
## codes that were decoded with an independent reader (jsQR) and gave back the
## exact text, so a change that breaks scanning fails here.
## To re-check after a deliberate change: run dev/qr_dump.gd, decode the PNGs
## with any QR reader, then update the fingerprints.

const PINNED: Dictionary = {
	"https://example.org/card/#1.ACE.7412.2.0.87.90.66.71.55.80":
		"548d9dba761a56509b97a45457f7e2f86fd439a1d63cd6167e01ca47eda32780",
	"https://osakr6604-create.github.io/tryout/card/#1.ROOKIE-417.10000.0.6.99.99.99.99.99.99":
		"245c0bc1e5fd4ab84521b522152f8ec2ed1263d4683b418bf33a568d1fa1276f",
	"TRYOUT":
		"c8edc217c92a142f788da0b013e1b70e02181dce354f57a598095d97a57c015c",
}


func _flat(modules: Array) -> String:
	var out := ""
	for row: PackedByteArray in modules:
		for v in row:
			out += "1" if v != 0 else "0"
	return out


func _dark(modules: Array, x: int, y: int) -> bool:
	return (modules[y] as PackedByteArray)[x] != 0


func test_reference_codes_match_the_verified_ones() -> void:
	for text: String in PINNED:
		eq(_flat(QR.encode(text)).sha256_text(), str(PINNED[text]), text)


func test_size_follows_the_version() -> void:
	eq(QR.encode("A").size(), 21, "version 1")
	for length in [14, 15, 26, 27, 62, 63, 84, 85, 106, 107, 180, 181, 213]:
		var text := "x".repeat(length)
		var modules := QR.encode(text)
		var version := QR.version_for(length)
		eq(modules.size(), 17 + 4 * version, "%d bytes" % length)
		for row: PackedByteArray in modules:
			eq(row.size(), modules.size(), "square")


func test_capacity_table_matches_the_standard() -> void:
	# Byte capacity at error correction level M, from the QR specification.
	var expected: Array[int] = [14, 26, 42, 62, 84, 106, 122, 152, 180, 213]
	for version in range(1, 11):
		eq(QR.capacity(version), expected[version - 1], "version %d" % version)
	eq(QR.version_for(84), 5)
	eq(QR.version_for(85), 6)
	eq(QR.version_for(214), 0, "too long")


func test_too_long_gives_nothing() -> void:
	eq(QR.encode("x".repeat(400)).size(), 0)


func test_finder_patterns_are_in_three_corners() -> void:
	var modules := QR.encode("https://example.org/card/#1.ACE.7412.2.0.87.90.66.71.55.80")
	var n := modules.size()
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(n - 7, 0), Vector2i(0, n - 7)]:
		for dy in 7:
			for dx in 7:
				var ring := maxi(absi(dx - 3), absi(dy - 3))
				eq(_dark(modules, corner.x + dx, corner.y + dy), ring != 2, "finder at %s, cell %d,%d" % [corner, dx, dy])
	# The fourth corner carries data, not a finder: its 7x7 block is not the same picture.
	var same := true
	for dy in 7:
		for dx in 7:
			if _dark(modules, n - 7 + dx, n - 7 + dy) != (maxi(absi(dx - 3), absi(dy - 3)) != 2):
				same = false
	check(not same, "no finder in the fourth corner")


func test_timing_lines_alternate() -> void:
	var modules := QR.encode("TRYOUT")
	var n := modules.size()
	for i in range(8, n - 8):
		eq(_dark(modules, i, 6), i % 2 == 0, "row 6, column %d" % i)
		eq(_dark(modules, 6, i), i % 2 == 0, "column 6, row %d" % i)
	check(_dark(modules, 8, n - 8), "the fixed dark module")


func test_format_bits_survive_their_own_check() -> void:
	# A valid 15 bit format word leaves no remainder under its generator.
	for mask in 8:
		var word := QR._format_bits(mask) ^ 0x5412
		var rem := word
		for i in range(14, 9, -1):
			if (rem >> i) & 1:
				rem ^= 0x537 << (i - 10)
		eq(rem, 0, "mask %d" % mask)


func test_error_correction_matches_a_known_answer() -> void:
	# Worked example from the QR specification literature: "HELLO WORLD" at
	# version 1-M in alphanumeric mode has these 16 data and 10 check codewords.
	var data := PackedByteArray([32, 91, 11, 120, 209, 114, 220, 77, 67, 64, 236, 17, 236, 17, 236, 17])
	var want := PackedByteArray([196, 35, 39, 119, 235, 215, 231, 226, 93, 23])
	eq(QR._rs_remainder(data, QR._rs_divisor(10)), want)


func test_field_multiplication() -> void:
	eq(QR._gf_multiply(0, 77), 0)
	eq(QR._gf_multiply(1, 77), 77)
	eq(QR._gf_multiply(2, 128), 29, "wraps with the field polynomial")
	eq(QR._gf_multiply(7, 9), QR._gf_multiply(9, 7))


func test_same_text_same_code() -> void:
	eq(_flat(QR.encode("repeat me")), _flat(QR.encode("repeat me")))
	check(_flat(QR.encode("repeat me")) != _flat(QR.encode("repeat mf")), "one letter changes the code")


func test_card_link_round_trip() -> void:
	var link := CardLink.build("https://example.org/card/", "ACE", 7412, "A", "ENTRY", [87, 90, 66, 71, 55, 80])
	eq(link, "https://example.org/card/#1.ACE.7412.2.0.87.90.66.71.55.80")
	var back := CardLink.parse(link)
	eq(str(back["tag"]), "ACE")
	eq(int(back["score"]), 7412)
	eq(str(back["grade"]), "A")
	eq(str(back["role"]), "ENTRY")
	eq(back["attrs"], [87, 90, 66, 71, 55, 80])


func test_card_link_handles_every_grade_role_and_awkward_tag() -> void:
	for grade in CardLink.GRADE_ORDER:
		for role in CardLink.ROLE_ORDER:
			var back := CardLink.parse(CardLink.build("https://x.y/", "A_B-C9", 10000, grade, role, [0, 99, 5, 50, 1, 98]))
			eq(str(back["grade"]), grade)
			eq(str(back["role"]), role)
			eq(str(back["tag"]), "A_B-C9")
	# Every grade and role the game can produce must be in the link's tables.
	for row: Dictionary in Tuning.GRADES:
		check(CardLink.GRADE_ORDER.has(row["grade"]), "grade %s" % row["grade"])
	for attr in Rating.ATTRS:
		check(CardLink.ROLE_ORDER.has(Rating.ROLES[attr]), "role %s" % Rating.ROLES[attr])
	check(CardLink.ROLE_ORDER.has(Rating.FLEX_ROLE), "flex role")


func test_card_link_rejects_other_text() -> void:
	eq(CardLink.parse("https://example.org/"), {})
	eq(CardLink.parse("https://example.org/#2.ACE.1.1.1.1.1.1.1.1.1"), {}, "unknown format version")
	eq(CardLink.parse("https://example.org/#1.ACE.1"), {}, "too short")


func test_longest_real_link_fits_one_code() -> void:
	var link := CardLink.build(Config.card_url, "W".repeat(NameFilter.MAX_LENGTH), 10000, "S+", "SHOTCALLER", [99, 99, 99, 99, 99, 99])
	check(QR.encode(link).size() > 0, "the longest card link fits")
	at_most(float(QR.version_for(link.to_utf8_buffer().size())), 6.0, "and stays small enough to scan off a screen")


func test_card_page_says_what_the_game_says() -> void:
	# The card page repeats the report's wording in its own script. If the game's
	# text changes, the page has to change with it.
	var page := FileAccess.get_file_as_string("res://site/card/index.html")
	check(page.length() > 1000, "card page found")
	for table: Dictionary in [Rating.STRENGTHS, Rating.WEAKNESSES, Rating.VERDICTS]:
		for key: Variant in table:
			check(page.contains("\"%s\"" % str(table[key])), "card page is missing: %s" % str(table[key]))
	var roles := "\"" + "\", \"".join(CardLink.ROLE_ORDER) + "\""
	check(page.contains(roles), "roles in the same order")
	var grades := "\"" + "\", \"".join(CardLink.GRADE_ORDER) + "\""
	check(page.contains(grades), "grades in the same order")
	var attrs: PackedStringArray = []
	for attr in Rating.ATTRS:
		attrs.append(String(attr))
	check(page.contains("\"" + "\", \"".join(attrs) + "\""), "attributes in the same order")
	check(not page.contains("—"), "no long dashes on the public page")
