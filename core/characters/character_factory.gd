class_name CharacterFactory
extends RefCounted
## Builds a character by id. If a real model exists at res://shared_assets/characters/<id>.glb
## it is used (with its Idle/Walk animations); otherwise a simple placeholder figure is built.
## Ids: scribe_female, scribe_male, adam, eve, adam_skins, eve_skins, cherub, serpent.
## Every character is returned inside a holder node whose front faces +X (like the rest of the game),
## so turning the holder turns the character.

const DIR := "res://shared_assets/characters/"
const LOOPING := ["Idle", "Walk", "Run"]

static func has_model(id: String) -> bool:
	return ResourceLoader.exists(DIR + id + ".glb")

static func make(id: String, parent: Node3D, pos: Vector3, faces_left: bool = false) -> Node3D:
	var path := DIR + id + ".glb"
	if ResourceLoader.exists(path):
		var holder := Node3D.new()
		holder.name = id
		holder.position = pos
		holder.rotation.y = PI if faces_left else 0.0
		parent.add_child(holder)
		var model: Node3D = (load(path) as PackedScene).instantiate()
		# glTF models face +Z; turn them to face +X.
		model.rotation.y = PI / 2.0
		holder.add_child(model)
		play(holder, "Idle", randf() * 2.0)
		return holder
	if id == "cherub":
		return Props.cherub_placeholder(parent, pos)
	if id == "serpent":
		return Props.serpent_placeholder(parent, pos)
	return Props.person(parent, pos, id.begins_with("eve") or id.ends_with("female"), faces_left)

static func animator(holder: Node) -> AnimationPlayer:
	return holder.find_child("AnimationPlayer", true, false) as AnimationPlayer

## Play an animation if the model has it. Idle, Walk and Run loop. `offset` starts partway in,
## so a herd of the same animal doesn't move in lockstep.
static func play(holder: Node, anim_name: String, offset: float = 0.0, speed: float = 1.0) -> void:
	var anim := animator(holder)
	if anim == null or not anim.has_animation(anim_name):
		return
	if anim.current_animation == anim_name:
		anim.speed_scale = speed
		return
	var a := anim.get_animation(anim_name)
	if anim_name in LOOPING:
		a.loop_mode = Animation.LOOP_LINEAR
	anim.play(anim_name, 0.2)
	anim.speed_scale = speed
	if offset > 0.0:
		anim.seek(fmod(offset, a.length), true)
