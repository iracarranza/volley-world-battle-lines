extends SceneTree
const Store := preload("res://scripts/athlete_store.gd")
const Carry := preload("res://scripts/ball_carry_animation.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(600,700)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.hud.ui.hide()
	lab.animation.pose_smoothing = false
	for body_type in ["Avi","Feli"]:
		var config := Store.blank()
		config.body_type = body_type
		lab.apply_created_athlete(config)
		lab.inventory.enabled = true
		lab.inventory.give()
		lab.player.position = Vector3(10,0.03,20)
		lab.aim = lab.player.position+Vector3.FORWARD*5
		lab.camera_rig.facing_yaw = 0
		var carry = lab.animation.carry
		for sequence in ["idles","ground","cart"]:
			var times := [0.0,1.7,4.7,6.75,7.15,8.7] if sequence == "idles" else [0.0,0.2,0.42,0.65,0.85,1.01]
			var strip := Image.create(300*times.size(),350,false,Image.FORMAT_RGBA8)
			for column in range(times.size()):
				lab.player.velocity = Vector3.ZERO
				carry.moving = false
				carry.pickup_age = -1
				if sequence == "idles":
					carry.idle_age = times[column]
					if column == 0: lab.player.velocity = Vector3(0,0,-2)
				else:
					lab.inventory.record_pickup(sequence,lab.player.global_position+Vector3(0.25,0.105 if sequence == "ground" else 0.84,-0.45))
					lab.animation.update()
					carry.pickup_age = times[column]*(1.05 if sequence == "ground" else 0.7)
				lab.animation.update()
				lab.camera.position = lab.player.position+Vector3(2.3,1.8,-3.0)
				lab.camera.look_at(lab.player.position+Vector3(0,0.9,0))
				await process_frame
				await RenderingServer.frame_post_draw
				var shot := root.get_texture().get_image()
				shot.resize(300,350)
				strip.blit_rect(shot,Rect2i(0,0,300,350),Vector2i(column*300,0))
			strip.save_png("res://artifacts/carry-%s-%s.png"%[body_type.to_lower(),sequence])
	lab.queue_free()
	await process_frame
	quit()
