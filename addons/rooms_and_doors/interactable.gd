class_name Interactable
extends Area3D
## Generic interact prompt volume. Forwards to the parent's `interact`/`get_prompt`.
## Player controllers find Interactables they overlap and call these.

@export var verbs: PackedStringArray = ["toggle", "knock", "listen", "peek", "lock", "unlock", "ajar"]


func prompt_for(actor_id: StringName) -> String:
	var p := get_parent()
	return p.get_prompt(actor_id) if p != null and p.has_method(&"get_prompt") else ""


func interact(actor_id: StringName, verb: StringName = &"toggle", opts: Dictionary = {}) -> Dictionary:
	var p := get_parent()
	if p != null and p.has_method(&"interact"):
		return p.interact(actor_id, verb, opts)
	return {}
