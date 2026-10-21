extends "res://tests/support/test_case.gd"
const Layout := preload("res://scripts/map_layout.gd")
const Footprints := preload("res://scripts/drill_layout.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var markers := Layout.drill_markers()
	for i in range(markers.size()):
		var bounds := Footprints.footprint(markers[i])
		for j in range(i+1,markers.size()):
			check(not bounds.grow(0.5).intersects(Footprints.footprint(markers[j]).grow(0.5)),"%s and %s have at least one metre between drill envelopes"%[markers[i].id,markers[j].id])
		for net in Layout.nets():
			var court := Rect2(Vector2(net.position.x-net.width/2,net.position.z-net.depth/2),Vector2(net.width,net.depth))
			check(not bounds.grow(1).intersects(court),"%s clears %s court, including targets and feed machinery"%[markers[i].id,net.id])
	var lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var drills = lab.activities.courses[0]
	var pad: MeshInstance3D = drills.spike_root.get_child(0)
	check(is_equal_approx(pad.mesh.size.z,13.7) and is_equal_approx(pad.position.z+pad.mesh.size.z/2,drills.RUNWAY_START.z),"Spike pad begins exactly at the runway")
	check(is_equal_approx(pad.position.z-pad.mesh.size.z/2,drills.SPIKE_GOAL.z-drills.GOAL_RADIUS),"Spike pad ends at the far edge of the large target ring")
	for body in lab.map_world.solids:
		check(body.get_meta("map_geometry","") in ["wall","net"],"Hosted map terrain has no non-wall obstacles")
	lab.queue_free()
	await process_frame
	print("DRILL SEPARATION: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
