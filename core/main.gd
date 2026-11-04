extends Node
## Entry point: shows the premise, then starts chapter 1.

const CHAPTER_1 := "res://chapters/01_adam_and_eve/scenes/chapter.tscn"

func _ready() -> void:
	get_tree().change_scene_to_file.call_deferred(CHAPTER_1)
