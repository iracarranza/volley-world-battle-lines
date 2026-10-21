extends "res://tests/support/test_case.gd"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.animation.pose_smoothing = false
	lab.inventory.enabled = true
	lab.inventory.give()
	for kind in ["Avi","Feli"]:
		for height in [1.55,2.10]:
			for ratio in [0.8,1.2]:
				lab.body_type = kind
				lab.athlete.build = {"name":"carry morphology","height":height,"span":height*ratio,"power":65,"speed":65,"accuracy":65,"endurance":65}
				lab._rebuild_visual()
				for hand in ["Left","Right"]:
					lab.dominant_hand = hand
					lab.player.velocity = Vector3(0,0,-2)
					lab.animation.update()
					for age in [0.0,1.5,4.5,6.75,7.15,9.2]:
						lab.player.velocity = Vector3.ZERO
						lab.animation.carry.moving = false
						lab.animation.carry.idle_age = age
						lab.animation.update()
						var carry = lab.animation.carry
						for side in ["Left","Right"]:
							var wrist: Node3D = lab.body.get_node(side+"Arm/Elbow/Wrist")
							var error: float = wrist.global_position.distance_to(carry.evidence[side.to_lower()])
							check(error < 0.075,"%s %.2fm span %.1f %s phase %.2f %s grip reachable (%.3fm)"%[kind,height,ratio,hand,age,side,error])
	lab.queue_free()
	await process_frame
	print("CARRY MORPHOLOGY: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
