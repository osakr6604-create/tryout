class_name Session
extends RefCounted
## One player's run: the seed, which drill is next, and the results so far.
## It also knows how to build each drill, so the game, the demo bot and the
## tests all make drills the same way.

var seed_value: int = 0
var index: int = 0
var results: Array[DrillResult] = []


static func create(p_seed: int) -> Session:
	var s := Session.new()
	s.seed_value = p_seed
	return s


static func drill_count() -> int:
	return Tuning.DRILL_ORDER.size()


static func make_model(id: StringName) -> DrillModel:
	match id:
		&"flick":
			return FlickModel.new()
		&"track":
			return TrackModel.new()
		&"react":
			return ReactModel.new()
		&"holdfire":
			return HoldFireModel.new()
		&"lasthit":
			return LastHitModel.new()
		&"skillshot":
			return SkillshotModel.new()
		&"mapcheck":
			return MapCheckModel.new()
		&"clutch":
			return ClutchModel.new()
	push_error("Unknown drill: %s" % id)
	return DrillModel.new()


## A generator for one drill. Each drill gets its own stream from the run's
## seed, so changing one drill never changes what the others roll.
func rng_for(drill_index: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, drill_index, "tryout"])
	return rng


func current_id() -> StringName:
	return Tuning.DRILL_ORDER[index] if index < drill_count() else &""


func is_complete() -> bool:
	return index >= drill_count()


## Builds the next drill, ready to run on [param field].
func next_model(field: Rect2) -> DrillModel:
	var model := make_model(current_id())
	model.setup(rng_for(index), field)
	return model


func record(result: DrillResult) -> void:
	results.append(result)
	index += 1


func total() -> int:
	return Rating.total(results)


func running_total() -> int:
	return Rating.total(results)


func attributes() -> Dictionary:
	return Rating.attributes(results)


func attribute_list() -> Array:
	var attrs := attributes()
	var out: Array = []
	for name in Rating.ATTRS:
		out.append(int(attrs[name]))
	return out


func grade() -> String:
	return Tuning.grade_for(total())


func role() -> String:
	return Rating.role(attributes())


func note() -> String:
	return Rating.scout_note(attributes(), grade())
