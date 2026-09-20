extends Camera2D

@export var max_offset: Vector2 = Vector2(50, 50) # The maximum distance it can snap in pixels
@export var max_roll: float = 0.1 # Maximum rotation in radians
@export var decay_rate: float = 5.0 # How quickly the shake snaps back to zero (higher = snappier)

var shake_strength: float = 0.0

func _ready() -> void:
	# Connect to your existing Events Singleton
	GameState.camera_shook.connect(add_impact)
	#await get_tree().create_timer(1).timeout  
	#GameState.camera_shook.emit(0.2)

func _process(delta: float) -> void:
	if shake_strength > 0.0:
		# Quickly decay the shake strength to 0 over time
		shake_strength = move_toward(shake_strength, 0.0, decay_rate * delta)
		
		# Apply pure random offsets every frame for a jagged, violent feel
		offset.x = randf_range(-max_offset.x, max_offset.x) * shake_strength
		offset.y = randf_range(-max_offset.y, max_offset.y) * shake_strength
		rotation = randf_range(-max_roll, max_roll) * shake_strength
		
	elif offset != Vector2.ZERO or rotation != 0.0:
		# Snap perfectly back to center when the shake finishes
		offset = Vector2.ZERO
		rotation = 0.0

func add_impact(intensity: float) -> void:
	# Intensity should usually be between 0.1 and 1.0. 
	# We add it so multiple quick impacts stack and get crazier.
	shake_strength = clamp(shake_strength + intensity, 0.0, 2.0)
