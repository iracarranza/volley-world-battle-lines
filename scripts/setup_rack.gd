extends Node3D
## The visible ball rack of a Setup's distributor. Every ball still inside sits behind a locked bar; when a ball is sent out its bar rises and
## the ball leaves, so the rack always shows how many are left. When the Setup is completed all bars rise and the reward balls wait,
## claimable only by the player who completed it; each claimed ball leaves the rack.
const SLOTS := 12
const COLUMNS := 6
const BAR_UP := 0.55
const BAR_SPEED := 2.4
var balls: Array[MeshInstance3D] = []
var bars: Array[MeshInstance3D] = []
var bar_target: Array[float] = []
var label: Label3D
var shown := -1
var unlocked := false
var fade: Array[float] = [] # seconds a risen bar stays visible after its ball has left

func build(lab: Node3D, tint: Color = Color("ffb46e")) -> void:
	var wood: StandardMaterial3D = lab.world_builder.material(Color("4a4f58"), true)
	var frame := MeshInstance3D.new()
	var back := BoxMesh.new()
	back.size = Vector3(COLUMNS * 0.34 + 0.3, 0.9, 0.08)
	frame.mesh = back
	frame.position = Vector3(0, 0.9, -0.2)
	frame.material_override = wood
	add_child(frame)
	for slot in range(SLOTS):
		var row := slot / COLUMNS
		var column := slot % COLUMNS
		var at := Vector3((column - (COLUMNS - 1) * 0.5) * 0.34, 0.55 + row * 0.42, 0.0)
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.13
		sphere.height = 0.26
		ball.mesh = sphere
		ball.position = at
		ball.material_override = lab.world_builder.material(Color("f5f0dc"), true)
		add_child(ball)
		balls.append(ball)
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.3, 0.04, 0.04)
		bar.mesh = box
		bar.position = at + Vector3(0, -0.02, 0.17)
		bar.material_override = lab.world_builder.material(tint, true)
		add_child(bar)
		bars.append(bar)
		bar_target.append(0.0)
		fade.append(0.0)
	label = Label3D.new()
	label.position = Vector3(0, 1.95, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 22
	label.pixel_size = 0.008
	add_child(label)
	_apply(0, false)

# Match the rack to the distributor. `dt` animates the bars.
func sync(distributor: RefCounted, dt: float, owner_name: String = "") -> void:
	var count := 0
	var open := false
	if distributor.phase == distributor.Phase.READY:
		count = distributor.balls
	elif distributor.phase == distributor.Phase.RUNNING:
		count = distributor.balls
	else:
		count = distributor.pile
		open = distributor.pile > 0
	if count != shown or open != unlocked:
		_apply(count, open)
	for slot in range(SLOTS):
		fade[slot] = maxf(0.0, fade[slot] - dt)
		bars[slot].visible = slot < count or fade[slot] > 0.0
		var bar := bars[slot]
		var base_y: float = balls[slot].position.y - 0.02
		var want: float = base_y + bar_target[slot]
		bar.position.y = move_toward(bar.position.y, want, BAR_SPEED * dt) if dt > 0.0 else want
	if open:
		label.text = "REWARD / %d BALLS%s" % [count, " / " + owner_name if not owner_name.is_empty() else ""]
	elif distributor.phase == distributor.Phase.RUNNING:
		label.text = "%d LEFT" % count
	else:
		label.text = ""

# Balls 0..count-1 are present. Locked bars stay down; a bar whose ball has just left (or any bar, once the reward is open) rises.
func _apply(count: int, open: bool) -> void:
	# Balls that just left: their bars rise and linger a moment so the release is seen.
	for slot in range(maxi(count, 0), mini(maxi(shown, 0), SLOTS)):
		fade[slot] = 1.2
	shown = count
	unlocked = open
	for slot in range(SLOTS):
		balls[slot].visible = slot < count
		bar_target[slot] = BAR_UP if (open or slot >= count) else 0.0

func visible_balls() -> int:
	var total := 0
	for ball in balls:
		if ball.visible:
			total += 1
	return total

func locked_bars() -> int:
	var total := 0
	for slot in range(SLOTS):
		if balls[slot].visible and bar_target[slot] == 0.0:
			total += 1
	return total
