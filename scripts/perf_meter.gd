extends CanvasLayer
## A small performance readout in the top right: frame rate, frame time (average and worst over the last second), engine process and physics time,
## draw calls, objects, nodes and memory. F3 shows or hides it.
const REFRESH := 0.25
const WINDOW := 1.0
var label: Label
var frame_times: Array[float] = []
var window_time := 0.0
var since_refresh := 0.0

func _init() -> void:
	layer = 100
	label = Label.new()
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("9be7ff"))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.offset_left = -330.0
	label.offset_right = -12.0
	label.offset_top = 8.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func _process(delta: float) -> void:
	frame_times.append(delta)
	window_time += delta
	while window_time > WINDOW and frame_times.size() > 1:
		window_time -= frame_times.pop_front()
	since_refresh += delta
	if since_refresh >= REFRESH and visible:
		since_refresh = 0.0
		label.text = report()

func report() -> String:
	var worst := 0.0
	var total := 0.0
	for frame in frame_times:
		worst = maxf(worst, frame)
		total += frame
	var average := total / maxf(float(frame_times.size()), 1.0)
	return "%d FPS\nframe %.1f ms avg / %.1f ms worst\nprocess %.1f ms / physics %.1f ms\ndraw calls %d / objects %d\nnodes %d / physics objects %d\nmemory %.0f MB / video %.0f MB" % [
		Engine.get_frames_per_second(), average * 1000.0, worst * 1000.0,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0]

func toggle() -> void:
	visible = not visible
	if visible:
		label.text = report()
