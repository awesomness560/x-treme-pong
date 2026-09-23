extends Node

## Each upgrade's rarity sets its baseline weight — see offer_weight() below
## for how tag affinity multiplies on top of this. No tier is guaranteed;
## rarity is just one factor in a single flat weighted pick now.
const RARITY_WEIGHTS := {
	GameState.UPGRADE_RARITY.COMMON: 0.40,
	GameState.UPGRADE_RARITY.RARE: 0.40,
	GameState.UPGRADE_RARITY.LEGENDARY: 0.20,
}

## Extra weight multiplier per tag an offer shares with tags already owned —
## e.g. 2 shared tags -> weight x(1 + 2 * this).
const TAG_AFFINITY_BONUS := 0.75

## Every upgrade that can be rolled. Heal is deliberately not here — the UI
## spawns it directly instead of drawing it from the pool.
const CATALOG : Array[Script] = [
	preload("res://Upgrades/kindle.gd"),
	preload("res://Upgrades/momentum.gd"),
	preload("res://Upgrades/ricochet.gd"),
	preload("res://Upgrades/combustion.gd"),
	preload("res://Upgrades/wide_swing.gd"),
	preload("res://Upgrades/glass_cannon.gd"),
	preload("res://Upgrades/pierce.gd"),
	preload("res://Upgrades/tough.gd"),
	preload("res://Upgrades/fever.gd"),
	preload("res://Upgrades/last_stand.gd"),
	preload("res://Upgrades/refund.gd"),
	preload("res://Upgrades/primed.gd"),
]

const HEAL_SCRIPT : Script = preload("res://Upgrades/heal.gd")

@export_group("Testing")
## Forces this upgrade into the first slot of every roll (as long as it's
## still in the pool), so you can pick it deliberately and verify it works.
## The rest of the offer still rolls normally. Leave null for normal play.
@export var force_upgrade : Script

var _pool : Array[Script] = []

## Every non-heal upgrade taken so far, in pick order. Whatever wants to
## remind the player what they have (the pause menu's badge row, etc.) just
## reads this straight — a Script already carries everything upgrade_badge
## needs (DISPLAY_NAME/CATEGORY/RARITY), so no separate struct is needed.
var taken : Array[Script] = []

## Every tag carried by an upgrade already taken. offer_weight() reads this
## to bias future rolls toward whatever tags the player's already leaning on.
var owned_tags : Dictionary = {}

func _ready() -> void:
	_pool = CATALOG.duplicate()

## Called by the restart button before reloading the scene. Committed
## upgrade instances are children of this autoload, not the scene tree, so
## a scene reload alone would leave them behind — still connected to
## whatever they hooked, still around to react to the new run.
func reset_run() -> void:
	for child in get_children():
		child.queue_free()
	_pool = CATALOG.duplicate()
	taken.clear()
	owned_tags.clear()

## Rolls up to `count` distinct upgrades from the remaining pool. Upgrades
## offered but not picked aren't removed here — only commit() does that.
func roll(count: int) -> Array[Script]:
	var picks : Array[Script] = []
	var available := _pool.duplicate()

	if force_upgrade != null and available.has(force_upgrade):
		picks.append(force_upgrade)
		available.erase(force_upgrade)
		count -= 1

	for i in count:
		if available.is_empty():
			break
		var script := _weighted_pick_script(available)
		if script == null:
			break
		picks.append(script)
		available.erase(script)

	return picks

## Rarity sets the baseline; each tag this upgrade shares with owned_tags
## multiplies it further, so a build already leaning into a tag keeps
## drawing more of it.
func offer_weight(script: Script) -> float:
	var w : float = RARITY_WEIGHTS.get(script.RARITY, 0.0)
	var shared := 0
	for tag in script.TAGS:
		if owned_tags.has(tag):
			shared += 1
	return w * (1.0 + TAG_AFFINITY_BONUS * shared)

func _weighted_pick_script(available: Array[Script]) -> Script:
	var weights := {}
	for script in available:
		weights[script] = offer_weight(script)
	return _weighted_pick(weights)

## Instantiates and activates the chosen upgrade, then removes it from the
## pool for good. Heal isn't in the pool, so erase() there is just a no-op.
func commit(script: Script) -> Upgrade:
	_pool.erase(script)
	var category : GameState.UPGRADE_CATAGORY = script.CATEGORY
	if category != GameState.UPGRADE_CATAGORY.HEAL:
		taken.append(script)
		for tag in script.TAGS:
			owned_tags[tag] = true

	var instance := script.new() as Upgrade
	add_child(instance)
	instance.activate()
	return instance

func _weighted_pick(weights: Dictionary):
	var total := 0.0
	for weight in weights.values():
		total += weight
	if total <= 0.0:
		return null
	var roll := randf() * total
	var accumulated := 0.0
	for key in weights:
		accumulated += weights[key]
		if roll <= accumulated:
			return key
	return weights.keys()[0]
