class_name UpgradeKindred
extends Upgrade

## Stays alive and reacts to every perfect for the rest of the run, rather
## than doing a one-shot stat change on pick.
const ID := "kindred"
const DISPLAY_NAME := "Kindred"
const DESCRIPTION := "Perfect smashes grant 20% meter."
const CATEGORY := GameState.UPGRADE_CATAGORY.ULTIMATE
const RARITY := GameState.UPGRADE_RARITY.RARE
const TAGS : Array[String] = ["perfect", "ultimate", "trigger"]

const METER_FRACTION := 0.2

func activate() -> void:
	GameState.ball.paddle_hit.connect(_on_paddle_hit)

func _on_paddle_hit(paddle: Node2D) -> void:
	if paddle == GameState.player and GameState.last_hit_perfect:
		GameState.ult_charge_manager.award_fraction(METER_FRACTION)
