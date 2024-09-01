class_name Chunk
extends RefCounted

var _position: Vector2i
var _position_3: Vector3i
var _data: Dictionary
var _world: World

func _init(position: Vector2i, data: Dictionary, world: World) -> void:
	self._position = position
	self._position_3 = Vector3i(position.x,0,position.y)
	self._data = data
	self._world = world

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
