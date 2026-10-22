extends RefCounted
## Inputs to contact resolution. No scene tree or mutation of the world is needed.
const Action := preload("res://scripts/contact/action.gd").Type
var action: int = Action.RECEIVE
var athlete: LabAthlete
var actor_id := "player"
var shape: Dictionary = {}
var local_point := Vector3.ZERO
var origin := Vector3.ZERO
var incoming := Vector3.ZERO
var incoming_shot: Dictionary = {}
var charge := 0.65
var auto_charge := false
var handling_charge := 0.0
var auto_evidence: Dictionary = {}
var confirmation_age := 0.20
var response_seed := 0
var net_distance := -1.0 # the receiver's distance from the net; negative when there is no net (a Pepper)
var remembered := false
var movement_speed := 0.0
var facing := Vector3.FORWARD
var directional_input := Vector3.ZERO
var intent_direction := Vector3.FORWARD
var base_velocity := Vector3.ZERO
var flow := 0.0
var gravity := 9.8
# Preview deliberately assumes a clean charge match and omits execution scatter.
var ideal_charge_match := false
var apply_set_spread := false
var apply_block_spread := false
# Bot target selection remains outside the resolver. These are execution inputs.
var keep_attack_intent := false
var aiming_accuracy := 100.0
var aim_random: RandomNumberGenerator
var receive_heading := Vector3.ZERO
var attack_strength_reference := 1.0
# Rolling Receive is an ability override, not a separate contact implementation.
var rolling_receive := false

var gameplay: Dictionary = {}
var source_athlete: LabAthlete

var block_confirmation_age := -1.0

# Negative keeps the passive/Auto reference; explicit effort affects confirmed blocks.
var block_charge_reference := -1.0
