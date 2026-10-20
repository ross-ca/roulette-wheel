extends Node2D


func _ready() -> void:
	$WheelViewportOutput.position = get_viewport_rect().size / 2

func _on_spin_requested() -> void:
	$SubViewport/RouletteWheel.spin_wheel()
