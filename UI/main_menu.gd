extends Node2D

func _ready() -> void:
	SoundManager.music.set("parameters/switch_to_clip", &"menu")

## _input (not _unhandled_input) so this still fires even if the very first
## click lands right on a button — it doesn't mark the event handled, so the
## button's own click still goes through normally. The fullscreen check
## itself is what limits this to "on first load": once the window's already
## fullscreen, every later press here is just a no-op.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")


func _on_tutorial_pressed() -> void:
	get_tree().change_scene_to_file("res://tutorial.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
