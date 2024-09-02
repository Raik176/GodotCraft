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

@export var blocks: Array[Block]

@export_category("World Generation Settings")
@export var noises: Array[FastNoiseLite]
@export var height_intensity: int
@export var height_offset: int

var seed: int
var exiting
var _block_lookup: Dictionary
var world_path: String = ""

var texture_atlas: Texture
var atlas_size: int
var block_material: StandardMaterial3D
var block_material_transparent: StandardMaterial3D


# Chunks
@export_category("Chunks")
var chunk_queue: Queue
var chunk_threads: Array[Thread]
var chunk_render_thread: Thread
var chunks: Dictionary
@export var max_chunk_threads: int = 1
@export var rendering_distance = 10
@export var chunk_render_center: Node3D
@export var frustum_camera: Camera3D
@export var chunk_container: Node

func _add_inspector_buttons() -> Array:
	return [
		{"name": "Generate", "pressed": _generate},
		{"name": "Clear", "pressed": _clear}
	]

func _clear() -> void:
	chunk_queue.clear()
	for child in chunk_container.get_children():
		child.queue_free()

func get_noise_average(x: float, y: float) -> float:
	var total_value = 0.0
	
	for noise in noises:
		total_value += noise.get_noise_2d(x, y)
	
	var combined_value = total_value / noises.size()

	return combined_value

func get_block_numeric_id(id: String) -> int:
	return _block_lookup[id]

func _unload_chunk(chunk_pos: Vector2i) -> void: #TODO:
	for child in chunk_container.get_children():
		if child.name == str(chunk_pos.x) + "," + str(chunk_pos.y):
			child.queue_free()

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
				for y in range(height, 63):
					data[Vector3i(fakeX,y,fakeZ)] = get_block_numeric_id("water")
			data[Vector3i(fakeX,LOWEST_POINT,fakeZ)] = get_block_numeric_id("bedrock")
	return data

func _load_blocks() -> void:
	var id: int = 0

	var size = blocks[0].texture.get_width()
	atlas_size = int(ceil(sqrt(blocks.size())))
	var atlas_image := Image.create_empty(atlas_size * size, atlas_size * size, false, Image.FORMAT_RGBA8)

	for block in blocks:
		_block_lookup[block.id] = id
		block.setup(id)
		
		var x: int = (id % atlas_size) * size
		var y: int = (id / atlas_size) * size
		var block_image: Image = block.texture.get_image()
		if block_image.is_compressed():
			block_image.decompress()

		for i in range(size):
			for j in range(size):
				var color := block_image.get_pixel(i, j)
				atlas_image.set_pixel(x + i, y + j, color)
		id += 1
	
	texture_atlas = ImageTexture.create_from_image(atlas_image)

	
	block_material = StandardMaterial3D.new()
	block_material.albedo_texture = texture_atlas
	block_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	block_material_transparent = block_material.duplicate()
	block_material_transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	block_material_transparent.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
func _generate() -> void:
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
	
	_clear()

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
	else:
		chunk_render_thread = Thread.new()
		chunk_render_thread.start(_chunk_loading.bind())

func _chunk_loading() -> void:
	var last_center_chunk: Vector2i = Vector2i(-1,-1)
	while true:
		# Loading & unloading
		var center_pos := chunk_render_center.global_transform.origin
		var center_chunk := Vector2i(floor(center_pos.x / CHUNK_SIZE.x), floor(center_pos.z / CHUNK_SIZE.z))
		if center_chunk != last_center_chunk:
			last_center_chunk = center_chunk
			for chunk_pos in chunks.keys():
				if chunk_pos.distance_to(center_chunk) > rendering_distance:
					_unload_chunk(chunk_pos)
			for x in range(center_chunk.x - rendering_distance, center_chunk.x + rendering_distance + 1):
				for z in range(center_chunk.y - rendering_distance, center_chunk.y + rendering_distance + 1):
					chunk_queue.offer(Vector2i(x, z))
		await get_tree().create_timer(0.05).timeout

func _chunk_render() -> void:
	while not exiting:
		if (Engine.is_editor_hint() and chunk_queue.empty()):
			break
		
		# Emptying queue
		var chunk_pos = chunk_queue.poll()
		if chunk_pos != null and not chunks.has(chunk_pos):
			var chunk: Chunk = _get_chunk(chunk_pos)
			chunks[chunk_pos] = chunk
		await get_tree().create_timer(0.001 if chunk_queue.empty() else 0.05).timeout

func _ready() -> void:
	if not Engine.is_editor_hint():
		_generate()
	
func _exit_tree():
	exiting = true
	for thread in chunk_threads:
		thread.wait_to_finish()
	chunk_render_thread.wait_to_finish()
