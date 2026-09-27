class_name UpgradeVeteran
extends Upgrade

## Stays alive and reacts to every perfect for the rest of the run —
## permanent and ever-stacking, same shape as Ascendant/Apex. Small per-hit
## bonus, but nothing here has ever capped this kind of stack.
const ID := "veteran"
const DISPLAY_NAME := "Veteran"
const DESCRIPTION := "Each perfect adds +3% damage for the run, with no cap."
const CATEGORY := GameState.UPGRADE_CATAGORY.STRIKE
const RARITY := GameState.UPGRADE_RARITY.RARE
const TAGS : Array[String] = ["perfect", "damage", "stack"]

const BONUS_PER_PERFECT := 0.03

func activate() -> void:
	GameState.ball.paddle_hit.connect(_on_paddle_hit)

func _on_paddle_hit(paddle: Node2D) -> void:
	if paddle == GameState.player and GameState.last_hit_perfect:
		GameState.damage_bonus += BONUS_PER_PERFECT
