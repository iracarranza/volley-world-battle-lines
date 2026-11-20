extends "res://tests/support/test_case.gd"
## MS-20 (G-14): Workout and Setup growth is saved once, at completion, through the repository; honest on failure; nothing written for an unsaved athlete.
const Store := preload("res://scripts/athlete_store.gd")
const GrowthSave := preload("res://scripts/growth_save.gd")
const Progress := preload("res://scripts/workout_progress.gd")
const Grants := preload("res://scripts/setup_grants.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var dir := "user://growth_save_test"
	DirAccess.make_dir_recursive_absolute(dir)
	var original: String = Store.save_path
	Store.save_path = dir + "/athletes.json"
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(Store.save_path + suffix): DirAccess.remove_absolute(Store.save_path + suffix)
	var config := Store.blank()
	config.name = "Grower"
	Store.roster = [config]
	Store.selected = 0
	Store.save_roster()
	var lab: Node = load("res://main.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	lab.apply_created_athlete(Store.selected_config())
	var before := FileAccess.get_file_as_string(Store.save_path)
	# Completing a Workout counts, then persists once.
	var progress: Dictionary = Progress.record(lab.athlete, "explosiveness")
	check(FileAccess.get_file_as_string(Store.save_path) == before, "Recording progress alone writes nothing (not per tick)")
	check(GrowthSave.at_completion(lab) == " / growth saved", "The completion call reports a verified save")
	Store.load_roster()
	check(int(Store.roster[0].workout_counts.get("explosiveness", 0)) == int(lab.athlete.build.workout_counts.explosiveness), "The Workout count is in the file")
	# A Setup grant persists and comes back with the athlete.
	Grants.grant(lab.athlete, "SPIKE TRAINER")
	check(GrowthSave.at_completion(lab) == " / growth saved", "A Setup completion saves")
	Store.load_roster()
	lab.apply_created_athlete(Store.selected_config())
	check(float(lab.athlete.build.drill_auxiliaries.get("spike_velocity", 0.0)) == 1.0, "The Setup grant is loaded back")
	check(int(lab.athlete.build.workout_counts.explosiveness) == int(progress.count), "The Workout count is loaded back")
	# A gained point survives the round trip through migrate.
	lab.athlete.build["workout_counts"]["explosiveness"] = 99
	var gained: Dictionary = Progress.record(lab.athlete, "explosiveness")
	GrowthSave.at_completion(lab)
	Store.load_roster()
	check(gained.gained and float(Store.roster[0].statistics.explosiveness) == float(lab.athlete.build.statistics.explosiveness), "A gained sub-attribute point is saved")
	# An athlete that is not the saved one writes nothing.
	lab.athlete_name = "Somebody Else"
	var stamp := FileAccess.get_file_as_string(Store.save_path)
	check(GrowthSave.at_completion(lab) == "" and FileAccess.get_file_as_string(Store.save_path) == stamp, "A non-roster athlete is not saved and nothing is written")
	lab.athlete_name = "Grower"
	# Unwritable location is reported, never 'saved'.
	var good: String = Store.save_path
	Store.save_path = "user://no_such_dir_ms20/athletes.json"
	var text := GrowthSave.at_completion(lab)
	check(text.begins_with(" / growth NOT saved"), "An unwritable location reports the failure")
	Store.save_path = good
	# No roster at all (the test and default case): silent.
	Store.roster = []
	Store.selected = -1
	check(GrowthSave.at_completion(lab) == "", "No roster athlete means no save attempt")
	Store.save_path = original
	lab.queue_free()
	await process_frame
	print("GROWTH SAVE: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
