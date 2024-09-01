@tool
extends Node

# DO NOT USE!

var mesh_library: MeshLibrary
var _blocks: Array[Dictionary] = [
	#{
	#	"id": "test",
	#	"texture": preload("nil"),
	#	"color": Color(0,0,0,0),
	#	"transparent": true
	#}
	{
		"id": "stone",
		"texture": preload("res://assets/blocks/stone.png"),
	},
	{
		"id": "water",
		"texture": preload("res://assets/blocks/water.png"),
		"transparent": true
	}
]
var _block_lookup: Dictionary = {}

func _get_block_id(numeric_id: int) -> int:
	return _blocks[numeric_id].id

func _get_block_numeric_id(id: String) -> int:
	return _block_lookup[id]

func _get_block_data(id: int, key: String, placeholder):
	return _blocks[id][key] if _blocks[id].has(key) else placeholder

## Returns a block's texture
func get_block_texture(id: int) -> Texture:
	return _get_block_data(id,"texture",preload("res://assets/missing_texture.png"))

## Returns a block's color
func get_block_color(id: int) -> Color:
	return _get_block_data(id,"color",Color(1,1,1,1))

## Returns whether a block is transparent
func is_block_transparent(id: int) -> bool:
	return _get_block_data(id,"transparent",false)

## Returns whether a block is transparent, including the color alpha.
func is_block_transparent_color(id: int) -> bool:
	return get_block_color(id).a != 1 or is_block_transparent(id)


func load_blocks(world: World) -> void:
	mesh_library = MeshLibrary.new()
	var id: int = 0
	for block in _blocks:
		_block_lookup[block["id"]] = id
		
		mesh_library.create_item(id)
		mesh_library.set_item_name(id, block.id)
		
		var mesh: BoxMesh = BoxMesh.new()
		var mat: Material = StandardMaterial3D.new()
	
		if is_block_transparent_color(id):
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = get_block_color(id)
		mat.albedo_texture = get_block_texture(id)
		mat.uv1_triplanar = true
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		
		mesh.material = mat

		mesh_library.set_item_mesh(id,mesh)
		mesh_library.set_item_navigation_mesh(id, NavigationMesh.new())
	
		id += 1
	world.grid_map.mesh_library = mesh_library
