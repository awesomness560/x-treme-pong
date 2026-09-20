class_name UltCharge
extends Node

## Full bar, in charge points. Higher = slower to fill.
@export var max_charge: float = 100.0

@export_group("Awards (points)")
@export var smash_low: float = 3.0
@export var smash_high: float = 8.0
@export var perfect_high: float = 15.0
@export var ignited_perfect: float = 20.0
@export var ignition_trigger: float = 15.0
@export var border_min: float = 10.0
@export var border_max: float = 20.0
## Border damage that awards border_max. Below this it scales down.
@export var border_damage_for_max: float = 3.0
@export var damage_taken: float = 10.0

@export_group("Ignition Drip")
## Points per second while the ball is lit.
@export var ignited_rate: float = 6.0

@export_group("Overkill Refund")
## Fraction of overkill damage converted back to charge.
@export_range(0.0, 1.0) var refund_fraction: float = 0.5
## Cap on a single refund, as a fraction of a full bar.
@export_range(0.0, 1.0) var refund_cap: float = 0.4

@export_group("Feel")
## Speed ratio at or above which a smash counts as "high".
@export_range(0.0, 1.0) var high_speed_ratio: float = 0.5
## Seconds of smoothing on the rate readout.
@export var rate_smoothing: float = 0.2

var charge := 0.0 # In points.

var _rate_accum := 0.0
var _smoothed_rate := 0.0

func _ready() -> void:
	var ball := GameState.ball
	GameState.ult_charge_manager = self
	ball.paddle_hit.connect(_on_paddle_hit)
	ball.border_hit.connect(_on_border_hit)
	ball.ignited_changed.connect(_on_ignited_changed)
	_push()

func _process(delta: float) -> void:
	# Ignition drips charge continuously.
	if GameState.ball_ignited and not GameState.ult_armed:
		_award(ignited_rate * delta, GameState.GainKind.IGNITION, false)

	# Smoothed rate, so the bar's spark reacts to spikes and drips alike.
	var instant := _rate_accum / maxf(delta, 0.0001)
	_rate_accum = 0.0
	var t := 1.0 - exp(-delta / maxf(rate_smoothing, 0.001))
	_smoothed_rate = lerpf(_smoothed_rate, instant, t)
	GameState.ult_rate = _smoothed_rate / max_charge

# --- Award rules ---

func _on_paddle_hit(paddle: Node2D) -> void:
	if paddle != GameState.player:
		return
	if not GameState.last_hit_was_smash:
		return

	var hot := GameState.ball.get_speed_ratio() >= high_speed_ratio
	var amount: float
	if GameState.last_hit_perfect:
		amount = ignited_perfect if GameState.ball_ignited else (perfect_high if hot else smash_high)
	else:
		amount = smash_high if hot else smash_low

	_award(amount, GameState.GainKind.SMASH)

func _on_border_hit(_border: Node2D, damage: float) -> void:
	var t := clampf(damage / maxf(border_damage_for_max, 0.001), 0.0, 1.0)
	_award(lerpf(border_min, border_max, t), GameState.GainKind.BORDER)

func _on_ignited_changed(ignited: bool) -> void:
	if ignited:
		_award(ignition_trigger, GameState.GainKind.IGNITION)

## Call this when the player loses health.
func on_player_damaged(_amount: float = 1.0) -> void:
	_award(damage_taken, GameState.GainKind.DAMAGE_TAKEN)

## Call this when a boss dies with damage to spare.
func on_overkill(overkill_damage: float) -> void:
	var refund := overkill_damage * refund_fraction
	_award(minf(refund, max_charge * refund_cap), GameState.GainKind.REFUND)

# --- Spending ---

## Fires the ult's cost. Returns false if not armed.
func spend() -> bool:
	if not GameState.ult_armed:
		return false
	charge = 0.0
	GameState.ult_armed = false
	GameState.ult_armed_changed.emit(false)
	GameState.ult_spent.emit()
	_push()
	return true

# --- Internals ---

func _award(amount: float, kind: GameState.GainKind, announce: bool = true) -> void:
	if amount <= 0.0 or GameState.ult_armed:
		return # Overflow while armed is wasted: fire it.

	var before := charge
	charge = minf(charge + amount, max_charge)
	var gained := charge - before
	if gained <= 0.0:
		return

	_rate_accum += gained
	_push()

	if announce:
		GameState.ult_gained.emit(gained / max_charge, kind)

	if charge >= max_charge:
		GameState.ult_armed = true
		GameState.ult_armed_changed.emit(true)

func _push() -> void:
	GameState.ult_charge = charge / max_charge
