class_name UpgradeUnstableCombo
extends Upgrade

## Stays alive and reacts to ignition for the rest of the run, rather than
## doing a one-shot stat change on pick. Proves out that pathway.
const ID := "unstable_combo"
const DISPLAY_NAME := "Unstable Combo"
const DESCRIPTION := "Ignition boosts your combo multiplier while it lasts."
const CATEGORY := GameState.UPGRADE_CATAGORY.HEAT
const RARITY := GameState.UPGRADE_RARITY.LEGENDARY

const BOOST := 0.5

func activate() -> void:
	GameState.ball.ignited_changed.connect(_on_ignited_changed)

func _on_ignited_changed(ignited: bool) -> void:
	GameState.combo_multiplier += BOOST if ignited else -BOOST
