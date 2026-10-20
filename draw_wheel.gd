extends Node2D

@export var segment_texture: Texture2D
@export var texture_coverage: float = 0.5
@export var wheel_radius: float = 240
@export var inner_radius: float = 100
@export var label_radius: float = 210
@export var font: Font = ThemeDB.fallback_font
@export var font_size: int = 20
@export var segments: Array[Dictionary] = [
	{"number": 0, "colour": "green"},
	{"number": 32, "colour": "red"},
	{"number": 15, "colour": "black"},
	{"number": 19, "colour": "red"},
	{"number": 4, "colour": "black"},
	{"number": 21, "colour": "red"},
	{"number": 2, "colour": "black"},
	{"number": 25, "colour": "red"},
	{"number": 17, "colour": "black"},
	{"number": 34, "colour": "red"},
	{"number": 6, "colour": "black"},
	{"number": 27, "colour": "red"},
	{"number": 13, "colour": "black"},
	{"number": 36, "colour": "red"},
	{"number": 11, "colour": "black"},
	{"number": 30, "colour": "red"},
	{"number": 8, "colour": "black"},
	{"number": 23, "colour": "red"},
	{"number": 10, "colour": "black"},
	{"number": 5, "colour": "red"},
	{"number": 24, "colour": "black"},
	{"number": 16, "colour": "red"},
	{"number": 33, "colour": "black"},
	{"number": 1, "colour": "red"},
	{"number": 20, "colour": "black"},
	{"number": 14, "colour": "red"},
	{"number": 31, "colour": "black"},
	{"number": 9, "colour": "red"},
	{"number": 22, "colour": "black"},
	{"number": 18, "colour": "red"},
	{"number": 29, "colour": "black"},
	{"number": 7, "colour": "red"},
	{"number": 28, "colour": "black"},
	{"number": 12, "colour": "red"},
	{"number": 35, "colour": "black"},
	{"number": 3, "colour": "red"},
	{"number": 26, "colour": "black"}
]

const COLOURS = {
	"green": Color("#168653"),
	"red": Color("#c9343c"),
	"black": Color("#202529"),
	"gold": Color("#d9b66d"),
	"brown": Color("#331804")
}


func _draw() -> void:
	if segments.is_empty():
		return

	var segment_angle: float = TAU / segments.size()

	# Draw outer circle
	draw_circle(Vector2.ZERO, wheel_radius + 12, COLOURS["gold"], true, -1.0, true)

	# Draw each segment
	for i in segments.size():
		var segment: Dictionary = segments[i]
		var start_angle: float = -PI / 2.0 + i * segment_angle
		var end_angle: float = start_angle + segment_angle
		var middle_angle: float = (start_angle + end_angle) / 2.0

		var colour: Color = COLOURS[segment["colour"]]

		# Build a polygon for the centre and an arc
		var points: PackedVector2Array
		points.append(Vector2.ZERO)

		var arc_steps: int = maxi(4, int(ceil(24.0 * segment_angle / TAU)))

		for j in range(arc_steps + 1):
			var angle: float = lerp(start_angle, end_angle, float(j) / arc_steps)
			points.append(Vector2.from_angle(angle) * wheel_radius)

		if segment_texture:
			var uvs: PackedVector2Array = PackedVector2Array()

			for point in points:
				var radial_distance: float = point.length() / wheel_radius

				var angle: float
				if point.is_zero_approx():
					angle = middle_angle
				else:
					angle = point.angle()

				# Relative angle within this segment, from 0 to 1
				var relative_angle: float = (
					wrapf(angle - start_angle, 0.0, TAU)
					/ segment_angle
				)

				# Keep the centre vertex centred in the texture
				if point.is_zero_approx():
					relative_angle = 0.5

				# Control horizontal texture coverage
				var horizontal_uv: float = ((relative_angle - 0.5) / texture_coverage) + 0.5

				# Map the centre to the bottom and outer edge to the top
				var vertical_uv: float = 1.0 - radial_distance

				uvs.append(Vector2(horizontal_uv, vertical_uv))

			var vertex_colours: PackedColorArray = PackedColorArray()
			for _point in points:
				vertex_colours.append(colour)

			draw_polygon(points, vertex_colours, uvs, segment_texture)
		else:
			draw_colored_polygon(points, colour)

		# Draw borders between segments
		var edge_end: Vector2 = Vector2(cos(start_angle), sin(start_angle)) * wheel_radius
		draw_line(Vector2.ZERO, edge_end, COLOURS["gold"], 2.0, true)

		var label_position: Vector2 = Vector2(cos(middle_angle), sin(middle_angle)) * label_radius
		var label: String = str(segment["number"])
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var baseline_offset: float = (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0

		# Draw & rotate the label
		draw_set_transform(label_position, middle_angle + PI / 2.0)
		draw_string(font, Vector2(-text_size.x / 2.0, baseline_offset), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		draw_set_transform(Vector2.ZERO)

	# Center hub
	draw_circle(Vector2.ZERO, inner_radius + 5, COLOURS["gold"], true, -1.0, true)
	draw_circle(Vector2.ZERO, inner_radius, COLOURS["brown"], true, -1.0, true)
