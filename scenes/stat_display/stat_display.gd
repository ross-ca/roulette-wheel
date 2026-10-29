@tool
class_name StatDisplay
extends PanelContainer
## A boxed readout, like the money, rolls and profit along the top of the betting view: a small
## title above a big number padded with leading zeros to `digits` wide. The zeros and the number
## are separate labels so they can be styled apart; the looks live in stat_display.tscn.

@export var title := "Title":
	set(text):
		title = text
		_refresh()
## Shown before the number and its zeros, styled like the number, such as "$" for money.
@export var prefix := "":
	set(text):
		prefix = text
		_refresh()
## How many digits the number is padded to with leading zeros. Longer numbers show in full.
@export_range(1, 12) var digits := 3:
	set(count):
		digits = count
		_refresh()
@export var value := 0:
	set(number):
		value = number
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	var number := str(absi(value))
	$Rows/Title.text = title
	$Rows/Value/Prefix.text = prefix
	$Rows/Value/Prefix.visible = not prefix.is_empty()
	# A negative value (a round in the red) puts its sign in front of the zeros.
	$Rows/Value/Zeros.text = ("-" if value < 0 else "") + "0".repeat(maxi(digits - number.length(), 0))
	$Rows/Value/Number.text = number
