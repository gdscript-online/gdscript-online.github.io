# Copyright © 2019-present Hugo Locurcio and contributors - MIT License
# See `LICENSE.md` included in the source distribution for details.
extends Button


# The shortcut has to be implemented manually, so that it can block input in the
# text editor. Otherwise, a line break would be inserted and the shortcut
# wouldn't be triggered.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("run_script"):
		emit_signal("pressed")
		accept_event()
