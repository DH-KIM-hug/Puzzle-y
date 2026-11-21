## ADR-0001 Validation Criteria: src/core must contain none of the forbidden
## tokens (Node inheritance, engine RNG/time/OS, fractional numbers, String.hash).
## Full-line comments are skipped; the test reports each hit as an observation.
extends GdUnitTestSuite

const ROOT := "res://src/core"
const FORBIDDEN: Array[String] = [
	"extends Node", "get_tree(", "randi(", "randf(", "randomize(", "RandomNumberGenerator",
	"Time.", "OS.", "Engine.", ": float", "-> float", "float(", ".hash()",
]


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir + "/" + d))
	return out


func test_rules_core_has_no_forbidden_tokens() -> void:
	var files := _scripts(ROOT)
	assert_int(files.size()).is_greater(20)
	var fraction := RegEx.create_from_string("\\b\\d+\\.\\d+\\b")
	var hits: Array[String] = []
	for path: String in files:
		var n := 0
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue
			for token: String in FORBIDDEN:
				if code.contains(token):
					hits.append("%s:%d %s" % [path, n, token])
			if fraction.search(code) != null:
				hits.append("%s:%d fractional literal" % [path, n])
	assert_array(hits).is_empty()


func test_rules_core_scripts_extend_refcounted_or_resource_only() -> void:
	for path: String in _scripts(ROOT):
		var text := FileAccess.get_file_as_string(path)
		var ok := text.contains("extends RefCounted") or text.contains("extends Resource")
		assert_bool(ok).override_failure_message(path).is_true()
