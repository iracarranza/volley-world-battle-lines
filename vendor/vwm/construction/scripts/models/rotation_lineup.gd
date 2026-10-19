class_name RotationLineup
extends Resource

@export_range(1, 6) var rotation_number: int = 1
@export var setter_id: int = -1
@export_enum("5-1", "6-2") var setting_system: String = "5-1"
@export var designated_setter_ids: Array[int] = []
@export var slot_player_ids: Dictionary = {}


func active_setter_id() -> int:
	if setting_system == "6-2" and designated_setter_ids.size() >= 2:
		for player_id in designated_setter_ids:
			var slot_number := slot_for_player(player_id)
			if slot_number >= 0 and not CourtConstants.is_front_row_slot(slot_number):
				return player_id
	return setter_id if setter_id >= 0 else (
		designated_setter_ids[0] if not designated_setter_ids.is_empty() else -1
	)


func is_attack_eligible(player_id: int) -> bool:
	return player_id >= 0 and player_id != active_setter_id()


func assign_slot(slot_number: int, player_id: int) -> String:
	if slot_number < 1 or slot_number > 6:
		return "Rotation slot must be between 1 and 6."
	for existing_slot in slot_player_ids:
		if int(existing_slot) != slot_number \
				and int(slot_player_ids[existing_slot]) == player_id:
			return "A player cannot occupy two rotation slots."
	slot_player_ids[slot_number] = player_id
	return ""


func player_at_slot(slot_number: int) -> int:
	return int(slot_player_ids.get(slot_number, -1))


func slot_for_player(player_id: int) -> int:
	for slot_number in slot_player_ids:
		if int(slot_player_ids[slot_number]) == player_id:
			return int(slot_number)
	return -1


func front_row_player_ids() -> Array[int]:
	var result: Array[int] = []
	for slot_number in [2, 3, 4]:
		var player_id := player_at_slot(slot_number)
		if player_id >= 0:
			result.append(player_id)
	return result


func validate() -> Array[String]:
	var errors: Array[String] = []
	if rotation_number < 1 or rotation_number > 6:
		errors.append("Rotation number must be between 1 and 6.")
	if slot_player_ids.size() != 6:
		errors.append("A rotation requires exactly six occupied slots.")
	var unique_players := {}
	for slot_number in range(1, 7):
		var player_id := player_at_slot(slot_number)
		if player_id < 0:
			errors.append("Rotation slot %d is vacant." % slot_number)
		elif unique_players.has(player_id):
			errors.append("Player %d appears more than once." % player_id)
		else:
			unique_players[player_id] = true
	if active_setter_id() not in unique_players:
		errors.append("The setter must occupy a rotation slot.")
	if setting_system == "6-2":
		if designated_setter_ids.size() != 2:
			errors.append("A 6-2 requires exactly two designated setters.")
		else:
			var front_count := 0
			var back_count := 0
			for player_id in designated_setter_ids:
				var slot_number := slot_for_player(player_id)
				if slot_number < 0:
					errors.append("Both 6-2 setters must occupy the rotation.")
				elif CourtConstants.is_front_row_slot(slot_number):
					front_count += 1
				else:
					back_count += 1
			if front_count != 1 or back_count != 1:
				errors.append("A 6-2 requires one front-row and one back-row setter.")
	return errors


func to_dict() -> Dictionary:
	return {
		"rotation_number": rotation_number,
		"setter_id": setter_id,
		"setting_system": setting_system,
		"designated_setter_ids": designated_setter_ids.duplicate(),
		"slot_player_ids": slot_player_ids.duplicate(true),
	}


static func from_dict(data: Dictionary) -> RotationLineup:
	var lineup := RotationLineup.new()
	lineup.rotation_number = clampi(int(data.get("rotation_number", 1)), 1, 6)
	lineup.setter_id = int(data.get("setter_id", -1))
	lineup.setting_system = str(data.get("setting_system", "5-1"))
	for raw_id in data.get("designated_setter_ids", []):
		lineup.designated_setter_ids.append(int(raw_id))
	if lineup.designated_setter_ids.is_empty() and lineup.setter_id >= 0:
		lineup.designated_setter_ids.append(lineup.setter_id)
	var saved_slots: Dictionary = data.get("slot_player_ids", {})
	for raw_slot in saved_slots:
		lineup.slot_player_ids[int(raw_slot)] = int(saved_slots[raw_slot])
	return lineup
