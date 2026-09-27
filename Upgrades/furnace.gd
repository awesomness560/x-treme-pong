class_name UpgradeFurnace
extends Upgrade

## Stays alive, ticks while the ball is ignited, and resets its own partial
## progress every round alongside GameState.round_damage_bonus itself.
const ID := "furnace"
const DISPLAY_NAME := "Furnace"
const DESCRIPTION := "Every 3 seconds ignited, damage +20% for the round."
const CATEGORY := GameState.UPGRADE_CATAGORY.HEAT
const RARITY := GameState.UPGRADE_RARITY.RARE
const TAGS : Array[String] = ["ignition", "damage", "stack"]

const INTERVAL := 3.0
const BONUS_PER_INTERVAL := 0.2

var _elapsed := 0.0

func activate() -> void:
	GameState.spawn_encounter.connect(_on_new_round)

func _process(delta: float) -> void:
	if not GameState.ball_ignited:
		return
	_elapsed += delta
	while _elapsed >= INTERVAL:
		_elapsed -= INTERVAL
		GameState.round_damage_bonus += BONUS_PER_INTERVAL

func _on_new_round() -> void:
	_elapsed = 0.0
