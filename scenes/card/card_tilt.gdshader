// "Fakes" a 3D-camera perspective on a CanvasItem, so a flat card can tilt in 3D.
// Based on the "2D perspective" shader by Hei (https://godotshaders.com/shader/2d-perspective/), MIT licence.
// Changes: x_rot/y_rot are plain uniforms (each Card has its own material, see card.tscn)
// instead of instance uniforms, and the redundant PI constant is dropped (built in).
//
// The CanvasItem's rect must be the same size as its texture (true for a TextureRect that
// isn't stretched), because the vertex stage works in texture pixels.

shader_type canvas_item;

// Camera FOV
uniform float fov : hint_range(1, 179) = 90;
uniform bool cull_back = true;
uniform float y_rot : hint_range(-180, 180) = 0.0;
uniform float x_rot : hint_range(-180, 180) = 0.0;
// At 0, the image retains its size when unrotated.
// At 1, the image is resized so that it can do a full
// rotation without clipping inside its rect.
uniform float inset : hint_range(0, 1) = 0.0;

// Bob and shadow, as in wheelShader.gdshader. Pixel values are in texture pixels.
uniform vec4 background_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 shadow_color : source_color = vec4(0.15686275, 0.15686275, 0.15686275, 1.0);
uniform vec2 offset_in_pixels = vec2(4.0, 4.0);
uniform float bob_pixels : hint_range(0.0, 32.0) = 3.0;
uniform float bob_speed : hint_range(0.0, 6.0) = 1.25;
// Phase shift of the bob in radians, so neighbouring cards needn't move in sync.
uniform float bob_offset : hint_range(0.0, 6.283185) = 0.0;

// Dissolve: pixels disappear where the noise (mixed towards the gradient by mix_ratio) is below
// dissolve_amount, so 0 leaves the card whole and 1 removes all of it, shadow included.
// The textures are read in card space, so the pattern tilts and bobs with the card. An unassigned
// texture reads as white, which never dissolves, so Card assigns the noise.
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float mix_ratio : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D dissolve_noise : hint_default_white;
uniform sampler2D dissolve_gradient : hint_default_white;

varying flat vec2 o;
varying vec3 p;

// Creates rotation matrix
void vertex() {
	float sin_b = sin(y_rot / 180.0 * PI);
	float cos_b = cos(y_rot / 180.0 * PI);
	float sin_c = sin(x_rot / 180.0 * PI);
	float cos_c = cos(x_rot / 180.0 * PI);

	mat3 inv_rot_mat;
	inv_rot_mat[0][0] = cos_b;
	inv_rot_mat[0][1] = 0.0;
	inv_rot_mat[0][2] = -sin_b;

	inv_rot_mat[1][0] = sin_b * sin_c;
	inv_rot_mat[1][1] = cos_c;
	inv_rot_mat[1][2] = cos_b * sin_c;

	inv_rot_mat[2][0] = sin_b * cos_c;
	inv_rot_mat[2][1] = -sin_c;
	inv_rot_mat[2][2] = cos_b * cos_c;

	float t = tan(fov / 360.0 * PI);
	p = inv_rot_mat * vec3((UV - 0.5), 0.5 / t);
	float v = (0.5 / t) + 0.5;
	p.xy *= v * inv_rot_mat[2].z;
	o = v * inv_rot_mat[2].xy;

	VERTEX += (UV - 0.5) / TEXTURE_PIXEL_SIZE * t * (1.0 - inset);
}

// Card colour at a texture UV; anywhere off the card counts as background.
// TEXTURE is only in scope in the built-in functions, so it's passed in.
vec4 card_color(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return background_color;
	return texture(tex, uv);
}

void fragment() {
	if (cull_back && p.z <= 0.0) discard;
	vec2 uv = (p.xy / p.z).xy - o + 0.5;

	// Same bob and shadow as wheelShader.gdshader. The vertex stage draws the quad larger
	// than the card (at inset 0), so there's room outside the card for both.
	// Lift by the amplitude so the lowest point of the bob is the resting position.
	float bob = sin(TIME * bob_speed + bob_offset) * bob_pixels + bob_pixels;
	vec4 current_color = card_color(TEXTURE, uv + vec2(0.0, bob) * TEXTURE_PIXEL_SIZE);

	// Shadow is cast from the card at rest, so it stays put while the card bobs.
	if (length(current_color - background_color) < 0.01) {
		vec4 offset_color = card_color(TEXTURE, uv - offset_in_pixels * TEXTURE_PIXEL_SIZE);

		if (length(offset_color - background_color) > 0.01) {
			current_color = shadow_color;
		}
	}

	if (dissolve_amount > 0.0) {
		vec2 dissolve_uv = clamp(uv + vec2(0.0, bob) * TEXTURE_PIXEL_SIZE, 0.0, 1.0);
		float n = mix(texture(dissolve_noise, dissolve_uv).x, texture(dissolve_gradient, dissolve_uv).x, mix_ratio);
		// The small factor puts the threshold above a noise value of 1 at full amount.
		current_color.a *= step(dissolve_amount * 1.001, n);
	}

	COLOR = current_color;
}
