@tool
class_name World
extends Node3D

const CHUNK_SIZE := Vector3i(16,128,16)
const NEIGHBORS := [
	Vector3i.RIGHT, Vector3i.LEFT,
	Vector3i.UP, Vector3i.DOWN,
	Vector3i.FORWARD, Vector3i.BACK
]
const LOWEST_POINT: int = 0
const HIGHEST_POINT: int = 256
const WORLD_NAME = "test"

@export var grid_map: GridMap
@export var blocks: Array[Block]

@export_category("World Generation Settings")
@export var noises: Array[FastNoiseLite]
@export var height_intensity: int
@export var height_offset: int

var seed: int
var exiting
var mesh_library: MeshLibrary
var _block_lookup: Dictionary
var world_path: String = ""


# Chunks
@export_category("Chunks")
var chunk_queue: Queue
var chunk_threads: Array[Thread]
var chunks: Dictionary
@export var max_chunk_threads: int = 1
@export var rendering_distance = 10
@export var chunk_render_center: Node3D
@export var frustum_camera: Camera3D

func _add_inspector_buttons() -> Array:
	return [
		{"name": "Generate", "pressed": _generate},
		{"name": "Clear", "pressed": _clear}
	]

func _clear() -> void:
	grid_map.clear()
	chunk_queue.clear()

func get_noise_average(x: float, y: float) -> float:
	var total_value = 0.0
	
	for noise in noises:
		total_value += noise.get_noise_2d(x, y)
	
	var combined_value = total_value / noises.size()

	return combined_value

func get_block_numeric_id(id: String) -> int:
	return _block_lookup[id]

func _unload_chunk(chunk_pos: Vector2i) -> void:
	for fakeX in CHUNK_SIZE.x:
		var x = chunk_pos.x*CHUNK_SIZE.x + fakeX
		for fakeZ in CHUNK_SIZE.z:
			var z = chunk_pos.y*CHUNK_SIZE.z + fakeZ
			for y in range(LOWEST_POINT,HIGHEST_POINT):
				grid_map.set_cell_item(Vector3i(x,y,z),-1)

func _get_chunk(chunk_pos: Vector2i) -> Chunk:
	var chunk_path = world_path + "/chunks/" + str(chunk_pos.x) + "-" + str(chunk_pos.y) + ".ch"
	#if FileAccess.file_exists(chunk_path):
	#	return _load_chunk(chunk_path)
	var data: Dictionary = _generate_chunk_blocks(chunk_pos)
	var chunk := Chunk.new(chunk_pos,data,self)
	_save_chunk(chunk,chunk_path)
	return chunk
func _load_chunk(path: String) -> Chunk:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("Failed to open file for reading.")
		return
	
	var chunk_pos := Vector2i(file.get_32(), file.get_32())
	var total = file.get_32()
	var data = {}
	for i in range(total):
		var pos := Vector3i(file.get_32(),file.get_32(),file.get_32())
		data[pos] = file.get_32()
	
	return Chunk.new(chunk_pos,data,self)
func _save_chunk(chunk: Chunk, path: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("Failed to open file for writing.")
		return
	
	file.store_32(chunk.get_x())
	file.store_32(chunk.get_z())
	file.store_32(chunk.get_data().size())

	for key in chunk.get_data().keys():
		file.store_32(key.x)
		file.store_32(key.y)
		file.store_32(key.z)
		file.store_32(chunk.get_data()[key])

	file.close()

func _generate_chunk_blocks(chunk_pos: Vector2i) -> Dictionary:
	var start := Time.get_ticks_msec()
	var data := {}
	for fakeX in CHUNK_SIZE.x:
		var x = chunk_pos.x*CHUNK_SIZE.x + fakeX
		for fakeZ in CHUNK_SIZE.z:
			var z = chunk_pos.y*CHUNK_SIZE.z + fakeZ
			var height: int = floor(get_noise_average(x, z) 
				* height_intensity + height_offset)
			for y in range(LOWEST_POINT,height):
				data[Vector3i(fakeX,y,fakeZ)] = get_block_numeric_id("stone")
			if height < 63:
				for y in range(height,63):
					data[Vector3i(fakeX,y,fakeZ)] = get_block_numeric_id("water")
			data[Vector3i(fakeX,LOWEST_POINT,fakeZ)] = get_block_numeric_id("bedrock")
	print("Generating chunk took " + str(Time.get_ticks_msec() - start) + "ms")
	return data

func _load_blocks() -> void:
	var start := Time.get_ticks_msec()
	mesh_library = MeshLibrary.new()
	var id: int = 0
	for block in blocks:
		block.setup(id)
		_block_lookup[block.id] = id
		
		mesh_library.create_item(id)
		mesh_library.set_item_name(id, block.id)
		
		var mesh: BoxMesh = BoxMesh.new()
		var mat: Material = StandardMaterial3D.new()
	
		if block.actually_transparent:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = block.color
		mat.albedo_texture = block.texture
		mat.uv1_triplanar = true
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		
		mesh.material = mat

		mesh_library.set_item_mesh(id,mesh)
		if block.collision_shape != null:
			var collision_shapes := []
			collision_shapes.push_back(block.collision_shape)
			mesh_library.set_item_shapes(id,collision_shapes)
	
		id += 1
	grid_map.mesh_library = mesh_library
	print("Loading blocks took " + str(Time.get_ticks_msec() - start) + "ms")

func _generate() -> void:
	var start := Time.get_ticks_msec()
	world_path = "user://worlds/" + WORLD_NAME
	DirAccess.make_dir_recursive_absolute(world_path + "/chunks")

	
	_block_lookup = {}
	_load_blocks()
	
	seed = randi() % 9999999999
	seed(seed)
	for noise in noises:
		noise.seed = seed
	
	exiting = false
	chunk_queue = Queue.new(-1)
	chunks = {}
	
	var start2 := Time.get_ticks_msec()
	_clear()
	print("Clearing gridmap took " + str(Time.get_ticks_msec() - start2) + "ms")
	
	if (Engine.is_editor_hint()):
		for x in rendering_distance:
			for z in rendering_distance:
				chunk_queue.offer(Vector2i(x,z))
	
	for i in range(max_chunk_threads):
		var chunk_thread := Thread.new()
		chunk_thread.start(_chunk_render.bind())
		
		chunk_threads.push_back(chunk_thread)

	if (Engine.is_editor_hint()):
		for thread in chunk_threads:
			thread.wait_to_finish()
	print("Total time: " + str(Time.get_ticks_msec() - start) + "ms")
func _render_block(position: Vector3i, chunk_pos: Vector3i, id: int, chunk: Chunk) -> void:
	if chunk.has_empty_neighbor(chunk_pos):
		grid_map.call_thread_safe("set_cell_item", position, id)

func _chunk_loading() -> void:
	var last_center_chunk: Vector2i
	while true:
		# Loading & unloading
		var center_pos := chunk_render_center.global_transform.origin
		var center_chunk := Vector2i(floor(center_pos.x / CHUNK_SIZE.x), floor(center_pos.z / CHUNK_SIZE.z))
		if center_chunk != last_center_chunk and not Engine.is_editor_hint():
			last_center_chunk = center_chunk
			for chunk_pos in chunks.keys():
				if chunk_pos.distance_to(center_chunk) > rendering_distance:
					_unload_chunk(chunk_pos)
			for x in range(center_chunk.x - rendering_distance, center_chunk.x + rendering_distance + 1):
				for z in range(center_chunk.y - rendering_distance, center_chunk.y + rendering_distance + 1):
					var chunk_pos = Vector2i(x, z)
					if not chunks.has(chunk_pos) and is_chunk_in_frustum(chunk_pos):
						chunk_queue.offer(chunk_pos)
		await get_tree().create_timer(0.05).timeout

func _chunk_render() -> void:
	var i = 0
	while not exiting:
		var start := Time.get_ticks_msec()
		if (Engine.is_editor_hint() and chunk_queue.empty()):
			# No need to set exiting to true
			break
		
		# Emptying queue
		var chunk_pos = chunk_queue.poll()
		if chunk_pos != null and not chunks.has(chunk_pos):
			var chunk: Chunk = _get_chunk(chunk_pos)
			chunks[chunk_pos] = chunk
			for chunkPos in chunk.get_data().keys():
				var pos: Vector3i = Vector3i(chunk.get_x()*CHUNK_SIZE.x+chunkPos.x,chunkPos.y,chunk.get_z()*CHUNK_SIZE.z+chunkPos.z)
				_render_block(pos,chunkPos,chunk.get_data()[chunkPos],chunk)
		print("Rendering chunk took " + str(Time.get_ticks_msec() - start) + "ms")
		await get_tree().create_timer(0.001 if chunk_queue.empty() else 0.05).timeout

func is_chunk_in_frustum(chunk_pos: Vector2i) -> bool:
	return true

func _ready() -> void:
	if not Engine.is_editor_hint():
		_generate()
	
func _exit_tree():
	exiting = true
	for thread in chunk_threads:
		thread.wait_to_finish()
