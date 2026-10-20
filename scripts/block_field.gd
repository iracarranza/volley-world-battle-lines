extends RefCounted
## Anatomical block coverage; coordinates are athlete-local, forward is -Z.
const COLORS := {"CORE":Color("67f3a3"),"TORSO EDGE":Color("ffcf70"),"ARM EDGE":Color("f69c69"),"FINGERTIPS":Color("ee617b")}
static func definition(height: float,reach: float) -> Dictionary:
	var bottom := height*0.48
	var top := reach+height*0.10
	return {"shape":"block_triangle","block_triangle":true,"center":Vector3(0,(bottom+top)*0.5,-0.34),"size":Vector3(1.2*height/1.86,top-bottom,0.46*height/1.86),"bottom":bottom,"top":top,"shoulder":height*0.85,"palm":reach-height*0.08,"half_width":0.60*height/1.86,"hand_x":0.25*height/1.86,"sweet_center":Vector3(0,reach-height*0.08,-0.34)}

static func width(shape: Dictionary,y: float) -> float:
	return lerpf(float(shape.half_width)*0.12,float(shape.half_width),clampf((y-float(shape.bottom))/(float(shape.palm)-float(shape.bottom)),0,1))

static func contains(shape: Dictionary,point: Vector3,radius: float) -> bool:
	return point.y >= float(shape.bottom)-radius and point.y <= float(shape.top)+radius and absf(point.x) <= width(shape,point.y)+radius and absf(point.z-float(shape.center.z)) <= float(shape.size.z)*0.5+radius

static func grade(shape: Dictionary,point: Vector3) -> Dictionary:
	var across := absf(point.x)/maxf(width(shape,point.y),0.01)
	var fingertip := smoothstep(float(shape.palm)+0.05,float(shape.top),point.y)
	var arm := smoothstep(float(shape.shoulder)-0.08,float(shape.shoulder)+0.08,point.y)
	var edge := smoothstep(0.52,1.0,across)
	var edge_capacity := lerpf(0.80,0.55,arm)
	var regional := lerpf(lerpf(1.0,edge_capacity,edge),0.30,fingertip)
	var palm := Vector3(signf(point.x)*float(shape.hand_x),float(shape.palm),float(shape.center.z))
	var distance := point.distance_to(palm)
	var proximity := 1.0-smoothstep(0.06,0.48,distance)
	var falloff := 1.0-0.25*clampf(maxf(0,distance-0.06)/maxf(float(shape.top)-float(shape.bottom),0.1),0,1)
	var region := "FINGERTIPS" if fingertip > 0.5 else (("ARM EDGE" if arm > 0.5 else "TORSO EDGE") if edge > 0.25 else "CORE")
	return {"hit":true,"zone":"SWEET SPOT" if proximity > 0.75 and region == "CORE" else ("FAIR" if region == "CORE" else "SOUR SPOT"),"quality":regional*falloff,"strength":1.0,"block_region":region,"block_capacity":regional*falloff,"block_sweet_weight":proximity*(1.0-edge)*(1.0-fingertip),"block_height":clampf((point.y-float(shape.bottom))/(float(shape.top)-float(shape.bottom)),0,1),"block_side":clampf(point.x/maxf(width(shape,point.y),0.01),-1,1),"block_front":clampf((float(shape.center.z)-point.z)/(float(shape.size.z)*0.5),-1,1)}

static func mesh(shape: Dictionary) -> ImmediateMesh:
	var result := ImmediateMesh.new()
	result.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(24):
		for col in range(24):
			var y0 := lerpf(float(shape.bottom),float(shape.top),row/24.0)
			var y1 := lerpf(float(shape.bottom),float(shape.top),(row+1)/24.0)
			for face in [-1.0,1.0]:
				var z: float = float(shape.center.z)+float(shape.size.z)*0.5*face
				var corners := [Vector3(lerpf(-width(shape,y0),width(shape,y0),col/24.0),y0,z),Vector3(lerpf(-width(shape,y0),width(shape,y0),(col+1)/24.0),y0,z),Vector3(lerpf(-width(shape,y1),width(shape,y1),(col+1)/24.0),y1,z),Vector3(lerpf(-width(shape,y1),width(shape,y1),col/24.0),y1,z)]
				for index in [0,1,2,0,2,3]:
					var color: Color = COLORS[grade(shape,corners[index]).block_region]
					color.a = 0.23
					result.surface_set_color(color)
					result.surface_add_vertex(corners[index]-Vector3(shape.center))
	result.surface_end()
	return result

static func approaching(shape: Dictionary,point: Vector3,velocity: Vector3) -> bool:
	return velocity.z > 0.01 or (velocity.y < -0.01 and point.y >= float(shape.palm)) or (point.x*velocity.x < -0.01 and absf(point.x) > width(shape,point.y)*0.8)
