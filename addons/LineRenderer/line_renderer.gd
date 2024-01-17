@tool
extends MeshInstance3D

@export var points: Array[Vector3] = [Vector3(0,0,0),Vector3(0,5,0)]:
	set(new_points): points = new_points
@export var start_thickness:float = 0.1:
	set(new_start_thickness): start_thickness = new_start_thickness
@export var end_thickness:float = 0.1:
	set(new_end_thickness): end_thickness = new_end_thickness
@export var corner_resolution:int = 5:
	set(new_corner_resolution): corner_resolution = new_corner_resolution
@export var cap_resolution:int = 5:
	set(new_cap_resolution): cap_resolution = new_cap_resolution
@export var draw_caps:bool = true:
	set(new_draw_caps): draw_caps = new_draw_caps
@export var draw_crners:bool = true:
	set(new_draw_crners): draw_crners = new_draw_crners
@export var use_global_coords:bool = true:
	set(new_use_global_coords): use_global_coords = new_use_global_coords
@export var tile_texture:bool = true:
	set(new_tile_texture): tile_texture = new_tile_texture

var camera : Camera3D
var cameraOrigin : Vector3

func _enter_tree():
	mesh = ImmediateMesh.new()

func _ready():
	pass

func _process(_delta):
	if points.size() < 2:
		return
	
	camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	cameraOrigin = to_local(camera.get_global_transform().origin)
	
	var progressStep = 1.0 / points.size();
	var progress = 0;
	var thickness = lerp(start_thickness, end_thickness, progress);
	var nextThickness = lerp(start_thickness, end_thickness, progress + progressStep);
	
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for i in range(points.size() - 1):
		var A = points[i]
		var B = points[i+1]
	
		if use_global_coords:
			A = to_local(A)
			B = to_local(B)
	
		var AB = B - A;
		var orthogonalABStart = (cameraOrigin - ((A + B) / 2)).cross(AB).normalized() * thickness;
		var orthogonalABEnd = (cameraOrigin - ((A + B) / 2)).cross(AB).normalized() * nextThickness;
		
		var AtoABStart = A + orthogonalABStart
		var AfromABStart = A - orthogonalABStart
		var BtoABEnd = B + orthogonalABEnd
		var BfromABEnd = B - orthogonalABEnd
		
		if i == 0:
			if draw_caps:
				cap(A, B, thickness, cap_resolution)
		
		if tile_texture:
			var ABLen = AB.length()
			var ABFloor = floor(ABLen)
			var ABFrac = ABLen - ABFloor
			
			mesh.surface_set_uv(Vector2(ABFloor, 0))
			mesh.surface_add_vertex(AtoABStart)
			mesh.surface_set_uv(Vector2(-ABFrac, 0))
			mesh.surface_add_vertex(BtoABEnd)
			mesh.surface_set_uv(Vector2(ABFloor, 1))
			mesh.surface_add_vertex(AfromABStart)
			mesh.surface_set_uv(Vector2(-ABFrac, 0))
			mesh.surface_add_vertex(BtoABEnd)
			mesh.surface_set_uv(Vector2(-ABFrac, 1))
			mesh.surface_add_vertex(BfromABEnd)
			mesh.surface_set_uv(Vector2(ABFloor, 1))
			mesh.surface_add_vertex(AfromABStart)
		else:
			mesh.surface_set_uv(Vector2(1, 0))
			mesh.surface_add_vertex(AtoABStart)
			mesh.surface_set_uv(Vector2(0, 0))
			mesh.surface_add_vertex(BtoABEnd)
			mesh.surface_set_uv(Vector2(1, 1))
			mesh.surface_add_vertex(AfromABStart)
			mesh.surface_set_uv(Vector2(0, 0))
			mesh.surface_add_vertex(BtoABEnd)
			mesh.surface_set_uv(Vector2(0, 1))
			mesh.surface_add_vertex(BfromABEnd)
			mesh.surface_set_uv(Vector2(1, 1))
			mesh.surface_add_vertex(AfromABStart)
		
		if i == points.size() - 2:
			if draw_caps:
				cap(B, A, nextThickness, cap_resolution)
		else:
			if draw_crners:
				var C = points[i+2]
				if use_global_coords:
					C = to_local(C)
				
				var BC = C - B;
				var orthogonalBCStart = (cameraOrigin - ((B + C) / 2)).cross(BC).normalized() * nextThickness;
				
				var angleDot = AB.dot(orthogonalBCStart)
				
				if angleDot > 0:
					corner(B, BtoABEnd, B + orthogonalBCStart, corner_resolution)
				else:
					corner(B, B - orthogonalBCStart, BfromABEnd, corner_resolution)
		
		progress += progressStep;
		thickness = lerp(start_thickness, end_thickness, progress);
		nextThickness = lerp(start_thickness, end_thickness, progress + progressStep);
	
	mesh.surface_end()

func cap(center, pivot, thickness, smoothing):
	var orthogonal = (cameraOrigin - center).cross(center - pivot).normalized() * thickness;
	var axis = (center - cameraOrigin).normalized();
	
	var array = []
	for i in range(smoothing + 1):
		array.append(Vector3(0,0,0))
	array[0] = center + orthogonal;
	array[smoothing] = center - orthogonal;
	
	for i in range(1, smoothing):
		array[i] = center + (orthogonal.rotated(axis, lerp(0.0, PI, float(i) / smoothing)));
	
	for i in range(1, smoothing + 1):
		mesh.surface_set_uv(Vector2(0, (i - 1) / smoothing))
		mesh.surface_add_vertex(array[i - 1]);
		mesh.surface_set_uv(Vector2(0, (i - 1) / smoothing))
		mesh.surface_add_vertex(array[i]);
		mesh.surface_set_uv(Vector2(0.5, 0.5))
		mesh.surface_add_vertex(center);
		
func corner(center, start, end, smoothing):
	var array = []
	for i in range(smoothing + 1):
		array.append(Vector3(0,0,0))
	array[0] = start;
	array[smoothing] = end;
	
	var axis = start.cross(end).normalized()
	var offset = start - center
	var angle = offset.angle_to(end - center)
	
	for i in range(1, smoothing):
		array[i] = center + offset.rotated(axis, lerp(0.0, angle, float(i) / smoothing));
	
	for i in range(1, smoothing + 1):
		mesh.surface_set_uv(Vector2(0, (i - 1) / smoothing))
		mesh.surface_add_vertex(array[i - 1]);
		mesh.surface_set_uv(Vector2(0, (i - 1) / smoothing))
		mesh.surface_add_vertex(array[i]);
		mesh.surface_set_uv(Vector2(0.5, 0.5))
		mesh.surface_add_vertex(center);
		
