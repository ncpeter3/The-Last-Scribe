extends CharacterBody2D
## Side-scrolling scribe controller. Keyboard (A/D) or on-screen buttons via move_dir.
## frozen stops movement during dialogue; min_x/max_x keep the scribe inside the allowed area.

@export var speed := 300.0
var move_dir := 0.0  # set by touch controls
var frozen := false
var min_x := 0.0
var max_x := 1e9

func _physics_process(_delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	if dir == 0.0:
		dir = move_dir
	velocity.x = 0.0 if frozen else dir * speed
	move_and_slide()
	position.x = clampf(position.x, min_x, max_x)
