extends Node2D

func _ready() -> void:
	SoundManager.music.set("parameters/switch_to_clip", &"menu")

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")


func _on_tutorial_pressed() -> void:
	get_tree().change_scene_to_file("res://tutorial.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
