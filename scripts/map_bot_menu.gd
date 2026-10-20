extends RefCounted
## One inspector for summoning and editing map bots; model enforces all limits.
var _hud: WeakRef
var hud: RefCounted:
	get: return _hud.get_ref()
var panel: PanelContainer
var roster: OptionButton
var team: OptionButton
var net: OptionButton
var contacts: Array[OptionButton] = []
var blocking: CheckBox
var behavior: OptionButton
var move_speed: HSlider
var tracking: HSlider
var aiming: HSlider
var charge: HSlider
var vitals: Label
var summary: Label
var feedback: Label
var selected_slot := -1
var choices: Array[int] = []

func _init(owner_hud: RefCounted) -> void:
	_hud = weakref(owner_hud)
	panel = hud.panel(Vector2(360,130),Vector2(720,640))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680,600)
	panel.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation",10)
	scroll.add_child(stack)
	stack.add_child(hud.label("MAP BOTS / SUMMON & ASSIGN",22,hud.TEAL))
	vitals = hud.label("",14,hud.GOLD)
	stack.add_child(vitals)
	summary = hud.label("",14)
	stack.add_child(summary)
	stack.add_child(hud.label("Approach a bot and press I to inspect it. F9 opens this roster.",13))
	roster = option(stack,"Inspect bot",["New bot"])
	roster.item_selected.connect(func(index: int):
		selected_slot = choices[index]
		load_selected()
	)
	team = option(stack,"Team",["Home / Blue","Away / Red"])
	net = option(stack,"Primary net",["Unassigned","Net 1 / Top","Net 2 / Middle","Net 3 / Bottom"])
	for index in range(3): net.set_item_disabled(index+1,not hud.lab.bot_courts().has(index))
	for contact in range(1,4):
		var field := option(stack,"Contact %d" % contact,["No responsibility","Receive","Set","Attack"])
		field.select(contact)
		contacts.append(field)
	blocking = CheckBox.new()
	blocking.text = "Block opposing contacts (independent of 1 / 2 / 3)"
	stack.add_child(blocking)
	behavior = option(stack,"Movement",["Follow ball","Static","Move"])
	behavior.select(2)
	net.select(hud.lab.current_net+1)
	move_speed = slider(stack,"Move speed",0,12,6," m/s",0.25)
	tracking = slider(stack,"Tracking accuracy",0,100,100,"%")
	aiming = slider(stack,"Aiming accuracy",0,100,100,"%")
	charge = slider(stack,"Charge accuracy",0,100,100,"%")
	var buttons := HBoxContainer.new()
	stack.add_child(buttons)
	buttons.add_child(hud.button("SUMMON NEW BOT",summon))
	buttons.add_child(hud.button("APPLY TO BOT",apply_selected))
	buttons.add_child(hud.button("MOVE TO ME",move_to_me))
	buttons.add_child(hud.button("DISMISS BOT",dismiss))
	feedback = hud.label("",14,hud.GOLD)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.x = 650
	stack.add_child(feedback)
	stack.add_child(hud.label("PEPPER PARTNER ACCURACY",16,hud.TEAL))
	for index in range(3):
		var partner := index
		var aim := slider(stack,"Partner %d aim" % (index+1),0,100,hud.lab.pepper.settings[index].aiming_accuracy,"%")
		aim.value_changed.connect(func(value: float): hud.lab.pepper.set_aiming_accuracy(partner,value))
		var control := slider(stack,"Partner %d charge" % (index+1),0,100,hud.lab.pepper.settings[index].charge_accuracy,"%")
		control.value_changed.connect(func(value: float): hud.lab.pepper.set_charge_accuracy(partner,value))
	stack.add_child(hud.button("CLOSE",toggle))
	panel.hide()

func option(stack: VBoxContainer,title: String,items: Array) -> OptionButton:
	var row := HBoxContainer.new()
	stack.add_child(row)
	var caption: Label = hud.label(title,14)
	caption.custom_minimum_size.x = 180
	row.add_child(caption)
	var control := OptionButton.new()
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.focus_mode = Control.FOCUS_NONE
	for item in items: control.add_item(str(item))
	row.add_child(control)
	return control

func slider(stack: VBoxContainer,title: String,minimum: float,maximum: float,value: float,suffix: String,step: float = 1) -> HSlider:
	var row := HBoxContainer.new()
	stack.add_child(row)
	var caption: Label = hud.label("%s: %.2f%s" % [title,value,suffix],13)
	caption.custom_minimum_size.x = 260
	row.add_child(caption)
	var control := HSlider.new()
	control.min_value = minimum
	control.max_value = maximum
	control.step = step
	control.value = value
	control.focus_mode = Control.FOCUS_NONE
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.value_changed.connect(func(next: float): caption.text = "%s: %.2f%s" % [title,next,suffix])
	row.add_child(control)
	return control

func refresh() -> void:
	var bots = hud.lab.training_bots
	choices.assign([-1])
	roster.clear()
	roster.add_item("New bot / choose settings below")
	for slot in range(bots.settings.size()):
		var config = bots.settings[slot]
		if not config.enabled: continue
		choices.append(slot)
		roster.add_item(bots.label_for(slot))
	var index := choices.find(selected_slot)
	if index < 0:
		selected_slot = -1
		index = 0
	roster.select(index)
	summary.text = "Home %d/14 · Away %d/14\nNet 1 H%d/5 A%d/5 · Net 2 H%d/5 A%d/5 · Net 3 H%d/5 A%d/5" % [bots.count_team(false),bots.count_team(true),bots.count_net_side(0,false),bots.count_net_side(0,true),bots.count_net_side(1,false),bots.count_net_side(1,true),bots.count_net_side(2,false),bots.count_net_side(2,true)]

func update_vitals() -> void:
	if not panel.visible: return
	if selected_slot < 0:
		vitals.text = "Bots recover fully when a new rally begins"
		return
	var athlete: LabAthlete = hud.lab.training_bots.athlete_for(selected_slot)
	vitals.text = "Stamina %.0f / %.0f   %s" % [athlete.stamina,athlete.max_stamina(),athlete.fatigue_text()]

func load_selected() -> void:
	update_vitals()
	if selected_slot < 0: return
	var config = hud.lab.training_bots.settings[selected_slot]
	team.select(int(config.away))
	net.select(config.net_index+1)
	var plan: Dictionary = config.contact_actions()
	for index in range(3): contacts[index].select(int(plan.get(index+1,-1))+1)
	blocking.button_pressed = config.can_block()
	behavior.select(2 if config.moves else (0 if config.follows_ball else 1))
	move_speed.value = config.move_speed
	tracking.value = config.tracking_accuracy
	aiming.value = config.aiming_accuracy
	charge.value = config.charge_accuracy

func save_behavior(slot: int) -> void:
	var bots = hud.lab.training_bots
	bots.set_mode(slot,behavior.selected)
	bots.set_move_speed(slot,move_speed.value)
	bots.set_tracking_accuracy(slot,tracking.value)
	bots.set_aiming_accuracy(slot,aiming.value)
	bots.set_charge_accuracy(slot,charge.value)

func summon() -> void:
	var bots = hud.lab.training_bots
	var slot: int = bots.summon_generic(team.selected == 1,net.selected-1,contact_plan(),blocking.button_pressed,net.selected == 0)
	if slot >= 0:
		selected_slot = slot
		save_behavior(slot)
		feedback.text = "Summoned bot #%d" % (slot+1)
	else: feedback.text = bots.last_error
	refresh()

func apply_selected() -> void:
	if selected_slot < 0:
		feedback.text = "Choose a bot to edit, or summon a new bot."
		return
	var bots = hud.lab.training_bots
	if bots.edit_responsibilities(selected_slot,team.selected == 1,net.selected-1,contact_plan(),blocking.button_pressed):
		save_behavior(selected_slot)
		feedback.text = "Updated bot #%d" % (selected_slot+1)
	else:
		feedback.text = bots.last_error
		load_selected()
	refresh()

func contact_plan() -> Dictionary:
	var result := {}
	for index in range(3):
		if contacts[index].selected > 0: result[index+1] = contacts[index].selected-1
	return result

func move_to_me() -> void:
	if selected_slot < 0: return
	hud.lab.training_bots.place_at_player(selected_slot)
	feedback.text = "Saved new placement for bot #%d" % (selected_slot+1)

func dismiss() -> void:
	if selected_slot < 0: return
	hud.lab.training_bots.dismiss(selected_slot)
	selected_slot = -1
	feedback.text = "Bot dismissed"
	refresh()

func open_bot(slot: int) -> void:
	selected_slot = slot
	panel.show()
	hud.ui.show()
	hud.bot_panel.hide()
	hud.moc_menu.panel.hide()
	refresh()
	load_selected()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func toggle() -> void:
	if panel.visible:
		panel.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		open_bot(selected_slot)
