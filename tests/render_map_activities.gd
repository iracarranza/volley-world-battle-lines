extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(path: String) -> void:
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	root.size = Vector2i(1600,1000)
	var lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.overview_camera.current = true
	await capture("res://artifacts/map-activities-overview.png")
	var camera := Camera3D.new()
	lab.add_child(camera)
	camera.current = true
	var markers: Array = lab.Layout.drill_markers()
	for kind in ["receive","spike","box","transition"]:
		for marker in markers:
			if marker.type != kind: continue
			lab._reset()
			lab.player.position = marker.position+Vector3.UP*0.03
			lab.activities.select_nearby()
			if kind == "transition": lab.drills.interact()
			camera.position = marker.position+Vector3(12,16,21)
			camera.look_at(marker.position+Vector3.UP)
			lab.hud.update()
			await capture("res://artifacts/map-activities-%s.png"%kind)
			if kind == "transition":
				var basket: Node3D = lab.drills.basket
				camera.position = basket.global_position+basket.normal*6+Vector3(3,2,0)
				camera.look_at(basket.global_position)
				await capture("res://artifacts/map-activities-basket.png")
			break
	var drink: Dictionary = lab.activities.drinks[0]
	lab.player.position = drink.root.position+Vector3(0,0,1)
	lab.athlete.stamina = 20
	camera.position = drink.root.position+Vector3(5,5,7)
	camera.look_at(drink.root.position+Vector3.UP)
	lab.activities.tick(0)
	lab.hud.update()
	await capture("res://artifacts/map-activities-drink.png")
	lab.activities.consume_nearby()
	lab.activities.tick(0)
	lab.hud.update()
	await capture("res://artifacts/map-activities-drink-used.png")
	lab.queue_free()
	await process_frame
	quit()
