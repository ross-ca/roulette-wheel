shader_type canvas_item;

uniform vec4 background_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 offset_in_pixels = vec2(4.0, 4.0);
uniform float bob_pixels : hint_range(0.0, 32.0) = 12.0;
uniform float bob_speed : hint_range(0.0, 6.0) = 1.25;

void fragment()
{
	// Lift by the amplitude so the lowest point of the bob is the resting position.
	float bob = sin(TIME * bob_speed) * bob_pixels + bob_pixels;
	vec2 sample_uv = UV + vec2(0.0, bob) * TEXTURE_PIXEL_SIZE;

	vec4 current_color = texture(TEXTURE, sample_uv);

	// Shadow is cast from the wheel at rest, so it stays put while the wheel bobs.
	if (length(current_color - background_color) < 0.01) {
		vec2 shadow_uv = UV - offset_in_pixels * TEXTURE_PIXEL_SIZE;

		if (shadow_uv.x >= 0.0 && shadow_uv.y >= 0.0 && shadow_uv.x <= 1.0 && shadow_uv.y <= 1.0) {
			vec4 offset_color = texture(TEXTURE, shadow_uv);

			if (length(offset_color - background_color) > 0.01) {
				current_color = shadow_color;
			}
		}
	}

	COLOR = current_color;
}
