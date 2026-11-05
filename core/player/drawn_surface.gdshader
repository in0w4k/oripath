shader_type spatial;
render_mode specular_disabled;

uniform vec4 paper_color : source_color = vec4(0.65, 0.66, 0.62, 1.0);
uniform sampler2D base_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform float texture_amount : hint_range(0.0, 1.0) = 0.55;
uniform float hatch_amount : hint_range(0.0, 1.0) = 0.22;
uniform float hatch_scale = 110.0;
uniform float blanket_bulge = 0.0;
uniform float self_light : hint_range(0.0, 1.0) = 0.04;
varying vec3 world_position;
varying float hatch;

float pen_line(float phase) {
	float wave = sin(phase);
	float aa = max(fwidth(phase), 0.08);
	return 1.0 - smoothstep(0.09, 0.09 + aa, abs(wave));
}

void vertex() {
	VERTEX.y += sin(UV.x * PI) * sin(UV.y * PI) * blanket_bulge;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 pigment = paper_color.rgb;
	if (use_texture) {
		vec3 texel = texture(base_texture, UV).rgb;
		float gray = dot(texel, vec3(0.299, 0.587, 0.114));
		pigment *= mix(vec3(1.0), mix(vec3(gray), texel, 0.15), texture_amount);
	}
	vec2 p = vec2(world_position.x + world_position.z * 0.37, world_position.y + world_position.z * 0.64);
	float phase = (p.x + p.y * 0.72) * hatch_scale;
	phase += sin(p.y * 27.0) * 0.35 + sin(p.x * 13.0) * 0.18;
	hatch = pen_line(phase);
	ALBEDO = pigment;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = pigment * self_light;
}

void light() {
	float diffuse = max(dot(NORMAL, LIGHT), 0.0);
	float bands = mix(0.08, 0.5, smoothstep(0.16, 0.21, diffuse));
	bands = mix(bands, 1.0, smoothstep(0.64, 0.69, diffuse));
	float strokes = 1.0 - hatch * hatch_amount * (1.0 - smoothstep(0.4, 0.8, diffuse * ATTENUATION));
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * bands * strokes / PI;
}
