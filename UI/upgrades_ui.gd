extends HBoxContainer

## Emitted once a pick has been activated and the menu has cleared itself.
signal closed

const CARD_SCENE := preload("res://UI/upgrade_card.tscn")

func _ready() -> void:
	hide()
	#show()
	#open()
	GameState.boss_dead.connect(open)

## Rolls a fresh set of choices and shows them.
func open() -> void:
	GameState.ball.reset_to_entrance()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for card in get_children():
		card.queue_free()

	if GameState.player_health < 3:
		_add_card(Upgrades.HEAL_SCRIPT)
		for script in Upgrades.roll(2):
			_add_card(script)
	else:
		for script in Upgrades.roll(3):
			_add_card(script)

	show()

func _add_card(script: Script) -> void:
	var card := CARD_SCENE.instantiate()
	card.upgrade_script = script
	card.upgrade_name = script.DISPLAY_NAME
	card.description = script.DESCRIPTION
	card.catagory = script.CATEGORY
	card.rarity = script.RARITY
	card.chosen.connect(_on_card_chosen)
	add_child(card)

func _on_card_chosen(script: Script) -> void:
	Upgrades.commit(script)
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	hide()
	closed.emit()
