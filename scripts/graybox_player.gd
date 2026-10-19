extends CharacterBody3D

# A traversal-only body for the map graybox: walk, sprint, charged jump, third-person camera. Nothing else. It shares no code with
# the Contact Lab.
const WALK_SPEED := 5.9
const SPRINT_SPEED := 7.8
const GRAVITY := 9.81
const ACCEL := 32.0
const AIR_ACCEL := 3.0
const MIN_JUMP := 0.6
const MAX_JUMP := 1.6
const MOBILITY_JUMP := 2.7        # a stand-in for a mobility Trait; toggled with G so high routes can be tried
const CHARGE_TIME := 0.8
const CAMERA_DISTANCE := 6.5
const CAMERA_HEIGHT := 1.5
const MOUSE_SENSITIVITY := 0.0028
const RADIUS := 0.35
const HEIGHT := 1.8

var yaw := 0.0
var pitch := -0.28
var charge := -1.0               # seconds Space has been held on the floor, or -1
var mobility := false
var sprinting := false
var facing := 0.0
var camera: Camera3D
var body_mesh: MeshInstance3D
var capsule_material: StandardMaterial3D
# For tests: a scripted body ignores the keyboard and is stepped by calling tick() directly.
var scripted := false
var scripted_move := Vector3.ZERO
var scripted_sprint := false

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	shape.shape = capsule
	shape.position.y = HEIGHT * 0.5
	add_child(shape)
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.3
	body_mesh = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = RADIUS
	mesh.height = HEIGHT
	body_mesh.mesh = mesh
	body_mesh.position.y = HEIGHT * 0.5
	capsule_material = StandardMaterial3D.new()
	capsule_material.albedo_color = Color("54ead0")
	body_mesh.material_override = capsule_material
	add_child(body_mesh)
	var nose := MeshInstance3D.new()
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.18, 0.18, 0.36)
	nose.mesh = nose_mesh
	nose.position = Vector3(0.0, HEIGHT * 0.78, -RADIUS)
	var nose_material := StandardMaterial3D.new()
	nose_material.albedo_color = Color("ffce73")
	nose.material_override = nose_material
	body_mesh.add_child(nose)
	nose.position = Vector3(0.0, HEIGHT * 0.28, -RADIUS)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.top_level = true
	add_child(camera)
	camera.current = true

func _unhandled_input(event: InputEvent) -> void:
	if scripted:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * MOUSE_SENSITIVITY
		pitch = clampf(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.2, 0.5)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_G:
		mobility = not mobility
	elif event is InputEventKey and event.keycode == KEY_SPACE:
		if event.pressed and not event.echo and is_on_floor() and charge < 0.0:
			charge = 0.0
		elif not event.pressed and charge >= 0.0:
			release_jump()

func _physics_process(delta: float) -> void:
	# A scripted body is stepped by whoever scripts it, through tick().
	if scripted:
		return
	var wish := scripted_move
	var run := scripted_sprint
	if not scripted:
		var input := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		wish = (Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)).limit_length(1.0)
		run = Input.is_physical_key_pressed(KEY_SHIFT)
	tick(delta, wish, run)

# One step of movement. `wish` is a world-space direction of length 0 to 1.
func tick(delta: float, wish: Vector3, run: bool) -> void:
	sprinting = run
	var top_speed := SPRINT_SPEED if run else WALK_SPEED
	if is_on_floor():
		var target := wish * top_speed
		velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
		velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		var target := wish * top_speed
		velocity.x = move_toward(velocity.x, target.x, AIR_ACCEL * delta)
		velocity.z = move_toward(velocity.z, target.z, AIR_ACCEL * delta)
		velocity.y -= GRAVITY * delta
	if charge >= 0.0:
		charge += delta
		if charge >= CHARGE_TIME:
			release_jump()
	move_and_slide()
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.3:
		facing = lerp_angle(facing, atan2(-velocity.x, -velocity.z), minf(1.0, delta * 12.0))
		body_mesh.rotation.y = facing
	body_mesh.scale.y = 0.86 if charge >= 0.0 else 1.0
	body_mesh.position.y = HEIGHT * 0.5 * body_mesh.scale.y

func jump_height(held: float) -> float:
	var top := MOBILITY_JUMP if mobility else MAX_JUMP
	return lerpf(MIN_JUMP, top, clampf(held / CHARGE_TIME, 0.0, 1.0))

func release_jump() -> void:
	if charge < 0.0:
		return
	var height := jump_height(charge)
	charge = -1.0
	if is_on_floor():
		velocity.y = sqrt(2.0 * GRAVITY * height)

func _process(_delta: float) -> void:
	if camera == null or not camera.current:
		return
	var pivot := global_position + Vector3.UP * CAMERA_HEIGHT
	var offset := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Vector3(0.0, 0.0, CAMERA_DISTANCE)
	var wanted := pivot + offset
	var query := PhysicsRayQueryParameters3D.create(pivot, wanted, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		wanted = hit.position.lerp(pivot, 0.08)
	camera.global_position = wanted
	camera.look_at(pivot, Vector3.UP)

# Put the body somewhere new, standing and still.
func place(position_in_world: Vector3, face_yaw: float = 0.0) -> void:
	global_position = position_in_world
	velocity = Vector3.ZERO
	charge = -1.0
	yaw = face_yaw
	facing = face_yaw
