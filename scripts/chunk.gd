@tool
class_name Chunk
extends RefCounted

const BLOCK_UVS: Array[Vector2] = [
	Vector2(0, 0), Vector2(1, 0),
	Vector2(1, 1), Vector2(0, 1)
]
const BLOCK_FACE_DATA: Array[Dictionary] = [
	{ # Front
		vertices = [Vector3.ZERO, Vector3.RIGHT, Vector3(1, 1, 0), Vector3.UP],
		normal = Vector3.FORWARD,
		uvs = BLOCK_UVS
	},
	{ # Back
		vertices = [Vector3(1, 0, 1), Vector3.BACK, Vector3(0, 1, 1), Vector3.ONE],
		normal = Vector3.BACK,
		uvs = BLOCK_UVS
	},
	{ # Left
		vertices = [Vector3.BACK, Vector3.ZERO, Vector3.UP, Vector3(0, 1, 1)],
		normal = Vector3.LEFT,
		uvs = BLOCK_UVS
	},
	{ # Right
		vertices = [Vector3.RIGHT, Vector3(1,0,1), Vector3.ONE, Vector3(1, 1, 0)],
		normal = Vector3.RIGHT,
		uvs = BLOCK_UVS
	},
	{ # Top
		vertices = [Vector3.UP, Vector3(1, 1, 0), Vector3.ONE, Vector3(0, 1, 1)],
		normal = Vector3.UP,
		uvs = BLOCK_UVS
	},
	{ # Bottom
		vertices = [Vector3.BACK, Vector3(1, 0, 1), Vector3.RIGHT, Vector3.ZERO],
		normal = Vector3.DOWN,
		uvs = BLOCK_UVS
	}
]

var _position: Vector2i
var _position_3: Vector3i
var _data: Dictionary
var _world: World
var _node: MeshInstance3D
var _collision_shape: CollisionShape3D

func _init(position: Vector2i, data: Dictionary, world: World) -> void:
	self._position = position
	self._position_3 = Vector3i(position.x,0,position.y)
	self._data = data
	self._world = world
	self._node = MeshInstance3D.new()
	
	var static_body := StaticBody3D.new()
	_collision_shape = CollisionShape3D.new()
	
	_node.name = str(_position.x) + "," + str(position.y)
	_node.position = _position_3 * _world.CHUNK_SIZE.x
	
	render()
	
	static_body.add_child(_collision_shape)
	_node.add_child(static_body)
	_world.chunk_container.call_thread_safe("add_child",_node)

func get_data() -> Dictionary:
	return _data
func get_pos() -> Vector2i:
	return _position
func get_pos3() -> Vector3i:
	return _position_3
func get_x() -> int:
	return _position.x
func get_z() -> int:
	return _position.y

## Checks whether the block at said chunk-relative position has
## an empty or transparent neighbor.
func has_empty_neighbor(pos: Vector3i) -> bool:
	for neighbor in _world.NEIGHBORS:
		if not _data.has(pos + neighbor) or _world.blocks[_data[pos + neighbor]].actually_transparent:
			return true
	return false
func is_face_visible(pos: Vector3i, direction: Vector3i) -> bool:
	var position := pos + direction
	return not _data.has(position) or _world.blocks[_data[position]].actually_transparent

func render() -> void: # Called only once to render chunk
	var mesh = ArrayMesh.new()
	
	var vertices = PackedVector3Array()
	var collision_vertices = PackedVector3Array()
	var uvs = PackedVector2Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	var index_offset = 0 
	
	var vertices_t = PackedVector3Array()
	var uvs_t = PackedVector2Array()
	var normals_t = PackedVector3Array()
	var indices_t = PackedInt32Array()
	var index_offset_t = 0 
	
	var uv_size = (1.0/_world.atlas_size)
	

	for x in range(_world.CHUNK_SIZE.x):
		for y in range(_world.CHUNK_SIZE.y):
			for z in range(_world.CHUNK_SIZE.z):
				var pos_i := Vector3i(x,y,z)
				var pos := Vector3(x,y,z)
				if _data.has(pos_i):  # Only render if there's a block
					var block_id: int = _data[pos_i]
					var block: Block = _world.blocks[block_id]
					if has_empty_neighbor(pos_i):
						var uv_offset = _get_uv_offset(block_id, uv_size)
						
						var v: PackedVector3Array
						var n: PackedVector3Array
						var u: PackedVector2Array
						var i: PackedInt32Array
						var io: int
						
						if block.actually_transparent:
							v = vertices_t
							n = normals_t
							u = uvs_t
							i = indices_t
							io = index_offset_t
						else:
							v = vertices
							n = normals
							u = uvs
							i = indices
							io = index_offset
						
						for face in BLOCK_FACE_DATA:
							if not is_face_visible(pos,face.normal) and false: # Can't use this because else collision might fuck up
								continue
							
							for vertex in face.vertices:
								var temp: Vector3 = pos + vertex
								if block.can_collide:
									collision_vertices.push_back(temp)
								v.push_back(temp)
								if (block.actually_transparent): # THESE 2!
									pass # DONT REMOVE THESE 2 LINES! BREAKS TRANSPARENT BLOCKS!
							
							for j in range(4):
								n.append(face.normal)
							
							for uv in face.uvs:
								u.append(uv_offset + uv * uv_size)
							
							i.append(io + 0)
							i.append(io + 1)
							i.append(io + 2)
							i.append(io + 0)
							i.append(io + 2)
							i.append(io + 3)
							
							io += 4
							
							if block.actually_transparent:
								index_offset_t = io
							else:
								index_offset = io
					
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _world.block_material)
	
	
	if vertices_t.size() != 0:
		var arrays_t = []
		arrays_t.resize(Mesh.ARRAY_MAX)
		arrays_t[Mesh.ARRAY_VERTEX] = vertices_t
		arrays_t[Mesh.ARRAY_TEX_UV] = uvs_t
		arrays_t[Mesh.ARRAY_NORMAL] = normals_t
		arrays_t[Mesh.ARRAY_INDEX] = indices_t

		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_t)
		mesh.surface_set_material(1, _world.block_material_transparent)
	_node.mesh = mesh
	
	# Funny collision stuff
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(collision_vertices) # error here
	_collision_shape.shape = shape

func _get_uv_offset(block_id: int, uv_size) -> Vector2:
	var atlas_size = _world.atlas_size
	var block_x = block_id % atlas_size
	var block_y = block_id / atlas_size
	var uv_offset = Vector2(block_x, block_y) * uv_size
	return uv_offset
