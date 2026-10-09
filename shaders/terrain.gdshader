shader_type canvas_item;

// White terrain. Every pixel the player has touched is marked in erase_mask
// (alpha = 1) and rendered fully transparent.
uniform sampler2D erase_mask : filter_nearest;

void fragment() {
	float erased = texture(erase_mask, UV).a;
	COLOR = vec4(1.0, 1.0, 1.0, 1.0 - erased);
}
