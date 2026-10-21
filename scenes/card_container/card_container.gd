@tool
extends Container
## Lays its children (cards) out in a horizontal row, accounting for each child's scale.
## Unlike HBoxContainer, which ignores scale, so scaled cards would overlap or leave gaps.

enum Alignment { BEGIN, CENTER, END }

## Scale applied to every card. Set here rather than on each card: scale on a container's
## child isn't saved with the scene, so it only ever showed up in the editor.
@export var card_scale: float = 2.15625:
	set(value):
		card_scale = value
		queue_sort()
		update_minimum_size()
## Extra phase (radians) added per card, left to right, to both the bob and the idle tilt
## drift, so each card is at a different point in its cycles. Card n gets n * bob_tilt_offset_step.
@export_range(0.0, 3.14159, 0.01) var bob_tilt_offset_step: float = 0.6:
	set(value):
		bob_tilt_offset_step = value
		queue_sort()
## Gap in pixels between neighbouring cards, measured between their scaled edges.
@export var separation: float = 16.0:
	set(value):
		separation = value
		queue_sort()
		update_minimum_size()
## Where the row sits inside the container when the container is wider than the cards.
@export var alignment: Alignment = Alignment.CENTER:
	set(value):
		alignment = value
		queue_sort()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_sort_cards()


func _get_minimum_size() -> Vector2:
	var cards := _cards()
	var result := Vector2.ZERO
	for card in cards:
		var scaled := _scaled_size(card)
		result.x += scaled.x
		result.y = maxf(result.y, scaled.y)
	if cards.size() > 1:
		result.x += separation * (cards.size() - 1)
	return result


func _sort_cards() -> void:
	var cards := _cards()
	if cards.is_empty():
		return

	var row_width := get_combined_minimum_size().x
	var x := 0.0
	match alignment:
		Alignment.CENTER:
			x = (size.x - row_width) / 2.0
		Alignment.END:
			x = size.x - row_width

	for i in cards.size():
		var card := cards[i]
		var phase := fposmod(i * bob_tilt_offset_step, TAU)
		var card_material := card.material as ShaderMaterial
		if card_material:
			card_material.set_shader_parameter("bob_offset", phase)
		if "idle_phase_offset" in card:
			card.set("idle_phase_offset", phase)
		var base_size := card.get_combined_minimum_size()
		var scaled := base_size * card_scale
		if "base_scale" in card:
			card.set("base_scale", Vector2.ONE * card_scale) # Card adds its hover pop on top
		else:
			card.scale = Vector2.ONE * card_scale
		# Scaling is about the card's centre (its pivot), so the visual rect grows
		# symmetrically around position + base_size / 2; shift back to hit the slot.
		var pivot_shift := (base_size - scaled) / 2.0
		var y := (size.y - scaled.y) / 2.0
		card.position = Vector2(x, y) - pivot_shift
		card.size = base_size
		x += scaled.x + separation


func _cards() -> Array[Control]:
	var cards: Array[Control] = []
	for child in get_children():
		if child is Control and child.visible:
			cards.append(child)
	return cards


func _scaled_size(card: Control) -> Vector2:
	return card.get_combined_minimum_size() * card_scale
