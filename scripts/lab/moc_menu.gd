extends RefCounted

## Contact-lab tuning UI. Values persist across lab resets within this session.
var _hud: WeakRef
var hud: RefCounted:
	get: return _hud.get_ref()
var panel: PanelContainer
var mode: OptionButton
var speed: HSlider
var duration: HSlider
var steering_speed: HSlider
var steering_duration: HSlider
var steering_rate: HSlider
var steering_cost: HSlider
var ball: CheckButton
var actor: CheckButton

func _init(owner_hud: RefCounted) -> void:
	_hud = weakref(owner_hud)
	panel = hud.panel(Vector2(390,70),Vector2(540,580))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",6)
	panel.add_child(stack)
	stack.add_child(hud.label("MOMENT OF CONTACT",22,hud.TEAL))
	mode = OptionButton.new()
	for title in ["Current", "Tuned — spikes only", "Off", "Trajectory steering — all contacts"]:
		mode.add_item(title)
	mode.focus_mode = Control.FOCUS_NONE
	mode.item_selected.connect(func(index: int):
		hud.lab.moc.set_mode(index)
		hud.moc_button.text = ["MoC: CURRENT [O]","MoC: TUNED [O]","MoC: OFF [O]","MoC: STEERING [O]"][index]
	)
	stack.add_child(mode)
	stack.add_child(hud.label("Tuned settings · changes apply to the next spike",13))
	speed = slider(stack,"Tuned speed",1,100,hud.lab.moc.tuned_speed*100,"%",func(value: float): hud.lab.moc.tuned_speed = value/100.0)
	duration = slider(stack,"Tuned duration",0,1000,hud.lab.moc.tuned_duration*1000," ms",func(value: float): hud.lab.moc.tuned_duration = value/1000.0)
	stack.add_child(hud.label("Trajectory steering · hold a direction after contact",13))
	steering_speed = slider(stack,"Steering speed",0.1,100,hud.lab.moc.steering_speed*100,"%",func(value: float): hud.lab.moc.steering_speed = value/100.0)
	steering_speed.step = 0.1
	steering_duration = slider(stack,"Steering duration",100,3000,hud.lab.moc.steering_duration*1000," ms",func(value: float): hud.lab.moc.steering_duration = value/1000.0)
	steering_rate = slider(stack,"Steering rate",10,300,hud.lab.moc.steering_rate*100,"% / s",func(value: float): hud.lab.moc.steering_rate = value/100.0)
	steering_cost = slider(stack,"HP per full DI",0,30,hud.lab.moc.steering_hp_cost," HP",func(value: float): hud.lab.moc.steering_hp_cost = value)
	ball = toggle_control(stack,"Slow the ball",func(value: bool): hud.lab.moc.affect_ball = value)
	actor = toggle_control(stack,"Slow the acting athlete / follow-through",func(value: bool): hud.lab.moc.affect_actor = value)
	stack.add_child(hud.label("World, camera and other athletes always run normally.",13))
	stack.add_child(hud.button("CLOSE",toggle))
	panel.hide()

func slider(stack: VBoxContainer,title: String,minimum: float,maximum: float,value: float,suffix: String,changed: Callable) -> HSlider:
	var caption: Label = hud.label("%s: %.1f%s" % [title,value,suffix],14)
	stack.add_child(caption)
	var control := HSlider.new()
	control.min_value = minimum
	control.max_value = maximum
	control.step = 0.1 if minimum < 1 else 1
	control.value = value
	control.focus_mode = Control.FOCUS_NONE
	control.value_changed.connect(func(next: float):
		hud.lab.moc.clear()
		changed.call(next)
		caption.text = "%s: %.1f%s" % [title,next,suffix]
	)
	stack.add_child(control)
	return control

func toggle_control(stack: VBoxContainer,title: String,changed: Callable) -> CheckButton:
	var control := CheckButton.new()
	control.text = title
	control.button_pressed = true
	control.focus_mode = Control.FOCUS_NONE
	control.toggled.connect(changed)
	stack.add_child(control)
	return control

func sync_mode() -> void:
	mode.select(hud.lab.moc.mode)

func toggle() -> void:
	hud.ui.visible = true
	panel.visible = not panel.visible
	if panel.visible:
		hud.bot_panel.hide()
		sync_mode()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if panel.visible else Input.MOUSE_MODE_CAPTURED
