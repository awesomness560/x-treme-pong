extends Control

@export var upgrades_you_have: GridContainer
@export var background: ColorRect
@export var enemy_side: Control
@export var player_side: Control

@export_group("Timing")
## Background wipe half — matches the two shader_parameter tweens below.
@export var background_time : float = 0.3
@export var side_time : float = 0.3
## Delay before the enemy side starts sliding, after the player side starts.
@export var side_stagger : float = 0.08
## How far past its own edge each side panel starts/ends, so it isn't a hard
## pop-in right at the screen edge.
@export var side_offscreen_margin : float = 40.0

const UPGRADE_BADGE_SCENE := preload("res://UI/upgrade_badge.tscn")

var openState : bool = false

var _player_rest_x : float = 0.0
var _enemy_rest_x : float = 0.0
var _split_material : ShaderMaterial

var _bg_tween : Tween
var _side_tween : Tween

var prev_mouse_mode : Input.MouseMode

func _ready() -> void:
	# Tweens created from this script are bound to this node, so this also
	# keeps them (and, via inherit, background/player_side/enemy_side) alive
	# while get_tree().paused is true — otherwise the open/close animation
	# would freeze itself the instant it pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if background:
		_split_material = background.material
	if player_side:
		_player_rest_x = player_side.position.x
	if enemy_side:
		_enemy_rest_x = enemy_side.position.x
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
	show()
	get_tree().paused = true
	SoundManager.set_paused_duck(true)
	_refresh_upgrade_badges()

	if player_side:
		player_side.position.x = _player_rest_x - player_side.size.x - side_offscreen_margin
	if enemy_side:
		enemy_side.position.x = _enemy_rest_x + enemy_side.size.x + side_offscreen_margin

	if _split_material:
		_split_material.set_shader_parameter("top_x", 1.2)
		_split_material.set_shader_parameter("bottom_x", 1.1)
		if _bg_tween and _bg_tween.is_valid():
			_bg_tween.kill()
		_bg_tween = create_tween().set_parallel().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_bg_tween.tween_property(_split_material, "shader_parameter/top_x", 0.62, background_time)
		_bg_tween.tween_property(_split_material, "shader_parameter/bottom_x", 0.48, background_time)
		await _bg_tween.finished

	if _side_tween and _side_tween.is_valid():
		_side_tween.kill()
	_side_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if player_side:
		_side_tween.tween_property(player_side, "position:x", _player_rest_x, side_time)
	if enemy_side:
		_side_tween.tween_property(enemy_side, "position:x", _enemy_rest_x, side_time) \
			.set_delay(side_stagger)

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
	openState = false
	Input.mouse_mode = prev_mouse_mode
	SoundManager.set_paused_duck(false)

	if _side_tween and _side_tween.is_valid():
		_side_tween.kill()
	_side_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if player_side:
		_side_tween.tween_property(player_side, "position:x",
			_player_rest_x - player_side.size.x - side_offscreen_margin, side_time)
	if enemy_side:
		_side_tween.tween_property(enemy_side, "position:x",
			_enemy_rest_x + enemy_side.size.x + side_offscreen_margin, side_time) \
			.set_delay(side_stagger)
	await _side_tween.finished

	if _split_material:
		if _bg_tween and _bg_tween.is_valid():
			_bg_tween.kill()
		_bg_tween = create_tween().set_parallel().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		_bg_tween.tween_property(_split_material, "shader_parameter/top_x", 1.2, background_time)
		_bg_tween.tween_property(_split_material, "shader_parameter/bottom_x", 1.1, background_time)
		await _bg_tween.finished

	get_tree().paused = false
	hide()
