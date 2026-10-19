extends "res://tests/support/test_case.gd"
const Platform := preload("res://scripts/receive_platform.gd")
const Geometry := preload("res://scripts/contact_geometry.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var reference := Platform.definition(1.86, false)
	for diving in [false, true]:
		var standard := Platform.definition(1.86, diving)
		for height in [1.52, 1.67, 1.86, 2.05, 2.18]:
			var shape := Platform.definition(height, diving)
			var scale: float = height / 1.86
			check(Vector3(shape.size).is_equal_approx(Vector3(standard.size) * scale) and Vector3(shape.center).is_equal_approx(Vector3(standard.center) * scale), "Platform height applies one uniform scale")
			check(float(shape.forward_reach) > float(shape.side_reach) and shape.shape == "receive_fan", "Receiving fan extends farther forward than sideways")
			check(Geometry.contains(shape, Vector3(shape.center)) and not Geometry.contains(shape, Vector3(0, shape.center.y, 0.001)), "Fan accepts platform center and forbids contact behind the body")
			check(Geometry.contains(shape, Vector3(shape.side_reach * 0.7, shape.center.y + shape.size.y * 0.45, -shape.forward_reach * 0.5)), "Vertical extrusion is a fan rather than a squeezed ellipsoid")
			var front := Vector3(0, shape.center.y, -shape.forward_reach * 0.8)
			var flank := Vector3(shape.side_reach * 0.75, shape.center.y, -shape.forward_reach * 0.18)
			check(Platform.posture(shape, shape.center, 0) == "planted" and Platform.posture(shape, shape.center, 2) == "moving", "Central contacts distinguish still and moving receive")
			check(Platform.posture(shape, front, 0) == "reaching" and Platform.posture(shape, flank, 2) == "off-axis", "Front and side hurtboxes select reaching/off-axis")
	var left := Geometry.evaluate(reference, Vector3(reference.center) + Vector3(-0.55, 0, -0.25))
	var right := Geometry.evaluate(reference, Vector3(reference.center) + Vector3(0.55, 0, -0.25))
	check(left.quality == right.quality and left.zone == right.zone, "Left/right grades are symmetric, independent of handedness")
	var edge := Geometry.evaluate(reference, Vector3(reference.center) + Vector3(float(reference.size.x) * 0.45, 0, 0))
	check(edge.zone == "SOUR SPOT" and edge.edge, "Existing wide-edge Rolling Receive trigger is preserved")
	check(not Geometry.evaluate(reference, Vector3(reference.center) + Vector3(3, 0, 0)).hit, "Outside platform envelope must miss")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	lab.aim = Vector3(0, 0, -6)
	var origin := Vector3(0, 1.0, 5)
	var incoming := Vector3(0, -8, 0)
	var samples := [Vector3.ZERO, Vector3(0, 0, -0.3), Vector3(0, 0, 0.3), Vector3(0, 0, -0.6), Vector3(0, 0, 0.6), Vector3(-0.55, 0, -0.25), Vector3(0.55, 0, -0.25)]
	for charge in [0.0, 0.3, 0.6, 1.0]:
		var base: Vector3 = lab._shot_velocity(origin, 0, charge)
		var original_time: float = (base.y + sqrt(base.y * base.y + 2 * lab.GRAVITY * (origin.y - 0.105))) / lab.GRAVITY
		var original_range: float = Vector2(base.x, base.z).length() * original_time
		for point in samples:
			var assessment := Geometry.evaluate(reference, Vector3(reference.center) + point)
			var redirected := Platform.redirect(base, origin, 0, incoming, assessment, lab.GRAVITY)
			var time: float = (redirected.y + sqrt(redirected.y * redirected.y + 2 * lab.GRAVITY * (origin.y - 0.105))) / lab.GRAVITY
			check(absf(Vector2(redirected.x, redirected.z).length() * time - original_range) < 0.001, "Each platform trajectory preserves range for the stored charge")
			check(redirected.y <= base.y + 0.001 and redirected.z < 0, "Platform variations stay within bump ceiling and facing cone")
			var yaw := 1.1
			var rotated := Platform.redirect(base.rotated(Vector3.UP, yaw), origin, yaw, incoming.rotated(Vector3.UP, yaw), assessment, lab.GRAVITY)
			check(rotated.is_equal_approx(redirected.rotated(Vector3.UP, yaw)), "Rotating athlete and incoming ball rotates trajectory identically")
		var clean := Geometry.evaluate(reference, Vector3(reference.center))
		check(Platform.redirect(base, origin, 0, incoming, clean, lab.GRAVITY).is_equal_approx(base), "Centered receive retains the existing charge curve")
	var base: Vector3 = lab._shot_velocity(origin, 0, 0.6)
	var left_v := Platform.redirect(base, origin, 0, incoming, left, lab.GRAVITY)
	var right_v := Platform.redirect(base, origin, 0, incoming, right, lab.GRAVITY)
	check(left_v.x < 0 and right_v.x > 0 and absf(left_v.x + right_v.x) < 0.001, "Contact side produces mirrored facing-relative trajectories")
	var wrist := Geometry.evaluate(reference, Vector3(reference.center) + Vector3(0, 0, -0.6))
	var elbow := Geometry.evaluate(reference, Vector3(reference.center) + Vector3(0, 0, 0.6))
	check(Platform.redirect(base, origin, 0, incoming, wrist, lab.GRAVITY).y < Platform.redirect(base, origin, 0, incoming, elbow, lab.GRAVITY).y, "Wrist contact is flatter than elbow contact")
	lab._reset()
	lab.locked_action = 0
	lab.locked_charge = 0.6
	lab.armed = true
	lab.ball_active = true
	lab.ball.position = lab.player.position + Vector3(reference.center) + Vector3(0.55, 0, -0.25)
	lab.ball_velocity = incoming
	lab._confirm_action()
	lab.confirm_window = lab.confirm_duration-0.22
	check(lab.hurtbox_mesh.mesh is ImmediateMesh and lab.hurtbox_root.visible, "Confirmed receive reveals the actual graded volumes")
	lab._contact()
	check(lab.ball_velocity.x > 0 and lab.last_contact_result.physical_hit and lab.last_contact_result.zone == right.zone, "Real contact resolver uses graded platform trajectory and MoC evidence")
	for yaw in [0.0, 0.7, PI * 0.5, PI]:
		lab._reset()
		lab.locked_action = 0
		lab.locked_charge = 0.6
		lab.camera_rig.facing_yaw = yaw
		lab.aim = lab.player.position + Vector3.FORWARD.rotated(Vector3.UP, yaw) * 9
		lab.armed = true
		lab.ball_active = true
		var shape: Dictionary = lab._raw_hurtbox_definition(0)
		lab.ball.position = lab.player.position + (Vector3(shape.center) + Vector3(0.55, 0, -0.25)).rotated(Vector3.UP, yaw)
		lab.ball_velocity = incoming.rotated(Vector3.UP, yaw)
		lab._confirm_action()
		lab.confirm_window = lab.confirm_duration-0.22
		lab._contact()
		var local_velocity: Vector3 = lab.ball_velocity.rotated(Vector3.UP, -yaw)
		check(local_velocity.x > 0 and local_velocity.z < 0, "Live receive trajectory follows contact facing at every world orientation")
	lab._reset()
	lab.locked_action = 0
	lab.ball_active = true
	lab.armed = true
	lab.ball.position = lab.player.position + Vector3(0, 0.95, 0.05)
	lab.contact_memory[0] = 0.1
	check(not lab._can_contact(), "Old overlap memory cannot receive a ball behind the body")
	lab._contact()
	check(lab.contacts == 0, "Behind-body contact cannot bypass the forward fan resolver")
	# Forward-ready arms on every body type, especially the Avi wing chain.
	for type in lab.VoliVisual.Bodies.MODELLED:
		lab._reset()
		lab.body_type = type
		lab._rebuild_visual()
		lab.armed = true
		lab.locked_action = 0
		lab.selected = 0
		lab.ball_active = false
		lab.animation.update()
		for arm in lab.arms:
			var wrist_node: Node3D = arm.get_node("Elbow/Wrist")
			var local_wrist: Vector3 = lab.body.to_local(wrist_node.global_position)
			check(local_wrist.z < -0.25, "Ready hands/forearms must extend in front of the model: " + type)
	# Geometry drives the displayed contact variant through its follow-through.
	var cases := [{"point": Vector3(reference.center), "speed": 0.0, "posture": "planted"}, {"point": Vector3(reference.center), "speed": 2.0, "posture": "moving"}, {"point": Vector3(0, reference.center.y, -reference.forward_reach * 0.8), "speed": 0.0, "posture": "reaching"}, {"point": Vector3(reference.side_reach * 0.75, reference.center.y, -reference.forward_reach * 0.18), "speed": 0.0, "posture": "off-axis"}]
	for item in cases:
		lab._reset()
		lab.player.velocity = Vector3(item.speed, 0, 0)
		lab.locked_action = 0
		lab.locked_charge = 0.6
		lab.armed = true
		lab.ball_active = true
		lab.ball.position = lab.player.position + Vector3(item.point)
		lab.ball_velocity = incoming
		lab._confirm_action()
		lab.confirm_window = lab.confirm_duration-0.22
		lab._contact()
		lab.animation.update()
		check(lab.animation.receive_posture == item.posture and lab.last_contact_result.posture == item.posture and lab.animation.receive_pose_remaining > 0, "Actual contact drives the matching receive animation")
		if item.posture == "reaching":
			check(lab.arms[0].rotation.x > 1.2 and lab.legs[1].get_node("Knee").rotation.x < -0.9, "Reaching pose extends both arms and lunges")
		if item.posture == "off-axis":
			check(absf(lab.arms[0].rotation.y) > 0.1 and absf(lab.body.get_node("Torso").rotation.y) > 0.1, "Off-axis pose turns platform and trunk toward side contact")
	var vertices: PackedVector3Array = Platform.mesh(reference).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var all_forward := true
	for vertex in vertices:
		if (vertex + Vector3(reference.center)).z > 0.00001:
			all_forward = false
	check(all_forward, "Visible receive mesh never extends behind body plane")
	var colors: PackedColorArray = Platform.mesh(reference).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var clean_visible := false
	var sour_visible := false
	for color in colors:
		clean_visible = clean_visible or color.g > color.r * 1.2
		sour_visible = sour_visible or color.r > color.g * 1.2
	check(clean_visible and sour_visible, "Fan debug mesh must display actual clean and sour grading colors")
	print("RECEIVE PLATFORM CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
