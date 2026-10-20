extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440,900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var slot: int = lab.training_bots.summon_generic(false,1,{1:0,2:1,3:2},true)
	lab.training_bots.set_intended_charge(slot,false,0.8)
	lab.open_bot_menu()
	var menu = lab.bot_menu
	menu.selected_slot = slot
	menu.refresh()
	menu.load_selected()
	await process_frame
	await process_frame
	var scroll: ScrollContainer = menu.panel.get_child(0)
	scroll.ensure_control_visible(menu.charge)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/bot-charge-controls.png")
	lab.queue_free()
	await process_frame
	quit()
