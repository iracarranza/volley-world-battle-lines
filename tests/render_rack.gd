extends SceneTree
# The Setup ball rack in its three states: godot --path . --script res://tests/render_rack.gd
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1200, 700)
	var lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(lab)
	for i in range(10): await process_frame
	var spike = lab.activities.courses[0]
	var camera := Camera3D.new()
	lab.add_child(camera)
	var rack_at: Vector3 = spike.rack.global_position
	camera.global_position = rack_at + Vector3(0.0, 1.5, 4.2)
	camera.look_at(rack_at + Vector3(0, 1.1, 0))
	camera.make_current()
	for child in lab.get_children():
		if child is CanvasLayer: child.hide()
	var states := []
	spike.distributor.balls = 10
	spike.distributor.phase = spike.distributor.Phase.READY
	states.append("ready")
	await _shot(spike, "ready")
	spike.distributor.phase = spike.distributor.Phase.RUNNING
	spike.distributor.balls = 5
	await _shot(spike, "running")
	spike.distributor.phase = spike.distributor.Phase.COOLDOWN
	spike.distributor.cooldown = 30.0
	spike.distributor.pile = 6
	spike.distributor.pile_owner = "player"
	await _shot(spike, "reward")
	quit()
func _shot(spike, name: String) -> void:
	for i in range(60):
		spike.tick_setup(1.0 / 60.0)
		await process_frame
	print(name, " phase ", spike.distributor.phase, " pile ", spike.distributor.pile, " label ", spike.setup_label.text, " rack ", spike.rack.label.text, " balls ", spike.rack.visible_balls())
	root.get_texture().get_image().save_png("res://artifacts/rack-%s.png" % name)
