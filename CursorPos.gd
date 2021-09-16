extends Control


# the auto completer input must be called from here
# because its called before ScriptEditor input events
# then we can disable and enable the cursor from move
func _input(event: InputEvent) -> void:
	get_parent().auto_completer.input(event)
	
