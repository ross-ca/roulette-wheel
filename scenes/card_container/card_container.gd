@tool
class_name CardContainer
extends Container
## Lays its children (cards) out in a horizontal row, accounting for each child's scale.
## Unlike HBoxContainer, which ignores scale, so scaled cards would overlap or leave gaps.
## At runtime the cards can be dragged left and right to reorder them. That's the one interaction
## this container gives a card; what the new order means (e.g. ticket trigger order) is up to the
## scene that uses it, via `order_changed`.

## Emitted after a drag ends with the cards in a different order than they started.
signal order_changed
## Emitted when a card is right-clicked (and none is being dragged). What it means is up to the scene.
signal item_right_clicked(item: Modifier)

const CARD_SCENE := preload("res://scenes/card/card.tscn")

enum Alignment { BEGIN, CENTER, END }

## Scale applied to every card. Set here rather than on each card: scale on a container's
## child isn't saved with the scene, so it only ever showed up in the editor.
@export var card_scale: float = 2.15625:
	set(value):
		card_scale = value
		queue_sort()
		update_minimum_size()
## Extra phase (radians) added per card, left to right, to both the bob and the idle tilt
## drift, so each card is at a different point in its cycles. Card n gets n * bob_tilt_offset_step,
## counted in the order the cards were added, so reordering doesn't make their motion jump.
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
## How quickly cards slide into their slots after a reorder. Higher is snappier.
@export var slide_speed: float = 18.0
## Where the row sits inside the container when the container is wider than the cards.
@export var alignment: Alignment = Alignment.CENTER:
	set(value):
		alignment = value
		queue_sort()

var _dragged: Control
var _grab_dx := 0.0 # mouse x minus the dragged card's position.x when it was picked up
var _order_at_grab: Array[Control] = []
var _mouse_filters := {} # Control -> MouseFilter, of the other cards while one is dragged
var _targets := {} # Control -> Vector2, the position its slot wants
var _phase_index := {} # Control -> int, fixed when a card is first seen
var _next_phase_index := 0


## Replaces the cards with one per item, in order.
func set_items(items: Array) -> void:
	for child in get_children():
		remove_child(child) # out of the tree now, so _cards() doesn't see it before it's freed
		child.queue_free()
	for item: Modifier in items:
		var card: Card = CARD_SCENE.instantiate()
		card.setup(item)
		add_child(card)


## Removes the card showing `item`. It dissolves first, holding its slot, and only then do the
## others slide together to close the gap. Await it to know when the card is gone.
func remove_item(item: Modifier) -> void:
	for card in _cards():
		if card is Card and card.item == item:
			await card.dissolve()
			remove_child(card) # out of the tree now, so _cards() doesn't see it before it's freed
			card.queue_free()
			queue_sort()
			update_minimum_size()
			return


## The items of the cards, in their current left-to-right order. Assign it to a typed array
## (e.g. `run.tickets.assign(...)`) to get the item type back.
func get_items() -> Array[Modifier]:
	var items: Array[Modifier] = []
	for card in _cards():
		if card is Card:
			items.append(card.item)
	return items


func _ready() -> void:
	for child in get_children():
		_watch(child)
	child_entered_tree.connect(_watch)
	child_exiting_tree.connect(_forget)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var follow := 1.0 - exp(-slide_speed * delta)
	for card: Control in _targets:
		if card != _dragged:
			card.position = card.position.lerp(_targets[card], follow)


func _input(event: InputEvent) -> void:
	if _dragged == null:
		return
	if event is InputEventMouseMotion:
		_drag_to(get_local_mouse_position().x)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_drop()


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

	var slot_lefts := _slot_lefts(cards)
	for i in cards.size():
		var card := cards[i]
		if not _phase_index.has(card):
			_phase_index[card] = _next_phase_index
			_next_phase_index += 1
		var phase := fposmod(_phase_index[card] * bob_tilt_offset_step, TAU)
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
		var placed := _targets.has(card)
		_targets[card] = Vector2(slot_lefts[i], y) - pivot_shift
		card.size = base_size
		if card == _dragged:
			card.position.y = _targets[card].y # x follows the mouse
		elif not placed or Engine.is_editor_hint():
			card.position = _targets[card]


## Left edge of each card's slot (in its scaled, visual rect), in the order of `cards`.
func _slot_lefts(cards: Array[Control]) -> Array[float]:
	var x := 0.0
	var row_width := get_combined_minimum_size().x
	match alignment:
		Alignment.CENTER:
			x = (size.x - row_width) / 2.0
		Alignment.END:
			x = size.x - row_width

	var lefts: Array[float] = []
	for card in cards:
		lefts.append(x)
		x += _scaled_size(card).x + separation
	return lefts


func _watch(node: Node) -> void:
	if node is Control:
		node.gui_input.connect(_on_card_gui_input.bind(node))


func _forget(node: Node) -> void:
	_targets.erase(node)
	_phase_index.erase(node)
	_mouse_filters.erase(node)
	if node == _dragged:
		_dragged = null
		_restore_mouse_filters()


func _on_card_gui_input(event: InputEvent, card: Control) -> void:
	if Engine.is_editor_hint() or _dragged != null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if card is Card:
			item_right_clicked.emit(card.item)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dragged = card
		_grab_dx = get_local_mouse_position().x - card.position.x
		_order_at_grab = _cards()
		card.z_index = 1 # draw over its neighbours
		if "held" in card:
			card.set("held", true)
		# Mouse picking goes by tree order, not z_index, so a neighbour later in the tree would
		# take the hover (and its tooltip) whenever the dragged card is over it.
		for other in _order_at_grab:
			if other != card:
				_mouse_filters[other] = other.mouse_filter
				other.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Moves the dragged card with the mouse and swaps it into whichever slot it's nearest.
func _drag_to(mouse_x: float) -> void:
	_dragged.position.x = mouse_x - _grab_dx
	var centre := _dragged.position.x + _dragged.get_combined_minimum_size().x / 2.0

	var cards := _cards()
	var slot_lefts := _slot_lefts(cards)
	var nearest := 0
	var nearest_distance := INF
	for i in cards.size():
		var distance := absf(centre - (slot_lefts[i] + _scaled_size(cards[i]).x / 2.0))
		if distance < nearest_distance:
			nearest = i
			nearest_distance = distance

	if cards[nearest] != _dragged:
		move_child(_dragged, cards[nearest].get_index())
		queue_sort()


func _drop() -> void:
	var card := _dragged
	_dragged = null
	card.z_index = 0 # it eases back to its slot from where it was dropped
	if "held" in card:
		card.set("held", false)
	_restore_mouse_filters()
	if _cards() != _order_at_grab:
		order_changed.emit()


func _restore_mouse_filters() -> void:
	for other: Control in _mouse_filters:
		other.mouse_filter = _mouse_filters[other]
	_mouse_filters.clear()


func _cards() -> Array[Control]:
	var cards: Array[Control] = []
	for child in get_children():
		if child is Control and child.visible:
			cards.append(child)
	return cards


func _scaled_size(card: Control) -> Vector2:
	return card.get_combined_minimum_size() * card_scale
