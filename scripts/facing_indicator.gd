extends Control
var lab: Node3D
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(_dt: float) -> void:
	if not is_instance_valid(lab):
		return
	visible = lab.camera_mode == lab.ViewMode.BALL
	if visible:
		queue_redraw()
func _draw() -> void:
	if not is_instance_valid(lab):
		return
	var center := Vector2(36, 38)
	var forward: Vector3 = -lab.camera.global_basis.z
	forward.y = 0
	if forward.length_squared() < 0.001:
		forward = Vector3(-sin(lab.ball_movement_yaw), 0, -cos(lab.ball_movement_yaw))
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var facing := Vector3(-sin(lab._contact_yaw()), 0, -cos(lab._contact_yaw()))
	var direction := Vector2(facing.dot(right), -facing.dot(forward)).normalized()
	draw_circle(center, 24, Color(0.04, 0.09, 0.13, 0.82))
	draw_arc(center, 24, 0, TAU, 48, Color("688796"), 1, true)
	draw_line(center - direction * 12, center + direction * 17, lab.GOLD, 3, true)
	var side := direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([center + direction * 19, center + direction * 8 + side * 6, center + direction * 8 - side * 6]), lab.GOLD)
	draw_string(ThemeDB.fallback_font, Vector2(14, 7), "FACING", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d3e5ee"))
