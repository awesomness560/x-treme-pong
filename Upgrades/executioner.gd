class_name UpgradeExecutioner
extends Upgrade

## Stays alive and reacts to boss health for the rest of the run, toggling
## its own additive contribution in and out — same technique as Fever,
## just keyed on boss_new_health instead of player health.
const ID := "executioner"
const DISPLAY_NAME := "Executioner"
const DESCRIPTION := "Damage +250% against a border below 40%."
const CATEGORY := GameState.UPGRADE_CATAGORY.STRIKE
const RARITY := GameState.UPGRADE_RARITY.LEGENDARY
const TAGS : Array[String] = ["damage", "border"]

const BONUS := 2.5 # +250%
const THRESHOLD := 0.4

var _active := false

func activate() -> void:
	GameState.boss_new_health.connect(_on_boss_health_changed)

func _on_boss_health_changed(ratio: float) -> void:
	var should_be_active := ratio < THRESHOLD
	if should_be_active == _active:
		return
	_active = should_be_active
	if _active:
		GameState.damage_bonus += BONUS
	else:
		GameState.damage_bonus -= BONUS
