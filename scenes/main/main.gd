extends Node2D


func _ready() -> void:
	$WheelViewportOutput.position = get_viewport_rect().size / 2
	$SubViewport/RouletteWheel.spin_finished.connect(_on_wheel_spin_finished)

func _on_wheel_spin_finished(index: int, segment: Dictionary) -> void:
	print("Landed on %s (%s) at index %d" % [segment["number"], segment["colour"], index])

func _on_spin_requested() -> void:
	$SubViewport/RouletteWheel.spin_wheel()
