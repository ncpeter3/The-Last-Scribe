extends CharacterBody2D
## Side-scrolling scribe controller. Keyboard (A/D) or on-screen buttons via move_dir.

@export var speed := 260.0
var move_dir := 0.0  # set by touch controls

func _physics_process(_delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	if dir == 0.0:
		dir = move_dir
	velocity.x = dir * speed
	move_and_slide()
