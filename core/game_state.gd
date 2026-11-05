extends Node
## Global state: chosen scribe, unlocked verses, finished chapters. Saved to user://save.json.

const SAVE_PATH := "user://save.json"

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
