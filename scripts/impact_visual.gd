extends Node3D

# Adapted from VWM tools/ball_treatment_gallery.gd: _draw_shell / _shell_point.
# Its impulse-oriented equatorial shell is portable; gallery playback is not.
const STYLES := {
	"shell": {"seconds":0.16,"from":0.16,"to":0.30,"gain":0.62,"flatten":0.30,"alpha":0.075,"growth":0.50},
	"stop": {"seconds":0.10,"from":0.21,"to":0.34,"gain":0.20,"flatten":0.10,"alpha":0.12,"growth":0.16},
	"boom": {"seconds":0.20,"from":0.12,"to":0.44,"gain":1.05,"flatten":0.58,"alpha":0.055,"growth":0.60},
}
const IMPULSE_REFERENCE := 20.0
const MAX_LIVE := 16
var lab: Node3D
var live: Array[Dictionary] = []
var recent: Array[String] = []
var emitted := 0
var material: ShaderMaterial
var core_material: ShaderMaterial
var pool: Array[Dictionary] = []
var core_mesh: QuadMesh
var shell_meshes: Dictionary = {}

func setup(owner_lab: Node3D) -> void:
	lab = owner_lab
	material = ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = "shader_type spatial; render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled; uniform vec4 tint : source_color = vec4(1.0); void fragment() { ALBEDO = tint.rgb * COLOR.rgb; ALPHA = tint.a * COLOR.a; }"
	core_material = ShaderMaterial.new()
	core_material.shader = Shader.new()
	core_material.shader.code = "shader_type spatial; render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled; uniform vec4 tint : source_color = vec4(1.0); uniform sampler2D aura : source_color; void vertex() { MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]); MODELVIEW_MATRIX[0].xyz *= length(MODEL_MATRIX[0].xyz); MODELVIEW_MATRIX[1].xyz *= length(MODEL_MATRIX[1].xyz); } void fragment() { vec4 tex = texture(aura, UV); ALBEDO = tint.rgb * tex.rgb; ALPHA = tint.a * tex.a; }"
	core_material.set_shader_parameter("aura",preload("res://vendor/vwm/construction/assets/vfx/aura_soft.svg"))
	core_mesh = QuadMesh.new()
	core_mesh.size = Vector2.ONE
	# Build reusable meshes before play rather than allocating geometry at every impact frame.
	for profile in STYLES:
		var shell := MeshInstance3D.new()
		shell.material_override = material.duplicate()
		var core := MeshInstance3D.new()
		core.material_override = core_material.duplicate()
		_render({"age":0.0,"duration":1.0,"style":STYLES[profile],"profile":profile,"strength":1.0,"sweet":false,"color":Color.WHITE,"axis":Vector3.UP,"shell":shell,"core":core})
		shell.free()
		core.free()
	for index in range(MAX_LIVE):
		pool.append(_create_visual())
	_warm_shaders.call_deferred()
	lab.moc.impact_started.connect(play)

func play(event: Dictionary) -> void:
	if lab.paused or not event.get("physical_hit",false):
		return
	var id := str(event.get("id",""))
	if not id.is_empty() and id in recent:
		return
	var origin: Vector3 = event.get("point",lab.ball.position)
	var incoming: Vector3 = event.get("incoming_velocity",Vector3.ZERO)
	var outgoing: Vector3 = event.get("outgoing_velocity",Vector3.ZERO)
	if not origin.is_finite() or not incoming.is_finite() or not outgoing.is_finite():
		return
	var impulse := outgoing-incoming
	if impulse.length() < 0.05 and not event.get("sweet",false):
		return
	if not id.is_empty():
		recent.append(id)
		if recent.size() > 64:
			recent.pop_front()
	if live.size() >= MAX_LIVE:
		_dispose(live.pop_front())
	var sweet := bool(event.get("sweet",false))
	var profile := "stop" if int(event.get("action",0)) == 3 else ("boom" if int(event.get("action",0)) == 0 and incoming.length() > outgoing.length()*1.25 else "shell")
	var style: Dictionary = STYLES[profile]
	var color := Color("ffd66b") if sweet else Color("c4e9ff")
	if not event.get("charge_match",{}).get("matched",true):
		color = Color("f29a88")
	elif event.get("rescue",false):
		color = Color("f5bd91")
	var visual: Dictionary = pool.pop_back()
	var root: Node3D = visual.root
	var shell: MeshInstance3D = visual.shell
	var core: MeshInstance3D = visual.core
	root.visible = true
	root.position = origin
	var effect := {"root":root,"shell":shell,"core":core,"age":0.0,"duration":float(style.seconds)+(0.06 if sweet else 0.0),"style":style,"profile":profile,"color":color,"sweet":sweet,"axis":impulse.normalized() if impulse.length() > 0.001 else Vector3.UP,"strength":clampf(impulse.length()/IMPULSE_REFERENCE,0.08,1.0),"point":origin,"event_id":id}
	live.append(effect)
	emitted += 1
	_render(effect)

func tick(real_dt: float) -> void:
	if lab.paused:
		return
	for index in range(live.size()-1,-1,-1):
		var effect := live[index]
		effect.age += maxf(0,real_dt)
		if effect.age >= effect.duration:
			_dispose(effect)
			live.remove_at(index)
		else:
			_render(effect)

func clear() -> void:
	for effect in live:
		_dispose(effect)
	live.clear()

func _create_visual() -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	root.visible = false
	var shell := MeshInstance3D.new()
	shell.mesh = shell_meshes["shell"]
	shell.material_override = material.duplicate()
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shell)
	var core := MeshInstance3D.new()
	core.mesh = core_mesh
	core.material_override = core_material.duplicate()
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)
	return {"root":root,"shell":shell,"core":core}

func _warm_shaders() -> void:
	if DisplayServer.get_name() == "headless":
		return
	# Draw both shader variants before gameplay; retain resources for every impact.
	var visual := _create_visual()
	visual.root.visible = true
	visual.root.global_position = lab.camera.global_position - lab.camera.global_basis.z * 2.0
	visual.shell.material_override.set_shader_parameter("tint",Color(1,1,1,0.00001))
	visual.core.material_override.set_shader_parameter("tint",Color(1,1,1,0.00001))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	visual.root.queue_free()

func _dispose(effect: Dictionary) -> void:
	effect.root.visible = false
	pool.append({"root":effect.root,"shell":effect.shell,"core":effect.core})

func _render(effect: Dictionary) -> void:
	var age := float(effect.age)/float(effect.duration)
	var style: Dictionary = effect.style
	var strength := float(effect.strength)
	var radius := lerpf(float(style["from"]),(float(style.to)+float(style.gain)*strength)*(1.2 if effect.sweet else 1.0),pow(age,float(style.growth)))
	var alpha := pow(1-age,2)*float(style.alpha)*2.8*(0.35+0.65*strength)*(1.5 if effect.sweet else 1.0)
	var axis: Vector3 = effect.axis
	var side := axis.cross(Vector3.UP)
	if side.length() < 0.001:
		side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	var other := side.cross(axis).normalized()
	if not shell_meshes.has(effect.profile):
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for ring in range(6):
			var f0 := float(ring)/6
			var f1 := float(ring+1)/6
			var v0 := lerpf(0.26*PI,0.74*PI,f0)
			var v1 := lerpf(0.26*PI,0.74*PI,f1)
			var a0 := Color(1,1,1,sin(PI*f0))
			var a1 := Color(1,1,1,sin(PI*f1))
			for segment in range(24):
				var u0 := TAU*float(segment)/24
				var u1 := TAU*float(segment+1)/24
				var corners := [_shell_point(Vector3.UP,Vector3.RIGHT,Vector3.FORWARD,u0,v0,1.0,float(style.flatten)),_shell_point(Vector3.UP,Vector3.RIGHT,Vector3.FORWARD,u1,v0,1.0,float(style.flatten)),_shell_point(Vector3.UP,Vector3.RIGHT,Vector3.FORWARD,u1,v1,1.0,float(style.flatten)),_shell_point(Vector3.UP,Vector3.RIGHT,Vector3.FORWARD,u0,v1,1.0,float(style.flatten))]
				for corner in [0,1,2,0,2,3]:
					mesh.surface_set_color(a0 if corner < 2 else a1)
					mesh.surface_add_vertex(corners[corner])
		mesh.surface_end()
		shell_meshes[effect.profile] = mesh
	effect.shell.mesh = shell_meshes[effect.profile]
	effect.shell.basis = Basis(side,axis,-other).scaled(Vector3.ONE*radius)
	effect.shell.material_override.set_shader_parameter("tint",Color(effect.color,alpha))
	var flash := 1.0-smoothstep(0,0.075 if effect.sweet else 0.045,float(effect.age))
	effect.core.visible = flash > 0
	effect.core.scale = Vector3.ONE*(0.55+0.35*strength)*flash
	effect.core.material_override.set_shader_parameter("tint",Color(Color(effect.color).lerp(Color.WHITE,0.7),flash*0.8))

static func _shell_point(axis: Vector3,side: Vector3,other: Vector3,u: float,v: float,radius: float,flatten: float) -> Vector3:
	return (axis*cos(v)*flatten+(side*cos(u)+other*sin(u))*sin(v))*radius
