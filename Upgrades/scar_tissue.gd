class_name UpgradeScarTissue
extends Upgrade

## Stays alive and reacts to damage taken for the rest of the run. Reads
## GameState.hp_lost_this_run directly rather than counting its own hits, so
## HP lost before this was even picked up still counts. Replaces its own
## contribution each time (subtract the old, add the new) instead of just
## adding more, so it always reflects the current total exactly.
const ID := "scar_tissue"
const DISPLAY_NAME := "Scar Tissue"
const DESCRIPTION := "Each point of HP you've lost this run adds +30% damage."
const CATEGORY := GameState.UPGRADE_CATAGORY.ENDURANCE
const RARITY := GameState.UPGRADE_RARITY.COMMON
const TAGS : Array[String] = ["health", "risk", "damage"]

const BONUS_PER_HIT := 0.3

var _current_bonus := 0.0

func activate() -> void:
	GameState.player_damaged.connect(_recompute)
	# Credit whatever HP was already lost this run before this was picked up.
	_recompute()

func _recompute() -> void:
	GameState.damage_bonus -= _current_bonus
	_current_bonus = BONUS_PER_HIT * GameState.hp_lost_this_run
	GameState.damage_bonus += _current_bonus
