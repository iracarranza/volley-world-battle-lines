extends RefCounted
## The Esc settings menu: everything that used to sit in the ribbon along the top of the screen, grouped, in one panel. Esc opens and closes it; while it
## is open the cursor is free. Controls that already exist as HUD buttons are moved into it, so they keep their state and their shortcuts.
const SECTION_COLOR := Color("54ead0")
var _hud: WeakRef # weak: the HUD owns this menu
var hud: RefCounted:
	get: return _hud.get_ref()
var panel: PanelContainer
var stack: VBoxContainer
var _grid: GridContainer

func _init(owner_hud: RefCounted) -> void:
	_hud = weakref(owner_hud)
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142536")
	style.border_color = Color("54ead0")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	hud.ui.add_child(panel)
	# Fills the window with a margin all round, so it fits any size and scrolls when there is more than fits.
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 150
	panel.offset_right = -150
	panel.offset_top = 40
	panel.offset_bottom = -40
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	stack.add_child(hud.label("SETTINGS", 26, SECTION_COLOR))
	stack.add_child(hud.label("Esc closes", 12, Color("8faabb")))
	panel.hide()

# Starts a titled group; buttons added next go in a two-column grid under it.
func section(title: String) -> void:
	stack.add_child(hud.label(title, 15, SECTION_COLOR))
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 6)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(_grid)

func add_button(button: Button) -> Button:
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if button.get_parent() != null:
		button.get_parent().remove_child(button)
	_grid.add_child(button)
	return button

func add_control(control: Control) -> void:
	stack.add_child(control)

func is_open() -> bool:
	return panel.visible

func toggle() -> void:
	set_open(not panel.visible)

func set_open(open: bool) -> void:
	if open:
		hud.ui.visible = true
		hud.moc_menu.panel.hide()
		hud.bot_panel.hide()
	panel.visible = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
