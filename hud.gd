extends CanvasLayer

signal spin_requested


func _on_spin_button_pressed() -> void:
	spin_requested.emit()
