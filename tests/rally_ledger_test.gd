extends "res://tests/support/test_case.gd"
## MS-06: the ledger operations on a stub lab, as a sequence table (block, receive, set, attack, opponent touch, net crossing), and the
## reset scope per caller (bots clear the personal count only; Pepper, drills, serve and station clear both).
const Ledger := preload("res://scripts/rally_ledger.gd")
const Rules := preload("res://scripts/rally_rules.gd")

class StubPepper extends RefCounted:
	var running := false
	var player_contacts := 0
	func active() -> bool: return running

class StubLab extends RefCounted:
	var contacts := 0
	var side_contacts: Array[int] = [0, 0]
	var rally_rules := Rules.new()
	var pepper := StubPepper.new()
	var player := Node3D.new()
	var ball := Node3D.new()
	func side_index(z: float) -> int: return 0 if z >= 0.0 else 1

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var lab := StubLab.new()
	lab.player.position = Vector3(0, 0, 4)
	# Block does not count; receive, set and attack count; the fourth is the fault (personal count 4 > 3, team count already 3).
	Ledger.count_player_touch(lab, true)
	check(lab.contacts == 0 and not Ledger.player_fault(lab, true, 0), "A block adds no count and is never a three-contact fault")
	Ledger.record_player_touch(lab, true, 0)
	check(lab.side_contacts == [0, 0], "A block adds nothing to the team count")
	for touch in range(3):
		Ledger.count_player_touch(lab, false)
		check(not Ledger.player_fault(lab, false, 0), "Touch %d of three is legal" % (touch + 1))
		Ledger.record_player_touch(lab, false, 0)
	check(lab.contacts == 3 and lab.side_contacts == [3, 0], "Three touches: personal 3, team 3")
	Ledger.count_player_touch(lab, false)
	check(Ledger.player_fault(lab, false, 0), "The fourth touch is the fault")
	# An opponent's touch renews the other side's allowance, clears the personal count off the player's side, and is the last touch.
	lab.contacts = 2
	Ledger.renew_opponent(lab, 1)
	check(lab.side_contacts == [0, 0] and lab.contacts == 0 and lab.rally_rules.last_touch_side == 1, "Opponent touch renews, clears personal, sets last touch")
	lab.contacts = 2
	lab.side_contacts.assign([1, 2])
	Ledger.renew_opponent(lab, 0)
	check(lab.side_contacts == [1, 0] and lab.contacts == 2 and lab.rally_rules.last_touch_side == 0, "A same-side touch keeps the personal count and renews only the other side")
	# Net crossing clears the side the ball is now on and the personal count.
	lab.ball.position = Vector3(0, 2, -0.1)
	lab.side_contacts.assign([2, 2])
	Ledger.reset_on_crossing(lab)
	check(lab.side_contacts == [2, 0] and lab.contacts == 0, "Crossing clears the new side and the personal count")
	# Bot scope: the check reads before its own touch is added; the reset keeps the team count.
	lab.side_contacts.assign([0, 3])
	check(Ledger.bot_at_limit(lab, 1) and not Ledger.bot_at_limit(lab, 0), "Bot limit reads the side's count")
	lab.side_contacts.assign([0, 1])
	Ledger.count_bot_touch(lab, 1)
	lab.contacts = 2
	Ledger.clear_personal(lab)
	check(lab.side_contacts == [0, 2] and lab.contacts == 0, "A bot contact adds to the team count and clears only the personal count")
	# Pepper's player count, and the full reset.
	lab.pepper.running = true
	lab.pepper.player_contacts = 3
	check(Ledger.player_fault(lab, false, 0), "Pepper faults on its own count")
	Ledger.record_player_touch(lab, false, 0)
	check(lab.pepper.player_contacts == 4 and lab.side_contacts == [0, 2], "Under Pepper only Pepper's count rises")
	lab.contacts = 2
	Ledger.clear_all(lab)
	check(lab.contacts == 0 and lab.side_contacts == [0, 0], "clear_all zeroes both counts")
	Ledger.begin_rally(lab, 1)
	check(lab.rally_rules.last_touch_side == 1, "begin_rally sets the serving side as last touch")
	lab.player.free()
	lab.ball.free()
	print("RALLY LEDGER: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
