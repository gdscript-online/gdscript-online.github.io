# Copyright © 2019-2021 Hugo Locurcio and contributors - MIT License
# See `LICENSE.md` included in the source distribution for details.
extends TextEdit

signal incoming_word(word, line_text)
signal update_src(word)

onready var error_label: Label = $"../ErrorPanel/Label"
onready var output_panel: RichTextLabel = $"../../VBoxContainer2/OutputPanel/RichTextLabel"
var auto_completer:Autocompleter = Autocompleter.new()

# The printing functions to create
const PRINT_FUNCS = {
	"print": "", # Nothing between arguments, newline at end
	"prints": " ", # Space between arguments, newline at end
	"printt": "\\t", # Tab between arguments, newline at end
	"printraw": "", # Nothing between arguments, no newline at end
}

# Functions to replace in the script that will be run (see above)
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
const STRING_COLOR := Color(0.94, 0.43, 0.75)
# Slightly brighter than the default theme to improve readability.
const COMMENT_COLOR := Color(0.45, 0.45, 0.45)
const CLASS_COLOR := Color.aqua

# All reserved words in GDScript.
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
	# Control flow.
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

# Implement `print()` functions in the script for use with the output panel
# This must be done because built-in `print()` functions' output cannot be redirected
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
		output_panel = "$'/root/MainWindow/HSplitContainer/VBoxContainer2/OutputPanel/RichTextLabel'"
})

# The script shim that will be inserted at the end of the user-provided script
var script_shim := ""


func _ready() -> void:
	
	auto_completer.initialize(self)
	# Add in the missing bits of syntax highlighting for GDScript.
	for keyword in KEYWORDS:
		add_keyword_color(keyword, KEYWORD_COLOR)

	add_color_region('"', '"', STRING_COLOR, false)
	add_color_region("'", "'", STRING_COLOR, false)
	add_color_region("#", "", COMMENT_COLOR, false)

	# Generate printing functions
	for print_func in PRINT_FUNCS:
		script_shim += print_func_template.format({
				name = print_func,
				separator = PRINT_FUNCS[print_func],
				end_separator = "" if print_func == "printraw" else "\\n",
		})

func _run_button_pressed() -> void:
	# Clear the Output panel
	output_panel.text = ""

	# Replace `print()` and similar functions with our own so that messages
	# can be displayed in the output panel
	var script_text := text
	for func_replacement in FUNC_REPLACEMENTS:
		script_text = script_text.replace(
				func_replacement,
				FUNC_REPLACEMENTS[func_replacement]
		)

	# Append the script shim and load the script
	script_text += script_shim
	var script := GDScript.new()
	script.source_code = script_text
	auto_completer.search(text)
	var error := script.reload()

	# Display an error message if the script parsing failed
	error_label.text = "Script error" if error != OK else ""

	if error == OK:
		var run_context: Object = script.new()
		# Instance the script so it can access the scene tree.
		# This also runs the script's `_init()` and `_ready()` functions
		get_tree().get_root().add_child(run_context)
		# Clean up once the script is done running
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


func _on_ScriptEditor_request_completion() -> void:
	print("requested?")
	pass # Replace with function body.

func _on_ScriptEditor_text_changed() -> void:

	var line_text = get_line(cursor_get_line())
	var split = line_text.split(" ")
	var _current_word = split[-1]
	emit_signal("incoming_word",_current_word, get_line(cursor_get_line()))
	
	
	
	emit_signal("update_src", text)
	
	pass # Replace with function body.


func _on_ScriptEditor_cursor_changed() -> void:
	$CursorPos.rect_position = Vector2((8 * cursor_get_column()) + 43, (23 * cursor_get_line() ) + 23 )


func get_cursor_pos() -> Vector2:
	return $CursorPos.rect_position
