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
func shoe_bottom(lab: Node3D) -> float:
	var bottom := INF
	for leg in lab.legs:
		var shoe: MeshInstance3D = leg.get_node("Knee/Shoe")
		var bounds := shoe.get_aabb()
		for i in range(8):
			bottom = minf(bottom, (shoe.global_transform * bounds.get_endpoint(i)).y)
	return bottom
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	for type in lab.VoliVisual.Bodies.MODELLED:
		lab.body_type = type
		lab._rebuild_visual()
		lab.player.velocity = Vector3.ZERO
		lab.jumped = false
		lab.jump_charge = -1
		lab.armed = false
		lab.charging = false
		lab._update_pose()
		var upright: float = lab.body.position.y
		check(absf(lab.legs[0].rotation.z) < 0.001 and absf(lab.legs[0].get_node("Knee").rotation_degrees.x) < 6, "Neutral stance must be narrow and nearly straight: " + type)
		check(absf(shoe_bottom(lab) - lab.player.position.y) < 0.002, "Neutral feet must meet floor: " + type)
		lab.armed = true
		lab.locked_action = 0
		lab._update_pose()
		check(absf(lab.legs[0].rotation.z) > 0.1 and lab.legs[0].get_node("Knee").rotation_degrees.x < -30, "Prepared Receive must load wide defensive base: " + type)
		check(lab.body.position.y < upright - 0.05 and absf(shoe_bottom(lab) - lab.player.position.y) < 0.002, "Receive must lower body while grounding feet: " + type)
		lab.armed = false
		lab.player.velocity = Vector3(0, 0, -2)
		lab.gait_cycle = 0.2
		lab._update_pose()
		check(absf(lab.legs[0].rotation.z) < 0.001 and absf(shoe_bottom(lab) - lab.player.position.y) < 0.002, "Walking must release ready stance and ground support foot: " + type)
	print("STANCE CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
