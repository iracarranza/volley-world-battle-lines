extends SceneTree
# The Esc settings menu, and the vision focus beam at three moments: godot --path . --script res://tests/render_vision_menu.gd
func _initialize() -> void: call_deferred("capture")
func key_escape(lab: Node) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	lab._input(event)
func capture() -> void:
	root.size = Vector2i(1280, 720)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	for i in range(12): await process_frame
	root.get_texture().get_image().save_png("res://artifacts/vision-0-hud.png")
	key_escape(lab)
	for i in range(4): await process_frame
	root.get_texture().get_image().save_png("res://artifacts/vision-1-settings.png")
	key_escape(lab)
	var Vision = load("res://scripts/vision_focus.gd")
	Vision.enabled = true
	lab.set_physics_process(false)
	lab.auto_feed = false
	lab.ball_active = true
	lab.armed = true
	lab.locked_action = 2
	lab.locked_charge = 0.9
	lab.ball.position = lab.player.position + Vector3(0.6, 2.4, -3.0)
	lab.ball_velocity = Vector3(0, -1, -2)
	for step in range(3):
		for i in range(8 if step == 0 else 40): await process_frame
		print("vision ", step, " quad visible ", lab.vision.quad.visible, " strength ", lab.vision.strength, " age ", lab.vision.age, " armed ", lab.armed, " ball ", lab.ball_active, " enabled ", lab.vision.enabled)
		root.get_texture().get_image().save_png("res://artifacts/vision-%d-beam.png" % (2 + step))
	quit()
