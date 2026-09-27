class_name UpgradeApex
extends Upgrade

## Stays alive and reacts to every perfect for the rest of the run —
## permanent and ever-stacking, same shape as Ascendant.
const ID := "apex"
const DISPLAY_NAME := "Apex"
const DESCRIPTION := "Each perfect adds +20% damage for the rest of the run."
const CATEGORY := GameState.UPGRADE_CATAGORY.STRIKE
const RARITY := GameState.UPGRADE_RARITY.LEGENDARY
const TAGS : Array[String] = ["perfect", "damage", "stack"]

const BONUS_PER_PERFECT := 0.2

func activate() -> void:
	GameState.ball.paddle_hit.connect(_on_paddle_hit)

func _on_paddle_hit(paddle: Node2D) -> void:
	if paddle == GameState.player and GameState.last_hit_perfect:
		GameState.damage_bonus += BONUS_PER_PERFECT
