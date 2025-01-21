# Copyright © 2019-present Hugo Locurcio and contributors - MIT License
# See `LICENSE.md` included in the source distribution for details.
extends TextEdit

# Syntax highlighting colors are taken from the "Godot 2" script editor theme.
# https://github.com/godotengine/godot/blob/1b7b009674e05b566be11a5377b935f5d3d6c0ee/editor/editor_settings.cpp#L1043-L1083

@onready var error_label: Label = $"../../OutputPanel/ErrorLabel"
@onready var output_panel: RichTextLabel = $"../../OutputPanel/RichTextLabel"

# The printing functions to create.
const PRINT_FUNCS = {
	"print": "", # Nothing between arguments, newline at end.
	"print_rich": "", # Nothing between arguments, newline at end.
	"prints": " ", # Space between arguments, newline at end.
	"printt": "\\t", # Tab between arguments, newline at end.
	"printraw": "", # Nothing between arguments, no newline at end.
}

# Functions to replace in the script that will be run (see above).
const FUNC_REPLACEMENTS = {
	"print(": "self.print(",
	"print (": "self.print (",
	"print_rich(": "self.print_rich(",
	"print_rich (": "self.print_rich (",
	"prints(": "self.prints(",
	"prints (": "self.prints (",
	"printt(": "self.printt(",
	"printt (": "self.prints (",
	"printraw(": "self.printraw(",
	"printraw (": "self.printraw (",
}

# Implement `print()` functions in the script for use with the output panel.
# This must be done because built-in `print()` functions' output cannot be redirected.
var print_func_template := """
func {name}(arg1: Variant = '', arg2: Variant = '', arg3: Variant = '', arg4: Variant = '', arg5: Variant = '', arg6: Variant = '', arg7: Variant = '', arg8: Variant = '', arg9: Variant = '') -> void:
	# Also call the built-in printing function.
	{name}(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)

	var text := ''
	for argument: Variant in [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9]:
		text += str(argument) + '{separator}'

	text += '{end_separator}'

	if {escape_bbcode}:
		text = text.replace("[", "[lb]")

	{output_panel}.append_text(text)
""".format({
		output_panel = "$'/root/MainWindow/HSplitContainer/OutputPanel/RichTextLabel'"
})

# The script shim that will be inserted at the end of the user-provided script.
var script_shim := ""

# JavaScript event callback for 'hashchange'
var _on_hashchange_callback: JavaScriptObject


func _ready() -> void:
	# Run this in `@tool` mode to update the list of keyword colors:
	#for engine_type in ClassDB.get_class_list():
	#	syntax_highlighter.keyword_colors[engine_type] = Color(0.51, 0.83, 1)

	# Generate printing functions.
	for print_func: String in PRINT_FUNCS:
		script_shim += print_func_template.format({
				name = print_func,
				separator = PRINT_FUNCS[print_func],
				end_separator = "" if print_func == "printraw" else "\\n",
				escape_bbcode = "true" if print_func != "print_rich" else "false",
		})

	# Load initial URL hash, if present.
	_try_load_url_hash_text()

	# Subscribe to URL hash changes.
	if OS.has_feature("web"):
		_on_hashchange_callback = JavaScriptBridge.create_callback(_on_hashchange)
		JavaScriptBridge.get_interface("window").addEventListener("hashchange", _on_hashchange_callback)
	else:
		# Share button is only supported on the web platform, as it requires executing JavaScript code.
		$ShareButton.disabled = true
		$ShareButton.tooltip_text = "Not available outside the web platform."


func _run_button_pressed() -> void:
	output_panel.clear()

	# Replace `print()` and similar functions with our own so that messages
	# can be displayed in the output panel.
	var script_text := text
	for func_replacement: String in FUNC_REPLACEMENTS:
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
		var from := get_selection_from_line() if has_selection() else get_caret_line()
		var to := get_selection_to_line() if has_selection() else get_caret_line()
		for line in range(from, to + 1):
			if not get_line(line).begins_with("#"):
				# Code isn't commented out at the beginning of the line. Comment it.
				set_line(line, "#%s" % get_line(line))
			else:
				# Code is already commented out at the beginning of the line. Uncomment it.
				set_line(line, get_line(line).substr(1))

		accept_event()

	if event.is_action_pressed("deindent"):
		# If no selection is active, toggle comment on the line the cursor is currently on.
		var from := get_selection_from_line() if has_selection() else get_caret_line()
		var to := get_selection_to_line() if has_selection() else get_caret_line()
		for line in range(from, to + 1):
			if get_line(line).begins_with("\t"):
				# Remove first tab on the line.
				set_line(line, get_line(line).substr(1))

		accept_event()


func _on_ShareButton_pressed() -> void:
	var new_url: Variant = _set_url_hash_source(text)
	if new_url != null:
		DisplayServer.clipboard_set(new_url)
		$ShareButton.text = "Copied!"
		$CopiedTimer.start()


func _on_CopiedTimer_timeout() -> void:
	$ShareButton.text = "Share"


func _try_load_url_hash_text() -> void:
	var query_gd: Variant = _get_url_hash_source()
	if query_gd != null:
		text = query_gd


func _on_hashchange(_event: JavaScriptObject) -> void:
	_try_load_url_hash_text()


func _get_url_hash_source() -> Variant:
	var param: Variant = _get_url_hash()
	if param == null:
		print("No hash to load")
		return null

	var base64 := _base64url_to_base64(param)
	var raw := Marshalls.base64_to_raw(base64)

	if raw.size() > 2 && raw[0] == 0x1F && raw[1] == 0x8B:
		raw = raw.decompress_dynamic(1024 * 1024, FileAccess.COMPRESSION_GZIP)

	return raw.get_string_from_utf8()


func _set_url_hash_source(source: String) -> Variant:
	var uncompressed := source.to_utf8_buffer()
	var compressed := uncompressed.compress(FileAccess.COMPRESSION_GZIP)
	var base64 := ""

	if compressed.size() < uncompressed.size():
		base64 = Marshalls.raw_to_base64(compressed)
	else:
		base64 = Marshalls.raw_to_base64(uncompressed)

	var base64url := _base64_to_base64url(base64)

	return _set_url_hash(base64url)


func _base64url_to_base64(base64url: String) -> String:
	var base64 := base64url.replace("-", "+").replace("_", "/")
	if base64.length() % 4 != 0:
		base64 += "=".repeat(4 - base64.length() % 4)

	return base64


func _base64_to_base64url(base64: String) -> String:
	return base64.replace("+", "-").replace("/", "_").rstrip("=")


func _get_url_hash() -> Variant:
	if OS.has_feature("web"):
		var location := JavaScriptBridge.get_interface("location")
		if location.hash != "":
			return location.hash.substr(1)

		return null
	else:
		push_warning("`_get_url_hash()` requires JavaScript code execution, which means it can only work on the web platform. Returning `null`.")
		return null


func _set_url_hash(value: String) -> Variant:
	if OS.has_feature("web"):
		var location := JavaScriptBridge.get_interface("location")
		if (location.hash != "" and location.hash.substr(1) != value) or (location.hash == "" and value != ""):
				var history := JavaScriptBridge.get_interface("history")
				var url: Variant = JavaScriptBridge.create_object("URL", location)
				url.hash = value
				history.pushState(JavaScriptBridge.create_object("Object"), "", url)
				return url.toString()

		return null
	else:
		push_warning("`_set_url_hash()` requires JavaScript code execution, which means it can only work on the web platform. Returning `null`.")
		return null


func _on_ScriptEditor_text_changed() -> void:
	_set_url_hash("")
