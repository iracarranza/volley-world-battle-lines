extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var editor = load("res://scripts/trait_tree_editor.gd").new()
	root.add_child(editor)
	await process_frame
	editor.show_page("power")
	editor.select("new_trait")
	check(editor.effects_box.get_child_count() == 1,"Inspector shows authored gameplay effect")
	var row = editor.effects_box.get_child(0)
	var amount: SpinBox = row.get_child(1)
	amount.value = 14
	check(editor.book.nodes[editor.book.find("new_trait")].effects.spike_velocity == 14,"Numeric inspector edits actual runtime field")
	editor.effect_pick.select(editor.EFFECT_KEYS.find("charge_tolerance"))
	(editor.effect_pick.get_parent().get_child(1) as Button).pressed.emit()
	check(editor.effects_box.get_child_count() == 2,"Designer can add another supported effect")
	editor.save_path = "user://trait_effect_editor_test.json"
	check(editor.save(),"Effect-bearing book can be saved")
	var reloaded = load("res://scripts/trait_book.gd").new()
	reloaded.load_book(editor.save_path)
	check(reloaded.nodes[reloaded.find("new_trait")].effects.spike_velocity == 14,"Inspector changes persist through reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(editor.save_path))
	editor.queue_free()
	await process_frame
	print("TRAIT EFFECT EDITOR: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
