extends Resource
## Independent settings for a single court helper. Resetting play preserves these.
@export var enabled := false
@export_range(0, 3) var contact_order := 1
@export var follows_ball := true
@export var moves := false
@export_range(0, 12) var move_speed := 6.0
@export_range(0, 100) var tracking_accuracy := 100.0
@export_range(0, 100) var aiming_accuracy := 100.0
@export_range(0, 100) var charge_accuracy := 100.0
var fixed_position := Vector3.ZERO
