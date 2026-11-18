extends RefCounted
## Ball lease and activity hook contract (MS-08). An activity that borrows the ball (a serve-receive station, a drill, Pepper) holds a lease
## while it runs. The holder is derived from the activities' own running()/active() hooks, so the lease cannot disagree with them.
## Terms today (CURRENT, reproduced): ledger access NONE for every holder (a held ball is not a rally: no counter, renewal or last-touch
## change from its contacts; Pepper keeps and resets its own counters), per-frame position writes allowed for a holder that returns true from
## holding_ball(). Nothing here changes a value; docs/architecture-migration/ball-lease.md has the write trace the lease was written from.
const STATION := "station"
const DRILL := "drills"
const PEPPER := "pepper"

## The hooks a lab calls on a drill-slot activity (lab.drills) without asking first, and on the station; has_method-gated hooks are optional.
const DRILL_HOOKS := ["running", "holding_ball", "on_contact", "sweep_ball", "tick_setup", "in_zone"]
const DRILL_OPTIONAL_HOOKS := ["drill_input", "drill_motion", "terrain_motion", "apply_drill_pose"]
const STATION_HOOKS := ["running", "on_contact", "tick_setup", "in_zone"]
const PEPPER_HOOKS := ["active"]

## Who holds the ball now: "" when nobody does (an ordinary rally or free practice).
static func holder(lab) -> String:
	if lab.station.running():
		return STATION
	if lab.drills.running():
		return DRILL
	if lab.pepper.active():
		return PEPPER
	return ""

## The ledger-access term: contacts count, fault and renew the opponent only when no activity holds the ball.
static func ledger_open(lab) -> bool:
	return not lab.station.running() and not lab.drills.running() and not lab.pepper.active()
