extends CanvasLayer

## Anytime damage happens, whoever dealt it calls spawn() with a world
## position and the amount. Numbers stamp onto the screen rather than
## blooming in — see the phases below, each independently tunable.

@export_group("Slam")
## Scale it starts at before slamming down to 1.0 — bigger reads as more
## impact, like it's being stamped rather than grown.
@export var slam_start_scale : float = 2.5
## How long the slam-down takes. TRANS_BACK/EASE_OUT gives it a hard,
## fast drop that overshoots slightly below 1.0 before settling there.
@export var slam_time : float = 0.08

@export_group("Shake")
## How long the post-slam jitter lasts before going dead still. Counts
## against hold_time below, not on top of it.
@export var shake_time : float = 0.1
## Max jitter offset in pixels, decaying to 0 across shake_time.
@export var shake_strength : float = 3.0
@export var shake_steps : int = 5

@export_group("Hold & Fade")
## Total motionless time after the slam lands, INCLUDING the shake above —
## a stillness budget, not extra time added on top of it. 200-300ms reads
## as real weight; much less and it feels twitchy.
@export var hold_time : float = 0.25
@export var fade_time : float = 0.2

@export_group("Digit Stamping")
## Numbers with at least this many characters stamp in one at a time
## instead of landing all together.
@export var digit_stamp_min_digits : int = 4
## Delay between each character's own slam once digit-stamping kicks in.
@export var digit_stagger_time : float = 0.03

@export_group("Size")
@export var base_font_size : int = 28
@export var max_font_size : int = 90
## Damage at or above which size caps out at max_font_size. Raised to match
## ball.gd's new border-damage range (30-210 baseline) — the old value of 50
## would've maxed out the font on almost every hit.
@export var size_reference_damage : float = 200.0

@export_group("Notation")
## At or above this, switch from "1234" to "1.2k" shorthand.
@export var notation_threshold : float = 10000.0

@export_group("Style")
@export var text_color : Color = Color(1.6, 1.6, 1.6)
@export var outline_color : Color = Color(0.0, 0.0, 0.0, 0.6)
@export var outline_size : int = 4

@export_group("Screen Clamp")
## Kept off the very edge so a label is never visually clipped.
@export var screen_margin : float = 24.0

func spawn(world_position : Vector2, amount : float) -> void:
	if amount <= 0.0:
		return

	var text := _format_amount(amount)
	var settings := _build_settings(amount)

	var char_labels : Array[Label] = []
	for ch in text:
		var label := Label.new()
		label.text = ch
		label.label_settings = settings
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 4096
		label.modulate.a = 0.0
		add_child(label)
		# Not inside any Container, so nothing else will size this to fit
		# its text — has to be forced here, same fix as the upgrade popup.
		label.reset_size()
		char_labels.append(label)

	var total_size := Vector2.ZERO
	for label in char_labels:
		total_size.x += label.size.x
		total_size.y = maxf(total_size.y, label.size.y)

	# Peak footprint happens at spawn, when every character is briefly at
	# slam_start_scale — clamp against that, not the resting size.
	var center := get_viewport().get_canvas_transform() * world_position
	center = _clamp_center(center, total_size)

	var stagger := digit_stagger_time if text.length() >= digit_stamp_min_digits else 0.0

	var x := center.x - total_size.x * 0.5
	for i in char_labels.size():
		var label := char_labels[i]
		label.pivot_offset = label.size * 0.5
		label.position = Vector2(x, center.y - label.size.y * 0.5)
		x += label.size.x
		_animate(label, i * stagger)

func _format_amount(amount: float) -> String:
	if amount >= notation_threshold:
		return "%.1fk" % (amount / 1000.0)
	return "%.0f" % amount

func _build_settings(amount: float) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = _size_for(amount)
	settings.font_color = text_color
	settings.outline_size = outline_size
	settings.outline_color = outline_color
	return settings

func _size_for(amount: float) -> int:
	var t := clampf(amount / size_reference_damage, 0.0, 1.0)
	return roundi(lerpf(base_font_size, max_font_size, t))

## Clamps the group's centerpoint (not any one character's corner) so the
## whole number's peak, oversized footprint can never cross the screen edge.
func _clamp_center(center: Vector2, size: Vector2) -> Vector2:
	var viewport_rect := get_viewport().get_visible_rect()
	var half := size * 0.5 * slam_start_scale + Vector2(screen_margin, screen_margin)
	var max_c := viewport_rect.size - half
	return Vector2(
		clampf(center.x, half.x, maxf(max_c.x, half.x)),
		clampf(center.y, half.y, maxf(max_c.y, half.y)))

## One character's full lifecycle: wait its stagger delay, slam down from
## slam_start_scale, jitter briefly, sit dead still, fade, free itself.
func _animate(label: Label, delay: float) -> void:
	label.scale = Vector2.ONE * slam_start_scale
	var base_position := label.position

	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(func(): label.modulate.a = 1.0)

	tween.tween_property(label, "scale", Vector2.ONE, slam_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var steps := maxi(shake_steps, 1)
	var step_time := shake_time / steps
	for i in steps:
		var decay := 1.0 - float(i) / steps
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength * decay
		tween.tween_property(label, "position", base_position + offset, step_time)
	# Snap back to the exact resting spot — no residual jitter into the hold.
	tween.tween_property(label, "position", base_position, 0.001)

	tween.tween_interval(maxf(hold_time - shake_time, 0.0))
	tween.tween_property(label, "modulate:a", 0.0, fade_time)
	tween.tween_callback(label.queue_free)
