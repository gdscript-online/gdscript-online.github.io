# Copyright © 2019 Hugo Locurcio and contributors - MIT License
# See `LICENSE.md` included in the source distribution for details.

extends TextEdit

onready var error_label: Label = $"../ErrorPanel/Label"
onready var output_panel: RichTextLabel = $"../../OutputPanel/RichTextLabel"

# The printing functions to create
const print_funcs = {
	"print": "", # Nothing between arguments, newline at end
	"prints": " ", # Space between arguments, newline at end
	"printt": "\\t", # Tab between arguments, newline at end
	"printraw": "", # Nothing between arguments, no newline at end
}

# Functions to replace in the script that will be run (see above)
const func_replacements = {
	"print(": "self.print(",
	"print (": "self.print (",
	"prints(": "self.prints(",
	"prints (": "self.prints (",
	"printt(": "self.printt(",
	"printt (": "self.prints (",
	"printraw(": "self.printraw(",
	"printraw (": "self.printraw (",
}

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
		output_panel = "$'/root/MainWindow/HSplitContainer/OutputPanel/RichTextLabel'"
})

# The script shim that will be inserted at the end of the user-provided script
var script_shim := ""

func _ready() -> void:
	# Generate printing functions
	for print_func in print_funcs:
		script_shim += print_func_template.format({
				name = print_func,
				separator = print_funcs[print_func],
				end_separator = "" if print_func == "printraw" else "\\n",
		})

func _run_button_pressed() -> void:
	# Clear the Output panel
	output_panel.text = ""

	# Replace `print()` and similar functions with our own so that messages
	# can be displayed in the output panel
	var script_text := text
	for func_replacement in func_replacements:
		script_text = script_text.replace(
				func_replacement,
				func_replacements[func_replacement]
		)

	# Append the script shim and load the script
	script_text += script_shim
	var script := GDScript.new()
	script.source_code = script_text
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
