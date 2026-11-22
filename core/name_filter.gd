class_name NameFilter
extends RefCounted
## Tags go on a big screen at a public event, so they are cleaned and checked
## before they are saved. Letters, digits, dash and underscore only, ten
## characters at most, and nothing from the block list.

const MAX_LENGTH := 10
const ALLOWED := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"

## The block list is stored shifted by 13 letters so this file stays clean to
## read. Words in ANYWHERE block any tag that contains them. Words in WHOLE are
## short and only block when they are the entire tag, so harmless names that
## happen to contain them (a fish, a country, a fruit) still go through.
const ANYWHERE: Array[String] = [
	"shpx", "fuvg", "ovgpu", "phag", "avttre", "avttn", "snttbg", "juber",
	"fyhg", "qvpxurnq", "nffubyr", "onfgneq", "encvfg", "anmv", "uvgyre",
	"cbea", "chffl", "pbpx", "jnax", "gjng", "ergneq", "xvxr", "puvax",
	"genaal", "crqbcu", "zbyrfg",
]
const WHOLE: Array[String] = [
	"nff", "phz", "snt", "ubr", "wvm", "frk", "gvg", "gvgf", "qvpx", "nany",
	"nahf", "encr", "fcvp", "cnxv", "pbba", "qlxr", "crqb", "xxx",
]

## Digits people swap in for letters.
const LEET: Dictionary = {
	"0": "O", "1": "I", "3": "E", "4": "A", "5": "S", "7": "T", "8": "B", "9": "G",
}

## A collapsed word shorter than this is too likely to sit inside a clean name.
const MIN_COLLAPSED_MATCH := 6


## Upper-cases, strips anything not allowed and trims to length.
static func clean(raw: String) -> String:
	var out := ""
	for ch in raw.to_upper():
		if ch == " ":
			ch = "_"
		if ALLOWED.contains(ch):
			out += ch
		if out.length() >= MAX_LENGTH:
			break
	return out


static func is_allowed(tag: String) -> bool:
	if tag.is_empty():
		return false
	var plain := _letters(tag)
	if plain.is_empty():
		return true   # digits and dashes only
	var squeezed := _collapse(plain)
	for stored in ANYWHERE:
		var word := decode(stored)
		if plain.contains(word):
			return false
		# Stretched spellings: compare with repeated letters removed.
		var word_squeezed := _collapse(word)
		if word_squeezed == word:
			if squeezed.contains(word):
				return false
		elif word_squeezed.length() >= MIN_COLLAPSED_MATCH and squeezed.contains(word_squeezed):
			return false
	for stored in WHOLE:
		var word := decode(stored)
		if plain == word or squeezed == word:
			return false
	return true


## The cleaned tag, or an empty string when it should not be shown.
static func accept(raw: String) -> String:
	var tag := clean(raw)
	return tag if is_allowed(tag) else ""


## A neutral tag for players who skip the keyboard or type something blocked.
static func fallback(number: int) -> String:
	return "ROOKIE-%03d" % (absi(number) % 1000)


## Undoes the 13 letter shift used to store the block list.
static func decode(stored: String) -> String:
	var out := ""
	for ch in stored.to_upper():
		var code := ch.unicode_at(0)
		if code >= 65 and code <= 90:
			code = 65 + (code - 65 + 13) % 26
		out += String.chr(code)
	return out


## Letters only, with look-alike digits turned back into letters.
static func _letters(tag: String) -> String:
	var out := ""
	for ch in tag.to_upper():
		var c: String = LEET.get(ch, ch)
		if c >= "A" and c <= "Z":
			out += c
	return out


## "SHIIIT" becomes "SHIT".
static func _collapse(word: String) -> String:
	var out := ""
	var last := ""
	for ch in word:
		if ch != last:
			out += ch
		last = ch
	return out
