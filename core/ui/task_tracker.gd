class_name TaskTracker
extends CanvasLayer
## The task card in the top-left corner: what to do now, with a progress bar under each task.
##
##     tracker.set_task("Water the plants", 2, 5)        # one task, 2 of 5 done
##     tracker.set_tasks([
##         {"title": "Water the plants", "hint": "Fill the jar at the river.", "done": 2, "total": 5},
##         {"title": "Find the lost lamb", "progress": 0.4, "side": true},   # a side quest
##     ])
##     tracker.clear()
##
## Entries: title, and either done + total or progress (0..1). Optional hint (a small line under
## the title) and side (shown as a side quest). Safe to call every frame: rows are reused and the
## bars glide to their new value. A task that reaches 100% turns green.

const WIDTH := 470.0

## Where the card's top-left corner sits (under a scene's title label).
var at := Vector2(24, 70):
	set(v):
		at = v
		if _col:
			_col.position = v

var _col: VBoxContainer
var _rows: Array = []  # {panel, kind, title, hint, bar, count, value, last}

func _ready() -> void:
	layer = 5
	_col = VBoxContainer.new()
	_col.position = at
	_col.custom_minimum_size = Vector2(WIDTH, 0)
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_theme_constant_override("separation", 10)
	add_child(_col)

func set_task(title: String, done: int, total: int) -> void:
	set_tasks([{"title": title, "done": done, "total": total}])

func clear() -> void:
	set_tasks([])

## Number of tasks showing (used by tests).
func count() -> int:
	var n := 0
	for r in _rows:
		if (r["panel"] as Control).visible:
			n += 1
	return n

## The progress (0..1) of task i as given, not the animated bar.
func value(i: int) -> float:
	return float(_rows[i]["value"]) if i < _rows.size() else 0.0

func set_tasks(list: Array) -> void:
	while _rows.size() < list.size():
		_rows.append(_make_row())
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var panel: Control = r["panel"]
		if i >= list.size():
			panel.visible = false
			continue
		var e: Dictionary = list[i]
		var p := 0.0
		var count_text := ""
		if e.has("total"):
			var total := maxi(1, int(e["total"]))
			p = float(e.get("done", 0)) / float(total)
			count_text = "%d / %d" % [int(e.get("done", 0)), int(e["total"])]
		else:
			p = float(e.get("progress", 0.0))
			count_text = "%d%%" % roundi(clampf(p, 0.0, 1.0) * 100.0)
		p = clampf(p, 0.0, 1.0)
		var side := bool(e.get("side", false))
		var kind_text := "SIDE QUEST" if side else "TASK"
		if p >= 1.0:
			kind_text += "  ·  DONE"
		var c := UiStyle.GREEN if p >= 1.0 else (UiStyle.TEAL if side else UiStyle.GOLD)
		if r["color"] != c:
			r["color"] = c
			(r["kind"] as Label).add_theme_color_override("font_color", c)
			UiStyle.set_bar_color(r["bar"], c)
		_set_text(r["kind"], kind_text)
		_set_text(r["title"], String(e.get("title", "")))
		var hint := String(e.get("hint", ""))
		_set_text(r["hint"], hint)
		(r["hint"] as Label).visible = hint != ""
		_set_text(r["count"], count_text)
		var old := float(r["value"])
		if not panel.visible:
			panel.visible = true
			panel.modulate.a = 0.0
			create_tween().tween_property(panel, "modulate:a", 1.0, 0.25)
			(r["bar"] as ProgressBar).value = p
		elif p > old + 0.0001:
			_pulse(panel)
		r["value"] = p

func _set_text(l: Label, t: String) -> void:
	if l.text != t:
		l.text = t

func _process(delta: float) -> void:
	for r in _rows:
		var b: ProgressBar = r["bar"]
		b.value = lerpf(b.value, float(r["value"]), minf(1.0, delta * 6.0))

func _pulse(panel: Control) -> void:
	panel.pivot_offset = panel.size / 2.0
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2(1.04, 1.04), 0.1)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.2)

func _make_row() -> Dictionary:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiStyle.card(UiStyle.GLASS, 18, 16))
	panel.visible = false
	_col.add_child(panel)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	var kind := UiStyle.label("TASK", 16, UiStyle.GOLD, 900)
	v.add_child(kind)
	var title := UiStyle.label("", 23, UiStyle.TEXT, 750)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(WIDTH - 34, 0)
	v.add_child(title)
	var hint := UiStyle.label("", 18, UiStyle.TEXT_DIM, 600)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(WIDTH - 34, 0)
	v.add_child(hint)
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_theme_constant_override("separation", 12)
	v.add_child(foot)
	var bar := UiStyle.bar(UiStyle.GOLD, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(bar)
	var count := UiStyle.label("", 18, UiStyle.TEXT_DIM, 800)
	count.custom_minimum_size = Vector2(56, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.add_child(count)
	return {"panel": panel, "kind": kind, "title": title, "hint": hint, "bar": bar, "count": count, "value": 0.0, "color": Color.BLACK}
