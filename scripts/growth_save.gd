extends RefCounted
## G-14 (MS-20): the one call a Workout or Setup completion makes to persist the growth it just earned. Not per tick: once, at completion.
## Returns the text to append to the completion message: empty for an athlete that is not a saved roster athlete (nothing to save),
## "growth saved" after a verified save, "growth NOT saved: ..." when the repository reports a failure.
const Store := preload("res://scripts/athlete_store.gd")

static func at_completion(lab) -> String:
	var result: Dictionary = Store.persist_growth(lab.athlete.build, lab.athlete_name)
	if not bool(result.saved) and str(result.error) == "":
		return ""
	return " / growth saved" if bool(result.saved) else " / growth NOT saved: %s" % result.error
