extends Resource
## Independent settings for a single court helper. Resetting play preserves these.
@export var enabled := false
@export_range(0,3) var action_type := 0
@export var away := false
@export_range(-1,2) var net_index := 1
@export_range(0, 3) var contact_order := 1
# Keys 1/2/3 map to Receive/Set/Attack. Empty preserves old single-role presets.
@export var responsibility_mode := false
@export var responsibilities: Dictionary = {}
@export var block_enabled := false
@export var follows_ball := true
@export var moves := false
@export_range(0, 12) var move_speed := 6.0
@export_range(0, 100) var tracking_accuracy := 100.0
@export_range(0, 100) var aiming_accuracy := 100.0
@export_range(0, 100) var charge_accuracy := 100.0
@export var auto_intended_charge := true
@export_range(0, 1, 0.01) var intended_charge := 0.65
var fixed_position := Vector3.ZERO

func contact_actions() -> Dictionary:
	if responsibility_mode: return responsibilities.duplicate()
	if action_type == 3: return {}
	return {1:action_type,2:action_type,3:action_type} if contact_order == 0 else {contact_order:action_type}

func can_block() -> bool:
	return block_enabled if responsibility_mode else action_type == 3
