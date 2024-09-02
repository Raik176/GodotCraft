@tool
class_name Block
extends Resource

@export var id: String
@export var texture: Texture2D = preload("res://assets/missing_texture.png")
@export var color: Color = Color(1,1,1,1)
@export var transparent: bool = false
@export var collision_shape: Shape3D

var numeric_id: int
var actually_transparent: bool
var uv_offset: Vector2
var uv_size: Vector2

func setup(id: int) -> void:
	numeric_id = id
	actually_transparent = transparent or color.a != 1
