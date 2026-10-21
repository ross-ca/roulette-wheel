class_name ShopStep
extends RunStep
## A visit to the shop between rounds.


func _init() -> void:
	# load(), not preload(): shop.gd refers back to this class.
	phase_scene = load("res://scenes/shop/shop.tscn")
