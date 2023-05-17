# Copyright © 2019-present Hugo Locurcio and contributors - MIT License
# See `LICENSE.md` included in the source distribution for details.
extends TextEdit

onready var error_label: Label = $"../../OutputPanel/ErrorLabel"
onready var output_panel: RichTextLabel = $"../../OutputPanel/RichTextLabel"

# The printing functions to create.
const PRINT_FUNCS = {
	"print": "", # Nothing between arguments, newline at end.
	"prints": " ", # Space between arguments, newline at end.
	"printt": "\\t", # Tab between arguments, newline at end.
	"printraw": "", # Nothing between arguments, no newline at end.
}

# Functions to replace in the script that will be run (see above).
const FUNC_REPLACEMENTS = {
	"print(": "self.print(",
	"print (": "self.print (",
	"prints(": "self.prints(",
	"prints (": "self.prints (",
	"printt(": "self.printt(",
	"printt (": "self.prints (",
	"printraw(": "self.printraw(",
	"printraw (": "self.printraw (",
}

# Taken from the Default (Godot 2.x-like) script editor theme.
# https://github.com/godotengine/godot/blob/4ea73633047e5b52dee38ffe0b958f60e859d5b7/editor/editor_settings.cpp#L785-L822
const KEYWORD_COLOR := Color(1.0, 1.0, 0.7)
# More orange to be easier to distinguish.
const CONTROL_FLOW_KEYWORD_COLOR := Color(1.0, 0.7, 0.7)
const BASE_TYPE_COLOR := Color(0.64, 1.0, 0.83)
const ENGINE_TYPE_COLOR := Color(0.51, 0.83, 1.0)
const STRING_COLOR := Color(0.94, 0.43, 0.75)
# Slightly brighter than the default theme to improve readability.
const COMMENT_COLOR := Color(0.45, 0.45, 0.45)

# All reserved words in GDScript, minus control flow keywords (for syntax highlighting).
const KEYWORDS := [
	# Operators.
	"and",
	"in",
	"not",
	"or",
	# Types and values.
	"false",
	"float",
	"int",
	"bool",
	"null",
	"PI",
	"TAU",
	"INF",
	"NAN",
	"self",
	"true",
	"void",
	# Functions.
	"as",
	"assert",
	"await",
	"breakpoint",
	"class",
	"class_name",
	"extends",
	"is",
	"func",
	"preload",
	"signal",
	"super",
	"trait",
	"yield",
	# Variables.
	"const",
	"enum",
	"static",
	"var",
]

# Control flow keywords (for syntax highlighting).
const CONTROL_FLOW_KEYWORDS = [
	"break",
	"continue",
	"if",
	"elif",
	"else",
	"for",
	"pass",
	"return",
	"match",
	"while",
]

# All base types in Godot (for syntax highlighting).
const BASE_TYPES = [
	"null",
	"String",
	"Vector2",
	"Rect2",
	"Vector3",
	"Transform2D",
	"Plane",
	"Quat",
	"AABB",
	"Basis",
	"Transform",
	"Color",
	"NodePath",
	"RID",
	"Object",
	"Dictionary",
	"Array",
	"PoolByteArray",
	"PoolIntArray",
	"PoolRealArray",
	"PoolStringArray",
	"PoolVector2Array",
	"PoolVector3Array",
	"PoolColorArray",
]

# Implement `print()` functions in the script for use with the output panel.
# This must be done because built-in `print()` functions' output cannot be redirected.
var print_func_template := """
func {name}(arg1 = '', arg2 = '', arg3 = '', arg4 = '', arg5 = '', arg6 = '', arg7 = '', arg8 = '', arg9 = '') -> void:
	# Also call the built-in printing function
	{name}(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)

	var text := ''
	for argument in [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9]:
		text += str(argument) + '{separator}'

	text += '{end_separator}'

	{output_panel}.add_text(text)
""".format({
		output_panel = "$'/root/MainWindow/HSplitContainer/OutputPanel/RichTextLabel'"
})

# The script shim that will be inserted at the end of the user-provided script.
var script_shim := ""

# JavaScript event callback for 'hashchange'
var _on_hashchange_callback

func _ready() -> void:
	# Add in the missing bits of syntax highlighting for GDScript.
	for keyword in KEYWORDS:
		add_keyword_color(keyword, KEYWORD_COLOR)

	for keyword in CONTROL_FLOW_KEYWORDS:
		add_keyword_color(keyword, CONTROL_FLOW_KEYWORD_COLOR)

	for base_type in BASE_TYPES:
		add_keyword_color(base_type, BASE_TYPE_COLOR)

	for engine_type in ClassDB.get_class_list():
		add_keyword_color(engine_type, ENGINE_TYPE_COLOR)

	add_color_region('"', '"', STRING_COLOR, false)
	add_color_region("'", "'", STRING_COLOR, false)
	add_color_region("#", "", COMMENT_COLOR, false)

	# Generate printing functions.
	for print_func in PRINT_FUNCS:
		script_shim += print_func_template.format({
				name = print_func,
				separator = PRINT_FUNCS[print_func],
				end_separator = "" if print_func == "printraw" else "\\n",
		})

	# Load initial URL hash, if present.
	_try_load_url_hash_text()

	# Subscribe to URL hash changes.
	if OS.has_feature("JavaScript"):
		_on_hashchange_callback = JavaScript.create_callback(self, "_on_hashchange")
		JavaScript.get_interface("window").addEventListener("hashchange", _on_hashchange_callback)
	else:
		# Share button is only supported on HTML5, as it requires executing JavaScript code.
		$ShareButton.visible = false

func _run_button_pressed() -> void:
	# Clear the Output panel.
	output_panel.text = ""

	# Replace `print()` and similar functions with our own so that messages
	# can be displayed in the output panel.
	var script_text := text
	for func_replacement in FUNC_REPLACEMENTS:
		script_text = script_text.replace(
				func_replacement,
				FUNC_REPLACEMENTS[func_replacement]
		)

	# Append the script shim and load the script.
	script_text += script_shim
	var script := GDScript.new()
	script.source_code = script_text
	var error := script.reload()

	# Display an error message if the script parsing failed.
	error_label.text = "Parser error in the script (invalid syntax).\nCheck browser console for more information." if error != OK else ""

	if error == OK:
		var run_context: Object = script.new()
		# Instance the script so it can access the scene tree.
		# This also runs the script's `_init()` and `_ready()` functions.
		get_tree().get_root().add_child(run_context)
		# Clean up once the script is done running.
		run_context.queue_free()

func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_comment"):
		# If no selection is active, toggle comment on the line the cursor is currently on.
		var from := get_selection_from_line() if is_selection_active() else cursor_get_line()
		var to := get_selection_to_line() if is_selection_active() else cursor_get_line()
		for line in range(from, to + 1):
			if not get_line(line).begins_with("#"):
				# Code is already commented out at the beginning of the line. Uncomment it.
				set_line(line, "#%s" % get_line(line))
			else:
				# Code isn't commented out at the beginning of the line. Comment it.
				set_line(line, get_line(line).substr(1))


func _on_ShareButton_pressed() -> void:
	var newUrl = _set_url_hash_source(text)
	if newUrl != null:
		OS.clipboard = newUrl
		$ShareButton.text = "Copied!"
		$CopiedTimer.start()


func _on_CopiedTimer_timeout() -> void:
	$ShareButton.text = "Share"


func _try_load_url_hash_text() -> void:
	var query_gd = _get_url_hash_source()
	if query_gd != null:
		text = query_gd


func _on_hashchange(_event) -> void:
	print("Hash changed")
	_try_load_url_hash_text()


func _get_url_hash_source():
	var param = _get_url_hash()
	if param == null:
		print("No hash to load")
		return null

	print("Loading hash: #%s" % param)

	var base64 := _base64url_to_base64(param)
	var raw := Marshalls.base64_to_raw(base64)

	if raw.size() > 2 && raw[0] == 0x1F && raw[1] == 0x8B:
		raw = raw.decompress_dynamic(1024 * 1024, File.COMPRESSION_GZIP)

	return raw.get_string_from_utf8()


func _set_url_hash_source(source: String):
	var uncompressed := source.to_utf8()
	var compressed := uncompressed.compress(File.COMPRESSION_GZIP)
	var base64 = null

	if compressed.size() < uncompressed.size():
		base64 = Marshalls.raw_to_base64(compressed)
	else:
		base64 = Marshalls.raw_to_base64(uncompressed)

	var base64url := _base64_to_base64url(base64)
	return _set_url_hash(base64url)


func _base64url_to_base64(base64url: String) -> String:
	var base64 = base64url.replace("-", "+").replace("_", "/")
	if base64.length() % 4 != 0:
		base64 += "=".repeat(4 - base64.length() % 4)
	return base64


func _base64_to_base64url(base64: String) -> String:
	return base64.replace("+", "-").replace("/", "_").rstrip("=")


func _get_url_hash():
	if OS.has_feature("JavaScript"):
		var location = JavaScript.get_interface("location")
		if location.hash != "":
			return location.hash.substr(1)

	push_error("`_get_url_hash()` requires JavaScript code execution, which means it can only work in HTML5. Returning `null`.")
	return null


func _set_url_hash(value: String):
	if OS.has_feature("JavaScript"):
		var location = JavaScript.get_interface("location")
		print("Setting location.hash (\"%s\") = \"%s\"" % [location.hash, value])
		if ((location.hash != "" && location.hash.substr(1) != value) ||
			(location.hash == "" && value != "")):
				var history = JavaScript.get_interface("history")
				var url = JavaScript.create_object("URL", location)
				url.hash = value
				history.pushState(JavaScript.create_object("Object"), "", url)
				print("Navigated to: %s" % url.toString())
				return url.toString()

	push_error("`_set_url_hash()` requires JavaScript code execution, which means it can only work in HTML5. Returning `null`.")
	return null


func _on_ScriptEditor_text_changed() -> void:
	_set_url_hash("")
