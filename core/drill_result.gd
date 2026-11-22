class_name DrillResult
extends RefCounted
## What one drill hands back: a 0..100 score, one line a spectator can read,
## and the raw numbers behind it.

var id: StringName = &""
var title: String = ""
var score: float = 0.0
var headline: String = ""
var metrics: Dictionary = {}


static func make(p_id: StringName, p_title: String, p_score: float, p_headline: String, p_metrics: Dictionary = {}) -> DrillResult:
	var r := DrillResult.new()
	r.id = p_id
	r.title = p_title
	r.score = clampf(p_score, 0.0, 100.0)
	r.headline = p_headline
	r.metrics = p_metrics
	return r


## Letter shown on the stamp after each drill.
func stamp() -> String:
	if score >= 92.0:
		return "PERFECT"
	if score >= 78.0:
		return "GREAT"
	if score >= 58.0:
		return "GOOD"
	if score >= 35.0:
		return "OK"
	return "ROUGH"


func to_dict() -> Dictionary:
	return {"id": String(id), "score": snappedf(score, 0.1), "headline": headline}
