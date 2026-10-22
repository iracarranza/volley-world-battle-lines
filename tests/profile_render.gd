extends SceneTree
# Real frame times with rendering: godot --path . --script res://tests/profile_render.gd (opens a window)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(lab)
	lab.inventory.enabled = false
	lab.moc.enabled = false
	for i in range(30): await process_frame
	var bots = lab.training_bots
	lab._reset()
	lab.select_net(1)
	for slot in range(bots.settings.size()): bots.dismiss(slot)
	for action in [0,1,2]:
		bots.summon(true,1,action,action+1)
		bots.summon(false,1,action,action+1)
	lab.player.position = lab.court_center+Vector3(0,0.03,lab.court_half_depth+0.4)
	lab.camera_rig.update_aim()
	lab.serve.press()
	lab.serve.basic_strike()
	var times: Array[float] = []
	var last := Time.get_ticks_usec()
	for frame in range(480):
		if not lab.ball_active:
			lab.serve.press()
			lab.serve.basic_strike()
		await process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now
	times.sort()
	var total := 0.0
	for t in times: total += t
	print("frames %d avg %.2f ms (%.0f fps) median %.2f p95 %.2f p99 %.2f worst %.2f" % [times.size(), total / times.size(), 1000.0 / (total / times.size()), times[times.size() / 2], times[int(times.size() * 0.95)], times[int(times.size() * 0.99)], times[-1]])
	for m in [["draw calls", Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME], ["objects", Performance.RENDER_TOTAL_OBJECTS_IN_FRAME], ["primitives", Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME], ["nodes", Performance.OBJECT_NODE_COUNT], ["process ms", Performance.TIME_PROCESS], ["physics ms", Performance.TIME_PHYSICS_PROCESS], ["video MB", Performance.RENDER_VIDEO_MEM_USED]]:
		var v: float = Performance.get_monitor(m[1])
		print("%-12s %.2f" % [m[0], v * (1000.0 if "ms" in String(m[0]) else (1.0 / 1048576.0 if "MB" in String(m[0]) else 1.0))])
	quit()
