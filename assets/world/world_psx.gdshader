shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform bool enable_monochrome = true;
uniform float saturation : hint_range(0.0, 1.0) = 0.0;
uniform vec4 shadow_tint : source_color = vec4(0.02, 0.03, 0.05, 1.0);
uniform vec4 mid_tint : source_color = vec4(0.40, 0.45, 0.48, 1.0);
uniform vec4 highlight_tint : source_color = vec4(0.92, 0.94, 0.96, 1.0);
uniform float tint_balance : hint_range(0.0, 1.0) = 0.5;

uniform float contrast : hint_range(0.5, 2.5) = 1.25;
uniform float brightness : hint_range(-0.5, 0.5) = 0.0;
uniform float gamma : hint_range(0.5, 2.0, 0.05) = 1.0;

uniform bool enable_pixelation = true;
uniform vec2 target_resolution = vec2(854.0, 480.0);

uniform bool enable_dithering = true;
uniform float color_depth : hint_range(2.0, 64.0, 1.0) = 32.0;
uniform float dither_intensity : hint_range(0.0, 1.0) = 0.12;
uniform float dither_scale : hint_range(1.0, 6.0, 1.0) = 2.0;
uniform float dither_cutoff : hint_range(0.0, 0.3, 0.01) = 0.05;

uniform bool enable_scanlines = true;
uniform float scanline_count = 480.0;
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.05;
uniform float scanline_speed = 0.0;

uniform bool enable_vignette = true;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.65;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.6;

uniform bool invert_colors = false;

const float bayer4[16] = float[](
	 0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
	12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0,
	 3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
	15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0
);

void fragment() {
	vec2 uv = SCREEN_UV;

	if (enable_pixelation && target_resolution.x > 0.0 && target_resolution.y > 0.0) {
		uv = floor(uv * target_resolution) / target_resolution;
	}

	vec3 original_color = texture(screen_texture, uv).rgb;

	float lum = dot(original_color, vec3(0.299, 0.587, 0.114));
	lum = pow(lum, gamma);
	lum = clamp((lum - 0.5) * contrast + 0.5 + brightness, 0.0, 1.0);

	if (enable_dithering) {
		ivec2 pixel_coord = ivec2(floor(FRAGCOORD.xy / max(1.0, dither_scale)));
		int bayer_index = (pixel_coord.x % 4) + (pixel_coord.y % 4) * 4;
		
		float dither_mask = smoothstep(0.0, dither_cutoff, lum) * (1.0 - smoothstep(1.0 - dither_cutoff, 1.0, lum));
		
		float dither_val = (bayer4[bayer_index] - 0.5) * dither_intensity * dither_mask;
		lum += dither_val;
		lum = clamp(floor(lum * color_depth) / color_depth, 0.0, 1.0);
	}

	vec3 final_color;
	if (lum < tint_balance) {
		final_color = mix(shadow_tint.rgb, mid_tint.rgb, lum / max(tint_balance, 0.001));
	} else {
		final_color = mix(mid_tint.rgb, highlight_tint.rgb, (lum - tint_balance) / max(1.0 - tint_balance, 0.001));
	}

	if (!enable_monochrome) {
		final_color = mix(final_color, original_color, saturation);
	}

	if (enable_scanlines) {
		float scan_offset = TIME * scanline_speed;
		float scanline = sin((uv.y + scan_offset) * scanline_count * 3.14159265 * 2.0);
		scanline = (scanline + 1.0) * 0.5;
		final_color -= (1.0 - scanline) * scanline_opacity;
	}

	if (enable_vignette) {
		vec2 v_uv = uv - vec2(0.5);
		float v_dist = length(v_uv);
		float vignette = smoothstep(0.2, 0.75, v_dist * vignette_intensity);
		final_color = mix(final_color, shadow_tint.rgb * 0.5, vignette * vignette_opacity);
	}

	if (invert_colors) {
		final_color = vec3(1.0) - final_color;
	}

	COLOR = vec4(clamp(final_color, 0.0, 1.0), 1.0);
}
