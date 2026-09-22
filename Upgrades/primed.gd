class_name UpgradePrimed
extends Upgrade

## Stays alive and reacts to next_round for the rest of the run, rather than
## doing a one-shot stat change on pick.
const ID := "primed"
const DISPLAY_NAME := "Primed"
const DESCRIPTION := "Start every round with your ultimate armed."
const CATEGORY := GameState.UPGRADE_CATAGORY.ULTIMATE
const RARITY := GameState.UPGRADE_RARITY.LEGENDARY
const TAGS : Array[String] = ["ultimate"]

func activate() -> void:
	GameState.next_round.connect(_arm)

func _arm() -> void:
	GameState.ult_charge_manager.arm()
