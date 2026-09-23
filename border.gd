extends StaticBody2D
class_name Border

@export var starting_health : float = 10
@export var crack_ease_time: float = 0.25
@export var shatter_time: float = 0.7
@export var flash_decay: float = 0.3
@export var visuals : ColorRect

@export_group("Boss Colors")
@export var fire_body_color : Color = Color(0.16, 0.05, 0.04)
@export var fire_crack_color : Color = Color(1.3, 0.4, 0.1)
@export var fire_edge_color : Color = Color(1.3, 0.45, 0.15)
@export var earth_body_color : Color = Color(0.08, 0.1, 0.05)
@export var earth_crack_color : Color = Color(0.55, 0.85, 0.2)
@export var earth_edge_color : Color = Color(0.6, 0.9, 0.25)
@export var water_body_color : Color = Color(0.04, 0.08, 0.16)
@export var water_crack_color : Color = Color(0.25, 0.7, 1.3)
@export var water_edge_color : Color = Color(0.3, 0.75, 1.3)

var health : float

## Set the instant health first drops to 0, so no further hit can restart
## the shatter tween or re-fire boss_dead while this one is still dying.
var _dying := false

var _damage := 0.0
var _shatter := 0.0
var _flash := 0.0
var _tween: Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameState.border = self
	health = starting_health
	GameState.take_damage.connect(_take_damage)
	GameState.boss_type_changed.connect(_apply_boss_color)
	_apply_boss_color(GameState.boss_type)
	# Announce full health so the health bar actually refills — otherwise it
	# just sits wherever the last boss left it until this one takes a hit.
	GameState.boss_new_health.emit(health / starting_health)

func _apply_boss_color(type: GameState.BossType) -> void:
	var mat := visuals.material as ShaderMaterial
	if mat == null:
		return
	match type:
		GameState.BossType.FIRE:
			mat.set_shader_parameter("body_color", fire_body_color)
			mat.set_shader_parameter("crack_color", fire_crack_color)
			mat.set_shader_parameter("edge_color", fire_edge_color)
		GameState.BossType.EARTH:
			mat.set_shader_parameter("body_color", earth_body_color)
			mat.set_shader_parameter("crack_color", earth_crack_color)
			mat.set_shader_parameter("edge_color", earth_edge_color)
		GameState.BossType.WATER:
			mat.set_shader_parameter("body_color", water_body_color)
			mat.set_shader_parameter("crack_color", water_crack_color)
			mat.set_shader_parameter("edge_color", water_edge_color)

func _take_damage(amount : float):
	if _dying:
		return
	health -= amount
	if health <= 0.0:
		_dying = true
		GameState.boss_dead.emit()
	##Death check
	GameState.boss_new_health.emit(health / starting_health)
	_on_hit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_push()

func _on_hit() -> void:
	# Flash from where the ball is
	var local := (GameState.ball.global_position - global_position) / visuals.size
	_flash = 1.0

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_damage", 1.0 - health / starting_health, crack_ease_time)
	_tween.parallel().tween_property(self, "_flash", 0.0, flash_decay) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	if health <= 0.0:
		SoundManager.glass_shatter.play()
		_tween.tween_property(self, "_shatter", 1.0, shatter_time) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		await _tween.finished
		queue_free()

	SoundManager.glass_crack.play()
	_set_hit_point(local)

func _set_hit_point(local: Vector2) -> void:
	var mat := visuals.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("hit_point", local.clamp(Vector2.ZERO, Vector2.ONE))

func _push() -> void:
	var mat := visuals.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("damage", _damage)
	mat.set_shader_parameter("shatter", _shatter)
	mat.set_shader_parameter("hit_flash", _flash)
