extends Node
## Saves a screenshot of each part of chapter 1's world (for comparing graphics changes).
## Needs a display:  godot --rendering-driver opengl3 res://tools/test/scenery_shots.tscn -- --shots=<dir>
## (in a headless Linux box, run it under xvfb-run).

const CHAPTER := preload("res://chapters/01_adam_and_eve/scenes/chapter.tscn")
# [file label, scribe x, scribe z, beat whose mood to show]
const SPOTS := [["void", 3.0, 0.0, 0], ["light", 12.0, 0.0, 1], ["sea", 21.0, 0.5, 2], ["sky", 31.0, 0.0, 3],
	["animals", 41.0, 0.0, 4], ["rest", 50.0, 0.0, 5], ["eden", 60.0, -2.0, 6], ["eden_pond", 57.0, -5.0, 6], ["naming", 84.0, 0.0, 7], ["flowers", 108.0, 3.0, 8], ["gather", 121.0, 0.0, 8], ["tree", 140.0, 0.0, 9],
	["dark", 150.0, 0.0, 10], ["gate", 175.0, 0.0, 11]]

func _ready() -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.substr(8)
	var ch: Node = CHAPTER.instantiate()
	add_child(ch)
	await get_tree().process_frame
	ch._beat_index = 999  # no story beats: just look around
	ch._scribe.max_x = 1e9
	for s in SPOTS:
		ch._scribe.position = Vector3(s[1], 0, s[2])
		ch._apply_mood(Color(ch._beats[s[3]]["tint"]))
		ch._cam.position = ch._cam_target()
		for i in 30:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, s[0]])
	get_tree().quit()
