class_name CharacterFactory
extends RefCounted
## Builds a character by id, in the game's low-poly style (core/lowpoly).
## Ids: scribe_female, scribe_male, adam, eve, adam_skins, eve_skins, cherub, serpent, mom, dad, grandma, sibling.
## Every character's front faces +X (like the rest of the game), so turning the node turns the character.

const LOOKS := {
	"scribe_female": LowPolyPerson.SCRIBE_F, "scribe_male": LowPolyPerson.SCRIBE_M,
	"adam": LowPolyPerson.ADAM, "eve": LowPolyPerson.EVE, "adam_skins": LowPolyPerson.ADAM_SKINS,
	"eve_skins": LowPolyPerson.EVE_SKINS, "cherub": LowPolyPerson.CHERUB,
	"mom": LowPolyPerson.MOM, "dad": LowPolyPerson.DAD, "grandma": LowPolyPerson.GRANDMA, "sibling": LowPolyPerson.SAM,
}

static func has_model(id: String) -> bool:
	return LOOKS.has(id) or id == "serpent"

static func make(id: String, parent: Node3D, pos: Vector3, faces_left: bool = false) -> Node3D:
	var n: Node3D
	if id == "serpent":
		n = LowPolyAnimal.create("serpent")
	else:
		n = LowPolyPerson.create(LOOKS.get(id, LowPolyPerson.SCRIBE_F))
	n.name = id
	n.position = pos
	n.rotation.y = PI if faces_left else 0.0
	parent.add_child(n)
	return n

## Kept for older callers: low-poly characters have no AnimationPlayer.
static func animator(_holder: Node) -> AnimationPlayer:
	return null

## Animate a character: "Idle", "Walk", "Run", "Victory" (cheer), "SitDown", "Wave", "Talk".
static func play(holder: Node, anim_name: String, _offset: float = 0.0, speed: float = 1.0) -> void:
	if holder is LowPolyPerson:
		var p := holder as LowPolyPerson
		p.walk_speed = speed if anim_name in ["Walk", "Run"] else 0.0
		p.sitting = anim_name == "SitDown"
		p.gesture = {"Victory": "cheer", "Wave": "wave", "Talk": "talk"}.get(anim_name, "")
	elif holder is LowPolyAnimal:
		(holder as LowPolyAnimal).set_moving(anim_name in ["Walk", "Run"])
