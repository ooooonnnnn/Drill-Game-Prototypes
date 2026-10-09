shader_type canvas_item;

// White terrain. solid_mask's alpha is 1 where terrain is intact and 0 where
// the player has drilled it away (transparent pixels).
uniform sampler2D solid_mask : filter_nearest;

void fragment() {
	COLOR = vec4(1.0, 1.0, 1.0, texture(solid_mask, UV).a);
}
