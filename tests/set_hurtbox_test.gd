extends "res://tests/support/test_case.gd"
const Geometry := preload("res://scripts/contact_geometry.gd")
const Athlete := preload("res://scripts/athlete.gd")
const Store := preload("res://scripts/athlete_store.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var athlete := Athlete.new()
	var shape := Geometry.definition(1, 1.86, athlete.reach(), false, 1.0)
	check(shape.shape == "set_sector" and shape.center.x == 0 and shape.center.z == 0, "Set sector is directly overhead")
	for y in [0.25, 0.6, 1.0]:
		var result := Geometry.evaluate(shape, Vector3(shape.center) + Vector3(0, y, 0))
		check(result.hit and result.zone == "SWEET SPOT" and result.quality == 1.0, "Central vertical column remains sweet across heights")
	var previous := 1.0
	for radius in [0.35, 0.45, 0.6, 0.75, 0.9]:
		var result := Geometry.evaluate(shape, Vector3(shape.center) + Vector3(radius, 0.6, 0))
		check(result.hit and result.quality < previous, "Set quality decreases continuously farther outside column")
		previous = result.quality
	var inside := Geometry.evaluate(shape, Vector3(shape.center) + Vector3(shape.column_radius - 0.0001, 0.6, 0))
	var outside := Geometry.evaluate(shape, Vector3(shape.center) + Vector3(shape.column_radius + 0.0001, 0.6, 0))
	check(absf(inside.quality - outside.quality) < 0.001, "No quality discontinuity at column edge")
	check(Geometry.contains(shape, Vector3(0, 1.86 * 0.78, 0)), "Chin/shoulder-height ball can be set")
	check(not Geometry.contains(shape, Vector3(shape.center) + Vector3(1.5, 0.05, 0)), "Ball outside expanded lower sector misses")
	check(not Geometry.contains(shape, Vector3(shape.center) + Vector3(0, 2, 0)), "Outside spherical radius misses")
	for offset in [Vector3(0.6, 0.6, 0), Vector3(-0.6, 0.6, 0), Vector3(0, 0.6, 0.6), Vector3(0, 0.6, -0.6)]:
		check(absf(Geometry.evaluate(shape, Vector3(shape.center) + offset).quality - Geometry.evaluate(shape, Vector3(shape.center) + Vector3(0.6, 0.6, 0)).quality) < 0.0001, "Set grading is radially symmetric")
	var low := Geometry.definition(1, 1.86, athlete.reach(), false, 1.0, -1, -1, 20)
	var high := Geometry.definition(1, 1.86, athlete.reach(), false, 1.0, -1, -1, 90)
	check(high.column_radius > low.column_radius and high.radius == low.radius, "Ball Control widens column without changing contact reach")
	athlete.build["statistics"] = {"ball_control": 73}
	check(athlete.ball_control() == 70, "Ball Control uses its canonical named rating")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	await physics_frame
	var config := Store.blank()
	config.offsets.accuracy = [8, -4, -4]
	Store.sync_statistics(config)
	lab.apply_created_athlete(config)
	check(lab.athlete.ball_control() == 70, "Creator Ball Control offset survives lab apply")
	var player_shape: Dictionary = lab._hurtbox_definition(1)
	check(player_shape.ball_control == 70 and lab.training_bots.shapes[1].ball_control == 65, "Player and default bots use their own Ball Control")
	lab.selected = 1
	lab.locked_action = 1
	lab.locked_charge = 0.6
	lab.armed = true
	lab._confirm_action()
	check(lab.hurtbox_mesh.mesh is ImmediateMesh, "Displayed Set hurtbox uses actual sector geometry")
	check(lab.confirmed_geometry.column_radius == player_shape.column_radius, "Confirmation freezes exact sweet column")
	var errors: Array[float] = []
	for x in [0.0, 0.8]:
		lab._reset()
		lab.elapsed = 0.15
		lab.selected = 1
		lab.locked_action = 1
		lab.locked_charge = 0.6
		lab.armed = true
		lab.ball_active = true
		lab.camera_rig.facing_yaw = 0
		lab.ball.position = lab.player.position + Vector3(player_shape.center) + Vector3(x, 0.6, 0)
		lab.aim = lab.ball.position + Vector3.FORWARD * 5
		var expected: Vector3 = lab._shot_velocity(lab.ball.position, 1, 0.6)
		lab._confirm_action()
		lab.confirm_window = lab.confirm_duration-0.22
		lab._contact()
		errors.append(absf(expected.signed_angle_to(lab.ball_velocity, Vector3.UP)))
		check(lab.last_contact_result.physical_hit, "Real Set contact uses the spherical sector")
	check(errors[0] < 0.01 and errors[1] > errors[0] + 0.01, "Off-column Set produces greater actual outgoing error")
	lab.selected = 1
	lab.armed = true
	lab._confirm_action()
	if "--render" in OS.get_cmdline_user_args():
		root.size = Vector2i(1440, 900)
		lab.animation.update()
		lab.camera_rig.update(2)
		lab.hud.update()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/rally-set-sector.png")
	print("SET HURTBOX: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
