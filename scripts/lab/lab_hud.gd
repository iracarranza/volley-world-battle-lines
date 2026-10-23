class_name LabHud
extends RefCounted

## Owns hud state. LabSession schedules updates and composes peers.
const ReceiveCharge := preload("res://scripts/receive_charge.gd")
const MoC := preload("res://scripts/moment_of_contact.gd")
const Athlete = preload("res://scripts/athlete.gd")
const Approach = preload("res://scripts/approach_run.gd")
const ACTIONS = preload("res://scripts/contact/action.gd").CONTACT_LABELS
const TEAL = Color("54ead0")
const GOLD = Color("ffce73")
const ViewMode = LabCamera.ViewMode

var lab: LabSession
var ui: CanvasLayer
var info: Label
var status: Label
var metrics: Label
var charge_label: Label
var athlete_hud: Control
var hp_bar: ProgressBar
var sta_bar: ProgressBar
var station_status: Label
var bot_buttons: Array[Button] = []
var bot_status: Label
var bot_panel: PanelContainer
var bot_scroll: ScrollContainer
var menu_panels: Array[Control] = []
var bot_modes: Array[OptionButton] = []
var action_wheel: Control
var build_button: Button
var camera_badge: Label
var ball_edge_indicator: Label
var facing_compass: Control
var help_panel: PanelContainer
var moc_menu: RefCounted
var moc_button: Button
var debug_button: Button
var rotate_button: Button
var auto_feed_button: Button
var settings_menu: RefCounted
var vision_menu: RefCounted
var menus_button: Button

func panel(pos: Vector2, size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.custom_minimum_size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142536")
	style.border_color = Color("30485b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", style)
	ui.add_child(p)
	return p

func label(text: String, size: int = 16, color: Color = Color("d8e8ed")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(130, 36)
	b.pressed.connect(callback)
	b.focus_mode = Control.FOCUS_NONE
	return b

func bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(255, 9)
	b.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	b.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color("293e50")
	b.add_theme_stylebox_override("background", back)
	return b

func bot_aim_control(title: String, value: float, changed: Callable, charge_control: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	var caption := label("%s: %d%%" % [title, value], 12)
	caption.custom_minimum_size.x = 185
	row.add_child(caption)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = value
	slider.custom_minimum_size.x = 220
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	slider.tooltip_text = "100% adds no aim error; 0% allows up to 2.5 m scatter at floor intercept. Contact quality still matters. Receivers keep their same-side setter heading and vary depth."
	if charge_control:
		slider.tooltip_text = "Charge accuracy controls preparation target error separately from tracking and aim. 100% targets the clean band; limited preparation time can still undercharge."
	slider.value_changed.connect(func(next: float):
		changed.call(next)
		caption.text = "%s: %d%%" % [title, next]
	)
	row.add_child(slider)
	return row

func build() -> void:
	ui = CanvasLayer.new()
	lab.add_child(ui)
	var top := panel(Vector2(24, 20), Vector2(1392, 85))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	top.add_child(row)
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	title.add_child(label("RALLY LANES", 27, TEAL))
	title.add_child(label("CONTACT LAB   /   C CREATE ATHLETE   /   M MAIN MENU", 12, Color("8faabb")))
	build_button = button("", lab._cycle_build)
	var title_button := button("TITLE  [M]", lab._return_to_title)
	var feed_button := button("FEED BALL  [B]", lab._feed)
	auto_feed_button = button("AUTO FEED: OFF", func():
		lab.auto_feed = not lab.auto_feed
		auto_feed_button.text = "AUTO FEED: " + ("ON" if lab.auto_feed else "OFF")
	)
	var reset_button := button("RESET  [T]", lab._reset)
	var create_button := button("CREATE  [C]", func(): lab.creator.open())
	var left := panel(Vector2(24, 126), Vector2(295, 240))
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 10)
	left.add_child(stats)
	stats.add_child(label("ATHLETE / LIVE RESOURCES", 13, TEAL))
	info = label("", 15)
	stats.add_child(info)
	metrics = label("", 13)
	stats.add_child(metrics)
	# Legacy panel handles remain for callers; the unified inspector owns bot UI.
	bot_panel = panel(Vector2.ZERO,Vector2.ONE)
	bot_panel.hide()
	bot_scroll = ScrollContainer.new()
	bot_panel.add_child(bot_scroll)
	bot_status = label("",12)
	bot_panel.add_child(bot_status)
	var station_panel := panel(Vector2(345, 126), Vector2(670, 102))
	station_status = label("", 13, Color("a8cbff"))
	station_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	station_status.custom_minimum_size = Vector2(630, 74)
	station_panel.add_child(station_status)
	athlete_hud = preload("res://scripts/athlete_hud.gd").new()
	ui.add_child(athlete_hud)
	athlete_hud.setup(lab)
	hp_bar = athlete_hud.hp_bar
	sta_bar = athlete_hud.sta_bar
	var bottom := Control.new()
	ui.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_left = -320
	bottom.offset_right = 320
	bottom.offset_top = -150
	bottom.offset_bottom = -90
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status = label("", 14, TEAL)
	status.add_theme_color_override("font_outline_color", Color("0e2532"))
	status.add_theme_constant_override("outline_size", 3)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(status)
	charge_label = label("", 12)
	charge_label.position = Vector2(0, -55)
	charge_label.size = Vector2(640, 50)
	charge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(charge_label)
	action_wheel = preload("res://scripts/action_wheel.gd").new()
	action_wheel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	action_wheel.offset_left = -364
	action_wheel.offset_top = -364
	action_wheel.offset_right = -24
	action_wheel.offset_bottom = -24
	ui.add_child(action_wheel)
	help_panel = panel(Vector2(390, 180), Vector2(660, 460))
	var help := VBoxContainer.new()
	help.add_theme_constant_override("separation", 14)
	help_panel.add_child(help)
	help.add_child(label("MAKE THE CONTACT", 25, TEAL))
	help.add_child(label("1   Select 1 receive, 2 set, 3 attack or 4 block.\n\n2   Hold left mouse to choose power, then release.\n      A quick tap prepares AUTO; Reaction Speed controls adaptation.\n\n3   Click again as the ball enters your reach ring.\n      Confirm is buffered for a short timing window.\n\nAttack + Space: long right, short left, inward right.\nFourth step launches upward. Right lead is fixed for now.\nReceive + Space: split step, move freely, release to dive.\nClick confirms Receive and cancels a pending dive.\nSet / Block: charge a direct jump; hold movement for carry.\nAttack: full approach gives the strongest spike jump.\n\nReceive low. Set overhead. Jump to spike or block.\nAim across the Net to score; keep sets on your side.\nAfter three personal contacts, return the ball.\n\nRight mouse cancels a grounded preparation.\nHold E: channel a safe standing serve. Tap E: toss; tap again to swing. Rising contact lofts higher. Quick Step: double-tap a direction while an action is charged. B feeds a debug ball. T resets. P pauses. H toggles help.\nI: inspect nearby bot; otherwise start / retry / stop drill.\nEast: Serve Receive. West: Spike Trainer. West lane: Box Jump.\nG: summon a bot here. I: inspect nearby bot. F9: roster.\nK: toggle hit/hurtboxes. Purple circles: serve to start Pepper.\nF5: feed landing here. F6: set target here. Shift+F6: receive target here. F7: tracking feed.\nV switches Athlete View / Ball View.\nMouse looks around. WASD is relative to the view.\nEsc releases the cursor for buttons; click court to return.", 17))
	help.add_child(button("LET’S PLAY", func():
		help_panel.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	))
	help_panel.hide()
	camera_badge = label("", 15, GOLD)
	camera_badge.position = Vector2(1040, 126)
	ui.add_child(camera_badge)
	menu_panels.assign([top, left, station_panel, charge_label])
	for menu in menu_panels:
		menu.hide()
	# The ribbon is gone: its controls live in the Esc settings menu.
	moc_menu = preload("res://scripts/lab/moc_menu.gd").new(self)
	settings_menu = preload("res://scripts/lab/settings_menu.gd").new(self)
	menus_button = button("INFO PANELS", func():
		var show_menus := not top.visible
		for menu in menu_panels:
			menu.visible = show_menus
	)
	menus_button.tooltip_text = "Show or hide the title bar and the athlete, station and charge panels."
	debug_button = button("BOXES: ON [K]", toggle_debug_volumes)
	rotate_button = button("TILT BOXES: ON", toggle_rotating_hurtboxes)
	rotate_button.tooltip_text = "Hurtboxes tilt with the aimed angle. Off keeps them level."
	moc_button = button("MoC: STEERING [O]", toggle_moc_mode)
	moc_button.tooltip_text = "Cycle Current, Tuned, Off and Trajectory Steering; open Contact Settings to tune local slowdown."
	var perf_button := button("PERFORMANCE [F3]", func(): lab.perf_meter.toggle())
	settings_menu.section("ATHLETE & SESSION")
	settings_menu.add_button(build_button)
	settings_menu.add_button(create_button)
	settings_menu.add_button(reset_button)
	settings_menu.add_button(feed_button)
	settings_menu.add_button(auto_feed_button)
	settings_menu.add_button(title_button)
	settings_menu.section("DISPLAY")
	settings_menu.add_button(menus_button)
	settings_menu.add_button(button("HIDE HUD [F8]", func():
		ui.visible = false
		settings_menu.set_open(false)
	))
	settings_menu.add_button(debug_button)
	settings_menu.add_button(rotate_button)
	settings_menu.add_button(perf_button)
	settings_menu.section("PRACTICE")
	settings_menu.add_button(button("BOTS [F9]", func():
		settings_menu.set_open(false)
		toggle_bot_menu()
	))
	settings_menu.section("CONTACT")
	settings_menu.add_button(moc_button)
	settings_menu.add_button(button("CONTACT SETTINGS", func():
		settings_menu.set_open(false)
		moc_menu.toggle()
	))
	vision_menu = preload("res://scripts/lab/vision_menu.gd").new(self)
	facing_compass = preload("res://scripts/facing_indicator.gd").new()
	facing_compass.lab = lab
	ui.add_child(facing_compass)
	facing_compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	facing_compass.offset_left = 248
	facing_compass.offset_right = 330
	facing_compass.offset_top = -94
	facing_compass.offset_bottom = -16
	facing_compass.hide()
	ball_edge_indicator = label("", 14, GOLD)
	ball_edge_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ball_edge_indicator.hide()
	ui.add_child(ball_edge_indicator)
	var reticle := label("+", 22, Color(0.85, 0.97, 1.0, 0.65))
	reticle.position = Vector2(710, 438)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(reticle)

func toggle_moc_mode() -> void:
	lab.moc.set_mode((lab.moc.mode + 1) % 4)
	moc_button.text = ["MoC: CURRENT [O]", "MoC: TUNED [O]", "MoC: OFF [O]", "MoC: STEERING [O]"][lab.moc.mode]
	moc_menu.sync_mode()
	lab._message("MoC / " + lab.moc.mode_name())

func toggle_rotating_hurtboxes() -> void:
	lab.rotate_hurtboxes = not lab.rotate_hurtboxes
	rotate_button.text = "TILT BOXES: %s" % ("ON" if lab.rotate_hurtboxes else "OFF")
	lab._message("Hurtboxes %s with the aimed angle" % ("tilt" if lab.rotate_hurtboxes else "stay level"))

func toggle_debug_volumes() -> void:
	lab.debug_volumes_visible = not lab.debug_volumes_visible
	debug_button.text = "BOXES: %s [K]" % ("ON" if lab.debug_volumes_visible else "OFF")
	lab.body_collision_view.visible = lab.debug_volumes_visible
	lab.reach_ring.visible = lab.debug_volumes_visible
	for volume in lab.training_bots.contact_boxes:
		volume.visible = lab.debug_volumes_visible
	for volume in lab.pepper.volumes:
		volume.visible = lab.debug_volumes_visible
	lab.serve.hand_volume.visible = lab.debug_volumes_visible and lab.serve.tossing()
	lab._update_hurtbox_visual(0)

func toggle_bot_menu() -> void:
	if lab.open_bot_menu():
		return
	ui.visible = true
	bot_panel.visible = not bot_panel.visible
	if bot_panel.visible:
		for menu in menu_panels:
			menu.hide()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func update() -> void:
	if lab.bot_menu != null: lab.bot_menu.update_vitals()
	if not ui.visible:
		return
	station_status.text = lab.drills.hud_text() if lab.drills.in_zone() or lab.drills.running() else lab.station.hud_text()
	bot_status.text = "Next: %d / 3  ·  %d bot contacts" % [mini(lab.side_contacts[lab.side_index(lab.ball.position.z)] + 1, 3), lab.training_bots.total_contacts] if lab.training_bots.any_enabled() else "Helpers off / E serve / G bots"
	action_wheel.set_action(lab.selected, lab.armed or lab.charging or lab.motion.jumped)
	action_wheel.set_auto(lab.armed and lab.auto_preparation.active)
	action_wheel.set_charge(lab.charge if lab.charging else (0.0 if lab.auto_preparation.active else (lab.locked_charge if lab.armed else 0.0)))
	athlete_hud.update_values()
	camera_badge.text = ("ATHLETE VIEW" if lab.camera_rig.camera_mode == ViewMode.ATHLETE else "BALL VIEW") + "   /   V switch\n" + ("Mouse look / aim   ·   Esc cursor" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "Cursor free   ·   click court to play")
	if lab.camera_rig.camera_mode == ViewMode.BALL:
		camera_badge.text = "BALL VIEW / AUTO TRACK   ·   V switch\nMouse: turn athlete / adjust loft\nWASD: toward / away from ball"
	if lab.pepper.active():
		camera_badge.text += "\n" + (("PARTNER " + ACTIONS[lab.pepper.stage]) if lab.pepper.npc_turn else ("YOUR " + ACTIONS[lab.pepper.required_player_action()]))
	camera_badge.text += "\n" + ("DRILL" if lab.station.running() or lab.drills.running() or lab.drills.box_state == lab.drills.State.ACTIVE else ("PEPPER" if lab.pepper.active() else ("HOLD E / STANDING SERVE" if lab.serve.channeling() else ("TOSS / E STRIKE" if lab.serve.tossing() else ("RALLY" if lab.ball_active else "EXPLORE / hold E serve · tap E toss / strike")))))
	if lab.debug_volumes_visible and lab.ball_shot.get("kind", "") == "receive" and lab.ball_shot.has("delivery_quality"):
		camera_badge.text += "\nDIG %d%% input → %d%% ball · delivery %d%%" % [roundi(float(lab.ball_shot.action_charge) * 100), roundi(float(lab.ball_shot.charge) * 100), roundi(float(lab.ball_shot.delivery_quality) * 100)]
	if lab.is_benched():
		lab.bench.refresh_ui()
		camera_badge.text = "BENCHED / %.1fs\nV spectate / Q–R cycle Home teammates" % lab.bench.remaining
	build_button.text = lab.athlete.build.name + "  [TAB]"
	sta_bar.value = lab.athlete.stamina
	info.text = "HP  %03d       STA  %03d%s" % [lab.athlete.hp, lab.athlete.stamina, "  " + lab.athlete.fatigue_text() if lab.athlete.exhausted or lab.athlete.winded else ""]
	metrics.text = "Height %.2fm  ·  Reach %.2fm\nPOW %d   SPD %d   ACC %d   END %d\nReturns %d / %d   ·   Last %s" % [lab.athlete.build.height, lab.athlete.reach(), lab.athlete.build.power, lab.athlete.build.speed, lab.athlete.build.accuracy, lab.athlete.build.endurance, lab.returns, lab.attempts, lab.last_quality]
	status.text = "PAUSED  /  P to resume" if lab.paused else lab.feedback
	var state := "HOLD LEFT MOUSE TO CHARGE → RELEASE → CLICK TO CONFIRM"
	if lab.motion.jump_charge >= 0:
		state = "TRAVEL JUMP / RELEASE TO LAUNCH" if lab.motion.generic_jump else lab.motion.approach_phase_name + (" / RELEASE FOR DIVE" if lab.motion.approach_action == 0 else " / RELEASE TO TAKE OFF")
	elif lab.motion.jumped:
		state = "TRAVEL JUMP" if lab.motion.airborne_action == -1 else Approach.STEP_NAMES[3] + (" / DIVE" if lab.motion.airborne_action == 0 else " / AIRBORNE")
	elif lab.charging:
		state = "CHARGING POWER  /  release to arm"
	elif lab.armed:
		state = ("AUTO READY" if lab.auto_preparation.active else "READY")+"  /  click at contact    ·    right click cancels on ground"
	if lab.hurtbox_root.visible and lab.hurtbox_action == 2:
		state += " / GREEN sweet · GOLD fair · ORANGE weak · RED sour"
	if (lab.armed or lab.charging) and (lab.locked_action if lab.armed else lab.selected) in [0, 1, 2]:
		state += " / WASD influences contact · live until impact"
	if lab.ball_active and lab.selected == 0:
		var demand := ReceiveCharge.match_charge(lab.ball_shot, lab.locked_charge if lab.armed else lab.charge)
		if demand.required:
			state += " / RECEIVE %d–%d%% INPUT" % [roundi(maxf(0,(demand.minimum-lab.athlete.cushioning_bonus())/lab.athlete.low_stamina_factor()) * 100), roundi(maxf(0,(demand.maximum-lab.athlete.cushioning_bonus())/lab.athlete.low_stamina_factor()) * 100)]
	charge_label.text = "%s   /   %s%s" % [ACTIONS[lab.selected], state, "   ·   AIRBORNE AIM LOCKED" if lab.motion.jumped else ""]


func _init(session: LabSession) -> void:
	lab = session

func inspect_bot(slot: int) -> void:
	if lab.bot_menu == null: lab.bot_menu = preload("res://scripts/map_bot_menu.gd").new(self)
	lab.bot_menu.open_bot(slot)
