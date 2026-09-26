extends Control

@export var restart: Button
@export var upgrades_you_have: GridContainer
@export var round_label: Label

@export var stat_total_damage: Label
@export var stat_biggest_hit : Label
@export var stat_smash: Label
@export var stat_ignitions: Label

func _ready() -> void:
	# Has to keep processing (and let its own button be clickable) while the
	# tree is paused below, or the restart button would be dead on arrival.
	process_mode = Node.PROCESS_MODE_ALWAYS
	#hide()
	GameState.game_over.connect(_on_game_over)

func _on_game_over() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if stat_total_damage:
		stat_total_damage.text = str(GameState.stat_damage_dealt)
	if stat_smash:
		stat_smash.text = str(GameState.stat_smashes)
	if stat_ignitions:
		stat_ignitions.text = str(GameState.stat_ignitions)
	get_tree().paused = true
	show()

func _on_restart_pressed() -> void:
	# round_manager.gd's own _ready() resets both autoloads right as the
	# reloaded scene starts up — no need to do it again here.
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	pass # Replace with function body.
