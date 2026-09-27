class_name UpgradeHarvest
extends Upgrade

## Stays alive and reacts to ignition for the rest of the run, rather than
## doing a one-shot stat change on pick — same shape as Stoke.
const ID := "harvest"
const DISPLAY_NAME := "Harvest"
const DESCRIPTION := "Each ignition grants 30% meter."
const CATEGORY := GameState.UPGRADE_CATAGORY.ULTIMATE
const RARITY := GameState.UPGRADE_RARITY.RARE
const TAGS : Array[String] = ["ignition", "ultimate", "trigger"]

const METER_FRACTION := 0.3

func activate() -> void:
	GameState.ball.ignited_changed.connect(_on_ignited_changed)

func _on_ignited_changed(ignited: bool) -> void:
	if ignited:
		GameState.ult_charge_manager.award_fraction(METER_FRACTION)
