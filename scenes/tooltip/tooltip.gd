extends CanvasLayer
## Autoload ("Tooltip"): the one tooltip, shared by every card on every screen. It's another view of
## the card's item, the detailed one next to the card's compact face: name, kind and description,
## all read from the item, never by checking what type it is.
##
## It lives here rather than inside the card so it isn't scaled with the card, draws over every other
## card, and only one can show at a time. Cards call `show_for` and `hide_for`; it follows the card
## each frame and stays on screen.

## Gap in pixels between the card and the tooltip.
const GAP := 12.0
## Closest the tooltip gets to the edge of the screen.
const SCREEN_MARGIN := 8.0

var _card: Card

@onready var _panel: PanelContainer = $Panel
@onready var _title: Label = %Title
@onready var _kind: Label = %Kind
@onready var _description: RichTextLabel = %Description


## Shows `card`'s item, replacing whatever was showing.
func show_for(card: Card) -> void:
	_card = card
	var item := card.item
	_title.text = item.display_name
	_kind.text = item.get_kind_name()
	_kind.visible = not _kind.text.is_empty()
	_description.text = item.get_description()
	_description.visible = not _description.text.is_empty()
	_update()


## Hides the tooltip if it's still showing `card`, so a late exit from the last card can't hide the
## one the cursor has just moved onto.
func hide_for(card: Card) -> void:
	if _card == card:
		_card = null
		_update()


func _ready() -> void:
	_update()


func _process(_delta: float) -> void:
	_update()


func _update() -> void:
	# Paused, the cards stop hearing the mouse, so a tooltip left up would never go away.
	_panel.visible = is_instance_valid(_card) and not get_tree().paused
	if not _panel.visible:
		return
	_panel.size = _panel.get_combined_minimum_size() # shrink back after a longer description

	# Centred above the card, or below it if there's no room above, kept on screen.
	var card_rect := _card.get_resting_screen_rect()
	var screen := get_viewport().get_visible_rect().grow(-SCREEN_MARGIN)
	var pos := Vector2(card_rect.get_center().x - _panel.size.x / 2.0, card_rect.position.y - GAP - _panel.size.y)
	if pos.y < screen.position.y:
		pos.y = card_rect.end.y + GAP
	pos.x = clampf(pos.x, screen.position.x, maxf(screen.position.x, screen.end.x - _panel.size.x))
	pos.y = clampf(pos.y, screen.position.y, maxf(screen.position.y, screen.end.y - _panel.size.y))
	_panel.position = pos
