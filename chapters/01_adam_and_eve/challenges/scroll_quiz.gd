extends Challenge
## Scroll check: fill in a missing word from verses the scribe recorded (KJV).
## A wrong answer shows the verse and asks again, so the quiz can't be failed.
## Questions come from the challenge's "questions" list in beats.json:
## {text (with ____ for the blank), options, answer (index), verse, full (the whole verse)}.

var _qs: Array = []
var _i := 0

func start() -> void:
	_qs = cfg.get("questions", [])
	_i = 0
	_next()

func _next() -> void:
	if _i >= _qs.size():
		finish()
		return
	var q: Dictionary = _qs[_i]
	host.ask("[b]Scroll check %d of %d[/b]\nFill in the missing words.\n\n[i]\"%s\"[/i]  (%s)" % [_i + 1, _qs.size(), q["text"], q["verse"]],
			q["options"], _answer)

func _answer(choice: int) -> void:
	var q: Dictionary = _qs[_i]
	if choice == int(q["answer"]):
		_i += 1
		_next()
		return
	host.say([{"speaker": "Codex", "text": "Not quite. Your scroll reads: \"%s\" Try again." % q["full"]}], _next)

func status() -> String:
	if _qs.is_empty():
		return "Scroll check"
	return "Scroll check: %d/%d" % [mini(_i + 1, _qs.size()), _qs.size()]
