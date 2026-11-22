class_name CardLink
extends RefCounted
## The link inside the QR code on the report screen. Everything the card page
## needs travels in the part after "#", so the booth never talks to a server:
## the page is static and draws the card from the link alone.
##
## Format: <base>#1.<tag>.<score>.<grade index>.<role index>.<six attributes>
## Example: https://example.org/card/#1.ACE.7412.2.0.87.90.66.71.55.80

const FORMAT_VERSION := 1
const GRADE_ORDER: Array[String] = ["S+", "S", "A", "B", "C", "D"]
const ROLE_ORDER: Array[String] = ["ENTRY", "MARKSMAN", "RIFLER", "PLAYMAKER", "ANCHOR", "SHOTCALLER", "FLEX"]


static func build(base: String, tag: String, score: int, grade: String, role: String, attrs: Array) -> String:
	var parts: PackedStringArray = [
		str(FORMAT_VERSION),
		tag,
		str(clampi(score, 0, 10000)),
		str(maxi(0, GRADE_ORDER.find(grade))),
		str(maxi(0, ROLE_ORDER.find(role))),
	]
	for i in 6:
		parts.append(str(clampi(int(attrs[i]) if i < attrs.size() else 0, 0, 99)))
	return base + "#" + ".".join(parts)


## The reverse of build(), used by the tests to prove the link carries the
## whole card. Returns an empty dictionary when the text is not a card link.
static func parse(link: String) -> Dictionary:
	var hash_at := link.find("#")
	if hash_at < 0:
		return {}
	var parts := link.substr(hash_at + 1).split(".")
	if parts.size() != 11 or int(parts[0]) != FORMAT_VERSION:
		return {}
	var attrs: Array = []
	for i in range(5, 11):
		attrs.append(int(parts[i]))
	return {
		"tag": parts[1],
		"score": int(parts[2]),
		"grade": GRADE_ORDER[clampi(int(parts[3]), 0, GRADE_ORDER.size() - 1)],
		"role": ROLE_ORDER[clampi(int(parts[4]), 0, ROLE_ORDER.size() - 1)],
		"attrs": attrs,
	}
