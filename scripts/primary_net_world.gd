extends RefCounted
## The playable map nets share the lab's tape/webbing dimensions and collision layer.
static func build(lab: Node3D,net: Dictionary) -> StaticBody3D:
	var world = lab.world_builder
	var center: Vector3 = net.position
	var height: float = net.height
	var width: float = net.width
	var bottom := height-0.896
	var transforms: Array[Transform3D] = []
	for i in range(33):
		transforms.append(Transform3D(Basis.from_scale(Vector3(0.012,0.88,0.012)),center+Vector3(-width/2+i*width/32,height-0.45,0)))
	for i in range(6):
		transforms.append(Transform3D(Basis.from_scale(Vector3(width,0.012,0.012)),center+Vector3(0,bottom+i*0.176,0)))
	world.box_batch(lab,transforms,Color("829dab"))
	world.box(lab,Vector3(width+0.5,0.055,0.06),center+Vector3.UP*height,Color("f0e6ce"))
	for side in [-1.0,1.0]:
		world.box(lab,Vector3(0.1,height+0.17,0.1),center+Vector3(side*(width/2+0.3),(height+0.17)/2,0),Color("ffce73"))
	world.world_label("NET %d / %s" % [int(net.index)+1,net.label],center+Vector3(0,height+1,0),32,Color("54ead0"))
	var body := StaticBody3D.new()
	body.name = "PrimaryNet%d" % (int(net.index)+1)
	body.position = center
	body.collision_layer = 2
	body.collision_mask = 0
	for band in [[width,bottom,height-0.0275],[width+0.5,height-0.0275,height+0.0275]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(float(band[0]),float(band[2])-float(band[1]),0.08)
		shape.shape = box
		shape.position.y = (float(band[1])+float(band[2]))/2
		body.add_child(shape)
	lab.add_child(body)
	# Court markings remain at their authored map size.
	world.box(lab,Vector3(width,0.01,float(net.depth)),center+Vector3.DOWN*0.01,Color("255b66"))
	for edge in [-width/2,width/2]:
		world.box(lab,Vector3(0.06,0.012,float(net.depth)),center+Vector3(edge,0.01,0),Color("54ead0"))
	for edge in [-float(net.depth)/2,float(net.depth)/2]:
		world.box(lab,Vector3(width,0.012,0.06),center+Vector3(0,0.01,edge),Color("54ead0"))
	return body
