extends Node3D
## Lines up every low-poly character for a screenshot (art check).
##   godot --rendering-driver opengl3 res://tools/test/lowpoly_lineup.tscn -- --shots=<dir>

func _ready() -> void:
	var dir := "/tmp"
	var pose := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.substr(8)
		if a.begins_with("--pose="):
			pose = a.substr(7)
	var we := WorldEnvironment.new()
	we.environment = Look.environment(null, Color(0.2, 0.22, 0.3))
	add_child(we)
	var sun := Look.sun()
	add_child(sun)
	var g := LowPoly.new()
	g.box(Vector3(0, -0.05, 1), Vector3(16, 0.1, 8), LowPoly.GRASS)
	add_child(g.instance())
	var looks := [LowPolyPerson.SCRIBE_F, LowPolyPerson.SCRIBE_M, LowPolyPerson.MOM, LowPolyPerson.DAD, LowPolyPerson.GRANDMA, LowPolyPerson.SAM]
	if "--chapter1" in OS.get_cmdline_user_args():
		looks = [LowPolyPerson.ADAM, LowPolyPerson.EVE, LowPolyPerson.ADAM_SKINS, LowPolyPerson.EVE_SKINS, LowPolyPerson.CHERUB]
		var ax := -5.0
		for id in ["cow", "horse", "zebra", "llama", "sheep", "pig", "wolf", "fox", "cat", "chick"]:
			var a := LowPolyAnimal.create(id)
			a.mode = "still"
			a.position = Vector3(ax, 0, 2.2)
			a.rotation.y = -PI / 2.0 + 0.9
			add_child(a)
			ax += 1.25
	var x := -4.0
	for l in looks:
		var p := LowPolyPerson.create(l)
		p.position = Vector3(x, 0, 0)
		p.rotation.y = -PI / 2.0  # face the camera
		if pose != "":
			p.gesture = pose
		add_child(p)
		x += 1.4
	var dog := LowPolyDog.new()
	dog.position = Vector3(x, 0, 0.3)
	dog.rotation.y = -PI / 2.0 + 0.6
	dog.pose = "stand"
	add_child(dog)
	var cam := Look.camera()
	cam.position = Vector3(0.5, 0, 0) + Look.CAM_OFFSET * 0.75
	add_child(cam)
	for i in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir + "/lineup%s.png" % pose)
	cam.position = Vector3(-3.3, 1.5, 3.2)
	cam.rotation_degrees = Vector3(-8, 0, 0)
	for i in 5:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir + "/closeup%s.png" % pose)
	get_tree().quit()
