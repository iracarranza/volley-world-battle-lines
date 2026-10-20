extends RefCounted
## Versioned interactive defaults; isolated scenes can still start with an empty roster.
const NET_2_FILE := "res://data/net_2_bot_setup.json"
const STARTUP_META := "load_default_net_2_bots"
static func apply_net_2(bots: Node3D) -> bool:
	# Loading a startup preset must never overwrite an existing live roster.
	if bots.settings.any(func(config): return config.enabled): return false
	var preset: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NET_2_FILE))
	var net_index := int(preset.net_index)
	var center: Vector3 = bots.court(net_index).position
	for entry in preset.bots:
		var plan := {}
		for contact in entry.contacts: plan[int(contact)] = int(entry.contacts[contact])
		var slot: int = bots.summon_generic(bool(entry.away),net_index,plan,bool(entry.block))
		if slot < 0: return false
		var config = bots.settings[slot]
		config.moves = str(preset.movement) == "Move"
		config.follows_ball = true
		config.move_speed = float(entry.move_speed)
		config.tracking_accuracy = float(preset.tracking_accuracy)
		config.aiming_accuracy = float(preset.aiming_accuracy)
		config.charge_accuracy = float(preset.charge_accuracy)
		bots._place(slot,center+Vector3(float(entry.position[0]),0,float(entry.position[1])))
	bots.reset()
	return true
