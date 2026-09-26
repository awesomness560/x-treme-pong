extends Control

@export var restart: Button
@export var upgrades_you_have: GridContainer
@export var round_label: Label

@export var stat_total_damage: Label
@export var stat_biggest_hit : Label
@export var stat_smash: Label
@export var stat_ignitions: Label

const UPGRADE_BADGE_SCENE := preload("res://UI/upgrade_badge.tscn")

func _ready() -> void:
	# Has to keep processing (and let its own button be clickable) while the
	# tree is paused below, or the restart button would be dead on arrival.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	GameState.game_over.connect(_on_game_over)

func _on_game_over() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if round_label:
		round_label.text = "Round " + str(GameState.current_round)
	if stat_total_damage:
		stat_total_damage.text = "%.0f" % GameState.stat_damage_dealt
	if stat_biggest_hit:
		stat_biggest_hit.text = "%.0f" % GameState.stat_biggest_hit
	if stat_smash:
		stat_smash.text = str(GameState.stat_smashes)
	if stat_ignitions:
		stat_ignitions.text = str(GameState.stat_ignitions)

	_refresh_upgrade_badges()

	get_tree().paused = true
	show()

## Same pattern as the pause menu's badge row: rebuild from Upgrades.taken.
func _refresh_upgrade_badges() -> void:
	if upgrades_you_have == null:
		return
	for child in upgrades_you_have.get_children():
		child.queue_free()
	for script in Upgrades.taken:
		var badge := UPGRADE_BADGE_SCENE.instantiate()
		upgrades_you_have.add_child(badge)
		badge.setup(script)

func _on_restart_pressed() -> void:
	# round_manager.gd's own _ready() resets both autoloads right as the
	# reloaded scene starts up — no need to do it again here.
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	# No main menu scene exists yet (project.godot's run/main_scene is the
	# gameplay scene itself) — nothing to switch to until one's built.
	pass
