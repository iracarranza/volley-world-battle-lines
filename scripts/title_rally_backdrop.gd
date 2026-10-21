extends SubViewportContainer
## Title-screen backdrop: the real bot rally, seen from the side as one flat grey silhouette. A hidden lab runs in its own viewport with bots on
## both sides; an orthographic side camera looks along the net and every mesh is drawn in one unshaded colour. The rally grows from 1v1 to 2v2,
## 3v3 and 5v5, then starts over. Presentation only: it never touches the player's lab or save data.

const LAB := preload("res://map_graybox.tscn")
const Bodies := preload("res://vendor/vwm/body_type_models.gd")
const Visual := preload("res://scripts/voli_visual.gd")
const BLOCK := Color(0.1, 0.13, 0.16) # the one silhouette colour; the title's own background shows through everywhere else
const TEAMS := [
	[{1: 0, 2: 1, 3: 2}],
	[{1: 0, 3: 2}, {2: 1}],
	[{1: 0}, {2: 1}, {3: 2}],
	[{1: 0}, {2: 1}, {3: 2}, {}, {1: 0}],
]
const SIDE_CAMERA_DISTANCE := 16.0

var lab: Node3D
var viewport: SubViewport
var camera: Camera3D
var scene_index := 0
var rally_started := false
var wait := 1.0
var rng := RandomNumberGenerator.new()
var flat: StandardMaterial3D
var painted := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stretch = true
	modulate = BLOCK # everything the viewport draws is white and unshaded, so this tint makes it one flat grey
	rng.seed = 7
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.BLACK
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	flat = StandardMaterial3D.new()
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flat.albedo_color = Color.WHITE
	flat.cull_mode = BaseMaterial3D.CULL_DISABLED
	lab = LAB.instantiate()
	viewport.add_child(lab)
	lab.set_process_input(false)
	lab.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().physics_frame
	# Enter Map can remove the title while this setup is still waiting: stop quietly.
	if not is_inside_tree() or not is_instance_valid(lab) or not lab.is_inside_tree():
		return
	lab.moc.enabled = false
	lab.select_net(0)
	# The lab picks the court nearest the player, so the (hidden) player waits just behind the home end line of this court.
	lab.player.position = lab.court_center + Vector3(0, 0.03, lab.court_half_depth + 0.6)
	lab.player.hide()
	for child in lab.get_children():
		if child is CanvasLayer:
			child.hide()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15.0
	camera.near = 5.0 # clips the lab's side fixtures between the camera and the court
	camera.far = SIDE_CAMERA_DISTANCE + 6.0
	viewport.add_child(camera)
	# Looking along the net from +x with the net centred on screen and the floor about three quarters of the way down.
	var view_centre: Vector3 = lab.court_center + Vector3(0, 4.2, 0)
	camera.position = view_centre + Vector3(SIDE_CAMERA_DISTANCE, 0, 0)
	camera.look_at(view_centre)
	camera.make_current()
	var bots = lab.training_bots
	bots.set_targets["0:false"] = lab.court_center + Vector3(-1.2, 0, 0.9)
	bots.set_targets["0:true"] = lab.court_center + Vector3(1.2, 0, -0.9)
	lab.debug_volumes_visible = false
	lab.debug_feed_locked = true
	lab.debug_feed_target = lab.court_center + Vector3(0, 0.95, 3.8)
	_populate()

func _populate() -> void:
	var bots = lab.training_bots
	for slot in range(bots.settings.size()):
		if bots.settings[slot].enabled:
			bots.dismiss(slot)
	for away in [false, true]:
		for player_index in range(TEAMS[scene_index].size()):
			var plan: Dictionary = TEAMS[scene_index][player_index]
			var blocking := player_index == 0 or (scene_index == 3 and player_index == 3)
			var slot: int = bots.summon_generic(away, 0, plan, blocking)
			if slot >= 0:
				bots.set_tracking_accuracy(slot, 75.0)
				bots.set_aiming_accuracy(slot, 65.0)
				bots.set_charge_accuracy(slot, 70.0)
				_randomise_look(slot)
	_paint()
	# Building a body briefly adds the actor scene (with its own camera) to this viewport: the side camera takes over again.
	camera.make_current()
	painted = 0
	rally_started = false
	wait = 1.0

# A different body type, height and wingspan for each player (presentation only: the bot keeps its normal physique for contact geometry).
func _randomise_look(slot: int) -> void:
	var bots = lab.training_bots
	var height := rng.randf_range(1.55, 2.12)
	var build := {"height": height, "span": height * rng.randf_range(0.93, 1.1), "name": "Backdrop", "dominant_hand": "Right", "role": "OH"}
	var body_type: String = Bodies.MODELLED[rng.randi() % Bodies.MODELLED.size()]
	var old: Dictionary = bots.rigs[slot]
	bots.animation.states.erase(old.body.get_instance_id())
	var rig: Dictionary = Visual.build(lab, bots.actors[slot], body_type, {"palette_index": 0, "marking": "none"}, build)
	old.body.queue_free()
	bots.rigs[slot] = rig

# One colour for everything that draws, re-applied as new bot visuals appear.
func _paint() -> void:
	# No debug geometry: contact boxes, hurtbox fans, reach rings and markers stay hidden.
	for box in lab.training_bots.contact_boxes:
		box.visible = false
	for debug_node in [lab.hurtbox_root, lab.aim_marker, lab.reach_ring, lab.body_collision_view]:
		if debug_node != null:
			debug_node.visible = false
	# The bots' role captions would draw as black text boxes: they are switched off.
	for caption in lab.find_children("*", "Label3D", true, false):
		(caption as Label3D).visible = false
	for light in lab.find_children("*", "Light3D", true, false):
		(light as Light3D).visible = false
	for node in lab.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		# Effect meshes driven by shader parameters (impact flashes and the like) are not silhouettes: they are made fully transparent and
		# left alone, so their scripts keep working.
		if geometry.material_override is ShaderMaterial:
			geometry.transparency = 1.0
			continue
		if geometry.material_override != flat:
			geometry.material_override = flat

func _physics_process(delta: float) -> void:
	if lab == null or camera == null:
		return
	painted += 1
	if painted % 15 == 1:
		_paint()
	var bots = lab.training_bots
	if lab.ball_active:
		rally_started = true
		return
	if rally_started:
		# One completed rally per composition, including serves that end without a contact.
		scene_index = (scene_index + 1) % TEAMS.size()
		_populate()
		return
	wait -= delta
	if wait > 0.0 or not bots.ready_to_serve():
		return
	bots.total_contacts = 0
	lab._feed()
	rally_started = lab.ball_active
	wait = 1.2
