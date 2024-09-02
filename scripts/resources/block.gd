@tool
class_name Block
extends Resource

@export var id: String
@export_subgroup("Texture")
@export var texture: Texture2D = preload("res://assets/missing_texture.png")
@export var use_faced_texture: bool = false:
	set(value):
		use_faced_texture = value
		notify_property_list_changed()
@export var same_side_texture: bool = false:
	set(value):
		same_side_texture = value
		notify_property_list_changed()
@export var front: Texture2D = preload("res://assets/missing_texture.png")
@export var back: Texture2D = preload("res://assets/missing_texture.png")
@export var left: Texture2D = preload("res://assets/missing_texture.png")
@export var right: Texture2D = preload("res://assets/missing_texture.png")
@export var top: Texture2D = preload("res://assets/missing_texture.png")
@export var bottom: Texture2D = preload("res://assets/missing_texture.png")
@export var side: Texture2D = preload("res://assets/missing_texture.png")
@export_group("Other")
@export var color: Color = Color(1,1,1,1)
@export var transparent: bool = false
@export var can_collide: bool = true
@export var size: Vector3 = Vector3.ONE

var numeric_id: int
var actually_transparent: bool
var uv_offset: Vector2
var uv_size: Vector2

func setup(id: int) -> void:
	numeric_id = id
	actually_transparent = transparent or color.a != 1
