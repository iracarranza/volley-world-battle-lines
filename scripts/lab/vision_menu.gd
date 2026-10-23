extends RefCounted
## The vision-focus settings inside the Esc menu: a master switch, each part as its own switch, and the numbers that shape the beam.
const Vision := preload("res://scripts/vision_focus.gd")
var _hud: WeakRef # weak: the HUD owns this menu
var hud: RefCounted:
	get: return _hud.get_ref()
var master: CheckButton
var controls: Array[Control] = []

func _init(owner_hud: RefCounted) -> void:
	_hud = weakref(owner_hud)
	var menu: RefCounted = hud.settings_menu
	menu.add_control(hud.label("VISION FOCUS  (prototype)", 15, hud.TEAL))
	menu.add_control(hud.label("On release the screen tunnels to a beam around the ball: charge sets its width, Accuracy how fast it clears, Stamina the blur and dark outside it; Ball Control shapes the trajectory preview.", 12, Color("8faabb")))
	master = toggle(menu, "Vision focus", Vision.enabled, func(value: bool):
		Vision.enabled = value
		_sync()
	)
	_part(menu, "Focus beam: width follows charge", Vision.focus_beam, func(value: bool): Vision.focus_beam = value)
	_part(menu, "Accuracy sets how fast the beam clears", Vision.acc_clarity, func(value: bool): Vision.acc_clarity = value)
	_part(menu, "Stamina blurs and darkens the edges (Endurance softens it)", Vision.fatigue_obscuration, func(value: bool): Vision.fatigue_obscuration = value)
	_part(menu, "Ball Control sets the preview's length and opacity", Vision.preview_by_ball_control, func(value: bool): Vision.preview_by_ball_control = value)
	_part(menu, "Trajectory preview only at the Moment of Contact", Vision.preview_only_in_moc, func(value: bool): Vision.preview_only_in_moc = value)
	_slider(menu, "Beam width, light charge", 0.2, 0.9, Vision.width_none, "", func(value: float): Vision.width_none = value)
	_slider(menu, "Beam width, full charge", 0.05, 0.6, Vision.width_full, "", func(value: float): Vision.width_full = value)
	_slider(menu, "Blur outside the beam", 0.0, 3.0, Vision.peripheral_blur, "x", func(value: float): Vision.peripheral_blur = value)
	_slider(menu, "Clearing time at neutral Accuracy", 0.1, 3.0, Vision.clarity_seconds, " s", func(value: float): Vision.clarity_seconds = value)
	_sync()

func toggle(menu: RefCounted, title: String, value: bool, changed: Callable) -> CheckButton:
	var control := CheckButton.new()
	control.text = title
	control.button_pressed = value
	control.focus_mode = Control.FOCUS_NONE
	control.toggled.connect(changed)
	menu.add_control(control)
	return control

func _part(menu: RefCounted, title: String, value: bool, changed: Callable) -> void:
	controls.append(toggle(menu, title, value, changed))

func _slider(menu: RefCounted, title: String, minimum: float, maximum: float, value: float, suffix: String, changed: Callable) -> void:
	var caption: Label = hud.label("%s: %.2f%s" % [title, value, suffix], 13)
	menu.add_control(caption)
	var control := HSlider.new()
	control.min_value = minimum
	control.max_value = maximum
	control.step = 0.01
	control.value = value
	control.focus_mode = Control.FOCUS_NONE
	control.value_changed.connect(func(next: float):
		changed.call(next)
		caption.text = "%s: %.2f%s" % [title, next, suffix]
	)
	menu.add_control(control)
	controls.append(control)

# The parts follow the master switch.
func _sync() -> void:
	for control in controls:
		if control is CheckButton:
			(control as CheckButton).disabled = not Vision.enabled
		elif control is HSlider:
			(control as HSlider).editable = Vision.enabled
