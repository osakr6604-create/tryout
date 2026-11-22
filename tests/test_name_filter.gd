extends TestCase
## Tags are shown on a big screen in public, so the filter gets its own tests.
## Blocked words are never written out here: the tests read them from the
## filter's own stored list.


func test_clean_keeps_only_allowed_characters() -> void:
	eq(NameFilter.clean("ace"), "ACE")
	eq(NameFilter.clean("  two words "), "__TWO_WORD")
	eq(NameFilter.clean("a!b@c#d$"), "ABCD")
	eq(NameFilter.clean("x-ray_9"), "X-RAY_9")
	eq(NameFilter.clean("ABCDEFGHIJKLMNOP").length(), NameFilter.MAX_LENGTH)
	eq(NameFilter.clean(""), "")
	eq(NameFilter.clean("مرحبا"), "", "other scripts are dropped, not crashed on")


func test_ordinary_tags_pass() -> void:
	for tag: String in ["ACE", "NOVA", "FALCON", "CLASSIC", "BASS", "ASSASSIN", "GRAPE", "NIGERIA",
			"PAKISTAN", "TORPEDO", "SPICY", "SCRAPER", "PEACH", "TITAN", "ESSEX", "DICKENS",
			"KKKK9", "42", "---", "ROOKIE-007", "MIA", "C9FAN", "SNIPER", "HOELAND"]:
		check(NameFilter.is_allowed(tag), "%s should be allowed" % tag)


func test_empty_is_not_a_tag() -> void:
	check(not NameFilter.is_allowed(""), "empty")
	eq(NameFilter.accept("!!!"), "")


func test_every_stored_word_is_blocked() -> void:
	for stored in NameFilter.ANYWHERE:
		var word := NameFilter.decode(stored)
		check(not NameFilter.is_allowed(word), "plain form of %s" % stored)
		check(not NameFilter.is_allowed("X" + word + "9"), "inside a longer tag: %s" % stored)
	for stored in NameFilter.WHOLE:
		var word := NameFilter.decode(stored)
		check(not NameFilter.is_allowed(word), "whole word %s" % stored)


func test_number_swaps_do_not_get_past() -> void:
	var swaps := {"O": "0", "I": "1", "E": "3", "A": "4", "S": "5", "T": "7", "B": "8"}
	for stored in NameFilter.ANYWHERE:
		var word := NameFilter.decode(stored)
		var disguised := ""
		for ch in word:
			disguised += str(swaps.get(ch, ch))
		check(not NameFilter.is_allowed(disguised), "number swap of %s" % stored)


func test_stretched_spellings_do_not_get_past() -> void:
	for stored in NameFilter.ANYWHERE:
		var word := NameFilter.decode(stored)
		if word.length() > 6:
			continue   # would not fit in a tag once stretched
		var has_double := false
		for i in range(1, word.length()):
			if word[i] == word[i - 1]:
				has_double = true
		if has_double:
			continue
		var stretched := word.substr(0, 2) + word[1] + word[1] + word.substr(2)
		check(not NameFilter.is_allowed(stretched), "stretched %s" % stored)


func test_separators_do_not_get_past() -> void:
	var word := NameFilter.decode(NameFilter.ANYWHERE[0])
	var spaced := "_".join(word.split(""))
	check(not NameFilter.is_allowed(NameFilter.clean(spaced)), "underscores between letters")


func test_decode_is_its_own_reverse() -> void:
	eq(NameFilter.decode(NameFilter.decode("HELLO")), "HELLO")
	eq(NameFilter.decode("uryyb"), "HELLO")


func test_fallback_tags_are_valid() -> void:
	for n in [0, 7, 999, 1000, 123456, -5]:
		var tag := NameFilter.fallback(n)
		check(tag.length() <= NameFilter.MAX_LENGTH, tag)
		eq(NameFilter.accept(tag), tag)
