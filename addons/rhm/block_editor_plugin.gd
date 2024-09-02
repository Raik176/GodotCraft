@tool
class_name BlockEditorPlugin
extends EditorInspectorPlugin

const sides := ["front","back","left","right"]
const faces := ["top","bottom"]

func _can_handle(object: Object) -> bool:
	return object is Block

func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	var block: Block = object as Block
	
	if block.use_faced_texture:
		if name == "texture":
			return true
		if block.same_side_texture:
			if sides.has(name):
				return true
		else:
			if name == "side":
				return true
	else:
		if sides.has(name) or faces.has(name) or name == "side" or name == "same_side_texture":
			return true
