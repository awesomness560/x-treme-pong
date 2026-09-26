class_name UpgradeScarTissue
extends Upgrade

## Stays alive and reacts to damage taken for the rest of the run. Replaces
## its own contribution each hit (subtract the old, add the new) instead of
## just adding more, so it always reflects the current hit count exactly.
const ID := "scar_tissue"
const DISPLAY_NAME := "Scar Tissue"
const DESCRIPTION := "Each point of HP you've lost this run adds +20% damage."
const CATEGORY := GameState.UPGRADE_CATAGORY.ENDURANCE
const RARITY := GameState.UPGRADE_RARITY.COMMON
const TAGS : Array[String] = ["health", "risk", "damage"]

const BONUS_PER_HIT := 0.2

var _hits_taken := 0
var _current_bonus := 0.0

func activate() -> void:
	GameState.player_damaged.connect(_on_player_damaged)

func _on_player_damaged() -> void:
	_hits_taken += 1
	GameState.damage_bonus -= _current_bonus
	_current_bonus = BONUS_PER_HIT * _hits_taken
	GameState.damage_bonus += _current_bonus
