class_name TestCase
extends RefCounted
## Base for the test files. Each method whose name starts with "test_" is one
## test; it fails when any check in it fails.

var failed: bool = false
var messages: PackedStringArray = []
var checks: int = 0


func begin() -> void:
	failed = false
	messages.clear()


func check(condition: bool, message: String = "") -> void:
	checks += 1
	if not condition:
		failed = true
		messages.append(message if message != "" else "check failed")


func eq(got: Variant, want: Variant, message: String = "") -> void:
	check(got == want, "%s: got %s, wanted %s" % [message, got, want])


func near(got: float, want: float, tolerance: float = 0.001, message: String = "") -> void:
	check(absf(got - want) <= tolerance, "%s: got %s, wanted %s within %s" % [message, got, want, tolerance])


func more(a: float, b: float, message: String = "") -> void:
	check(a > b, "%s: %s is not more than %s" % [message, a, b])


func at_least(a: float, b: float, message: String = "") -> void:
	check(a >= b, "%s: %s is less than %s" % [message, a, b])


func at_most(a: float, b: float, message: String = "") -> void:
	check(a <= b, "%s: %s is more than %s" % [message, a, b])
