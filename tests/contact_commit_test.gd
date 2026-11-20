extends "res://tests/support/test_case.gd"
## MS-07: the commit's step order per caller policy (G-01 CURRENT: player and Serve spend before publish, bots and Pepper after), the policy
## field cap (SADR-03), the counter-reset scope per caller, and that every caller's source routes through the commit.
const Commit := preload("res://scripts/contact_commit.gd")
const Ledger := preload("res://scripts/rally_ledger.gd")

class StubLab extends RefCounted:
	var contacts := 2
	var side_contacts: Array[int] = [1, 2]

func _initialize() -> void: call_deferred("run")

func order_for(policy: Dictionary, lab) -> Array:
	var log := []
	Commit.run(lab, policy, {
		"spend": func() -> void: log.append("spend"),
		"prepare": func() -> void: log.append("prepare"),
		"publish": func() -> void: log.append("publish"),
		"present": func() -> void: log.append("present"),
		"settle": func() -> void: log.append("settle"),
	})
	return log

func run() -> void:
	for policy in [Commit.PLAYER, Commit.SERVE, Commit.BOT, Commit.PEPPER]:
		check(policy.size() <= Commit.MAX_POLICY_FIELDS, "A caller policy stays within the five-field cap")
	check(order_for(Commit.PLAYER, StubLab.new()) == ["spend", "prepare", "publish", "present", "settle"], "Player spends before the event is published")
	check(order_for(Commit.SERVE, StubLab.new()) == ["spend", "prepare", "publish", "present", "settle"], "Serve spends before the event is published")
	check(order_for(Commit.BOT, StubLab.new()) == ["spend", "prepare", "publish", "present", "settle"], "A court bot spends before publishing (G-01, MS-16)")
	check(order_for(Commit.PEPPER, StubLab.new()) == ["spend", "prepare", "publish", "present", "settle"], "Pepper spends before publishing (G-01, MS-16)")
	var lab := StubLab.new()
	Commit.run(lab, Commit.PLAYER, {"spend": func() -> void: pass, "publish": func() -> void: pass})
	check(lab.contacts == 2 and lab.side_contacts == [1, 2], "Player policy resets no counter (renewal is in the publish)")
	lab = StubLab.new()
	Commit.run(lab, Commit.BOT, {"spend": func() -> void: pass, "publish": func() -> void: pass})
	check(lab.contacts == 0 and lab.side_contacts == [1, 2], "Bot policy clears the personal count only")
	lab = StubLab.new()
	Commit.run(lab, Commit.PEPPER, {"spend": func() -> void: pass, "publish": func() -> void: pass})
	check(lab.contacts == 0 and lab.side_contacts == [0, 0], "Pepper policy clears both counts")
	for path in ["res://scripts/contact_lab.gd", "res://scripts/training_bots.gd", "res://scripts/pepper_partners.gd", "res://scripts/interactive_serve.gd"]:
		check("ContactCommit.run(" in FileAccess.get_file_as_string(path), path.get_file() + " commits through ContactCommit.run")
	print("CONTACT COMMIT: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
