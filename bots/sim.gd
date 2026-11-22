class_name Sim
extends RefCounted
## Runs drills and whole sessions without a window, as fast as the CPU allows.
## The tests and the balance report go through here, and so does the demo
## data a booth can load to show a full leaderboard before the doors open.

const DT := 1.0 / 120.0
const MAX_SECONDS := 30.0


## One drill played by the bot at [param skill].
static func play(id: StringName, skill: float, seed_value: int) -> DrillResult:
	var model := _model(id, seed_value)
	var bot := DrillBot.create(model, skill, seed_value * 7919 + 17)
	while not model.done and model.t < MAX_SECONDS:
		bot.step(DT)
		model.advance(DT)
	model.take_events()
	return model.result()


## One drill with nobody at the mouse.
static func idle(id: StringName, seed_value: int) -> DrillResult:
	var model := _model(id, seed_value)
	while not model.done and model.t < MAX_SECONDS:
		model.advance(DT)
	return model.result()


static func _model(id: StringName, seed_value: int) -> DrillModel:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, String(id)])
	var model := Session.make_model(id)
	model.setup(rng, Tuning.FIELD)
	return model


## A whole run of eight drills played by the bot.
static func session(skill: float, seed_value: int) -> Session:
	var s := Session.create(seed_value)
	while not s.is_complete():
		var model := s.next_model(Tuning.FIELD)
		var bot := DrillBot.create(model, skill, seed_value * 31 + s.index)
		while not model.done and model.t < MAX_SECONDS:
			bot.step(DT)
			model.advance(DT)
		s.record(model.result())
	return s


static func mean(id: StringName, skill: float, runs: int, first_seed: int = 1) -> float:
	var sum := 0.0
	for i in runs:
		sum += play(id, skill, first_seed + i).score
	return sum / float(runs)


static func mean_total(skill: float, runs: int, first_seed: int = 1) -> float:
	var sum := 0.0
	for i in runs:
		sum += float(session(skill, first_seed + i).total())
	return sum / float(runs)
