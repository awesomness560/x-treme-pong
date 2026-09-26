extends Control

@export var upgrades_you_have: GridContainer
@export var round_label: Label

const UPGRADE_BADGE_SCENE := preload("res://UI/upgrade_badge.tscn")

var openState : bool = false
var prev_mouse_mode : Input.MouseMode

func _ready() -> void:
	# Has to keep processing input while the tree is paused below, or
	# pressing escape again to close it would never be seen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if openState:
			_close()
		else:
			_open()
		get_viewport().set_input_as_handled()

func _open() -> void:
	prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	openState = true
	get_tree().paused = true
	_refresh_upgrade_badges()
	if round_label:
		round_label.text = "Round %d" % GameState.current_round
	show()

## Rebuilds the badge row from scratch each open — cheap, and keeps it from
## ever drifting out of sync with Upgrades.taken (e.g. an upgrade picked
## since the last time the menu was open).
func _refresh_upgrade_badges() -> void:
	if upgrades_you_have == null:
		return
	for child in upgrades_you_have.get_children():
		child.queue_free()
	for script in Upgrades.taken:
		var badge := UPGRADE_BADGE_SCENE.instantiate()
		upgrades_you_have.add_child(badge)
		badge.setup(script)

func _close() -> void:
	Input.mouse_mode = prev_mouse_mode
	openState = false
	get_tree().paused = false
	hide()


func _on_resume_pressed() -> void:
	_close()

func _on_restart_pressed() -> void:
	# round_manager.gd's own _ready() resets both autoloads right as the
	# reloaded scene starts up — no need to do it again here.
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	# No main menu scene exists yet (project.godot's run/main_scene is the
	# gameplay scene itself) — nothing to switch to until one's built.
	pass
