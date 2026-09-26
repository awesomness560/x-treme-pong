class_name UpgradeAscendant
extends Upgrade

## Stays alive and reacts to every ult cast for the rest of the run —
## permanent and ever-stacking, so no divide-out needed like the toggles.
const ID := "ascendant"
const DISPLAY_NAME := "Ascendant"
const DESCRIPTION := "Every ultimate you fire permanently adds +25% damage for the run."
const CATEGORY := GameState.UPGRADE_CATAGORY.ULTIMATE
const RARITY := GameState.UPGRADE_RARITY.LEGENDARY
const TAGS : Array[String] = ["ultimate", "damage"]

const BONUS_PER_CAST := 0.25

func activate() -> void:
	GameState.ult_spent.connect(_on_ult_spent)

func _on_ult_spent() -> void:
	GameState.damage_bonus += BONUS_PER_CAST
