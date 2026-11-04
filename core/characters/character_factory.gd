class_name CharacterFactory
extends RefCounted
## Builds a character by id. If a real model exists at res://shared_assets/characters/<id>.glb
## it is used (with its idle/walk animations); otherwise a simple placeholder figure is built.
## To add art: drop a .glb named after the id (scribe_female, scribe_male, adam, eve, ...).

const DIR := "res://shared_assets/characters/"

static func make(id: String, parent: Node3D, pos: Vector3, faces_left: bool = false) -> Node3D:
	var path := DIR + id + ".glb"
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path)
		var model: Node3D = scene.instantiate()
		model.position = pos
		model.rotation.y = PI if faces_left else 0.0
		parent.add_child(model)
		var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim and anim.has_animation("Idle"):
			anim.play("Idle")
		return model
	return Props.person(parent, pos, id.ends_with("eve") or id.ends_with("female"), faces_left)
