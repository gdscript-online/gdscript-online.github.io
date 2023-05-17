# Copyright © 2019-present Hugo Locurcio and contributors - MIT License
# See `LICENSE.md` included in the source distribution for details.
extends Control

onready var engine_version_label := $EngineVersion as Label


func _ready() -> void:
	var version := Engine.get_version_info()
	# Mimic the official version numbering.
	if version.patch >= 1:
		engine_version_label.text = "Godot %s.%s.%s.%s" % [version.major, version.minor, version.patch, version.status]
	else:
		engine_version_label.text = "Godot %s.%s.%s" % [version.major, version.minor, version.status]

	# Upscale everything if the display requires it (crude hiDPI support).
	# This prevents UI elements from being too small on hiDPI displays.
	if OS.get_screen_dpi() >= 192 and OS.get_screen_size().x >= 2048:
		get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_DISABLED, SceneTree.STRETCH_ASPECT_IGNORE, Vector2(), 2)
