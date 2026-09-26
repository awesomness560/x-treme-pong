class_name UpgradeFever
extends Upgrade

## Stays alive and reacts to health for the rest of the run, toggling its
## own additive contribution in and out so it stacks safely (adding, not
## compounding) with anything else touching GameState.damage_bonus (e.g.
## Glass Cannon).
const ID := "fever"
const DISPLAY_NAME := "Fever"
const DESCRIPTION := "At 1 HP, damage +150%."
const CATEGORY := GameState.UPGRADE_CATAGORY.ENDURANCE
const RARITY := GameState.UPGRADE_RARITY.RARE
const TAGS : Array[String] = ["risk", "health", "damage"]

const BONUS := 1.5 # +150%

var _active := false

func activate() -> void:
	GameState.player_health_changed.connect(_on_health_changed)
	_on_health_changed()

func _on_health_changed() -> void:
	var should_be_active : bool = true if GameState.player_health == 1 else false
	if should_be_active == _active:
		return
	_active = should_be_active
	if _active:
		GameState.damage_bonus += BONUS
	else:
		GameState.damage_bonus -= BONUS
