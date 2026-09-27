class_name UpgradeCriticalMass
extends Upgrade

## Stays alive and counts border hits for the current round only — resets
## on spawn_encounter, so the count never carries between rounds.
const ID := "critical_mass"
const DISPLAY_NAME := "Critical Mass"
const DESCRIPTION := "Every 5th border hit in a round detonates for 5x that hit's damage."
const CATEGORY := GameState.UPGRADE_CATAGORY.STRIKE
const RARITY := GameState.UPGRADE_RARITY.LEGENDARY
const TAGS : Array[String] = ["border", "damage", "trigger"]

const HIT_INTERVAL := 5
const DETONATE_MULTIPLIER := 5.0

var _hits_this_round := 0

func activate() -> void:
	GameState.ball.border_hit.connect(_on_border_hit)
	GameState.spawn_encounter.connect(_on_new_round)

func _on_border_hit(_border: Node2D, damage: float) -> void:
	_hits_this_round += 1
	if _hits_this_round % HIT_INTERVAL != 0:
		return
	# damage is already this hit's final amount (bonuses included) — top it
	# up to 5x with a plain burst instead of running it through deal_damage()
	# again, which would apply those same bonuses a second time.
	var bonus := damage * (DETONATE_MULTIPLIER - 1.0)
	GameState.deal_raw_damage(bonus)
	DamageNumbers.spawn(GameState.ball.global_position, bonus)

func _on_new_round() -> void:
	_hits_this_round = 0
