extends SceneTree
## Base for behavioral suites. Run through tools/test.py for isolated user data.
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
