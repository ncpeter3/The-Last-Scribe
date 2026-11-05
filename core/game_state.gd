extends Node
## Global state: chosen scribe, unlocked verses, finished chapters. Saved to user://save.json.

const SAVE_PATH := "user://save.json"
## Every chapter in story order: [id, scene].
const CHAPTERS := [
	["01_adam_and_eve", "res://chapters/01_adam_and_eve/scenes/chapter.tscn"],
	["02_cain_and_abel", "res://chapters/02_cain_and_abel/scenes/chapter.tscn"],
]

var scribe_gender := "female"  # "female" or "male"
var unlocked_verses: Array = []  # entries like "Genesis 1:1"
var completed_chapters: Array = []
var side_quests: Array = []  # ids of finished side quests

func _ready() -> void:
	load_game()

func unlock_verse(ref: String) -> void:
	if ref not in unlocked_verses:
		unlocked_verses.append(ref)
		save_game()

func complete_chapter(id: String) -> void:
	if id not in completed_chapters:
		completed_chapters.append(id)
		save_game()

## The first chapter not finished yet (the time machine at home goes there), or the last one.
func next_chapter_scene() -> String:
	for c in CHAPTERS:
		if c[0] not in completed_chapters:
			return c[1]
	return CHAPTERS[-1][1]

func complete_side_quest(id: String) -> void:
	if id not in side_quests:
		side_quests.append(id)
		save_game()

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"scribe_gender": scribe_gender,
			"unlocked_verses": unlocked_verses,
			"completed_chapters": completed_chapters,
			"side_quests": side_quests,
		}))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		scribe_gender = data.get("scribe_gender", scribe_gender)
		unlocked_verses = data.get("unlocked_verses", [])
		completed_chapters = data.get("completed_chapters", [])
		side_quests = data.get("side_quests", [])
