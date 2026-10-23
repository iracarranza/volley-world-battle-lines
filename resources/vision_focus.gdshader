shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, skip_vertex_transform;
// The athlete's focus when an action is released: a directed, triangular beam from the athlete toward the ball, like light fanned out through a prism. Inside
// the triangle the picture is clear, starting from its centre line and clearing outward as the athlete takes in the situation. Outside it is blurred and
// darkened, and the edges of the beam refract: the colour channels split along them. Everything is driven from vision_focus.gd.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 apex = vec2(0.5, 0.8);      // where the beam starts (the athlete), in uv
uniform vec2 target = vec2(0.5, 0.4);    // where it points (the ball), in uv
uniform float aspect = 1.7778;
uniform float half_width = 0.25;         // the beam's half-width at its far end, in screen heights
uniform float reach = 1.18;              // the far end, as a multiple of the distance from apex to target
uniform float core = 0.2;                // the fraction of the beam's width that is sharp now (grows as the beam clears)
uniform float blur_amount = 0.012;       // blur radius outside the beam, in uv
uniform float darkness = 0.0;            // darkening away from the beam, 0..1
uniform float strength = 0.0;            // 0 = no effect
uniform float refraction = 0.012;        // how far the colour channels split at the beam's edges, in uv

void vertex() {
	// A quad that fills the camera's view: the post-process runs over the finished 3D picture.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 base = texture(screen_tex, uv).rgb;
	if (strength <= 0.001) {
		ALBEDO = base;
	} else {
		vec2 scale = vec2(aspect, 1.0);
		vec2 axis_full = (target - apex) * scale;
		float length_full = max(length(axis_full), 0.05);
		vec2 direction = axis_full / length_full;
		float beam_length = length_full * reach;
		vec2 v = (uv - apex) * scale;
		float along = dot(v, direction);
		float across = abs(v.x * direction.y - v.y * direction.x);
		float t = clamp(along / beam_length, 0.0, 1.0);
		// A triangle: nothing at the apex, widening to half_width at the far end.
		float width = max(half_width * t, 0.012);
		float u = across / width;
		// Sideways: sharp inside the core, blurred beyond the beam's edge. Lengthwise: sharp up to the far end, blurred past it and behind the athlete.
		float side = smoothstep(core, 1.0 + 0.22, u);
		float far = smoothstep(beam_length, beam_length + 0.10, along) + smoothstep(0.0, -0.06, along);
		float blur_mix = clamp(max(side, far), 0.0, 1.0) * strength;
		float outside = max(across - width, 0.0) + max(along - beam_length, 0.0) + max(-along, 0.0);
		float dark_mix = smoothstep(0.0, 0.40, outside) * darkness * strength;
		vec3 colour = base;
		if (blur_mix > 0.01) {
			vec3 sum = base;
			float weight = 1.0;
			for (int i = 0; i < 12; i++) {
				float angle = float(i) * 2.39996;
				float reach_i = sqrt(float(i + 1) / 12.0) * blur_amount * blur_mix;
				vec2 tap = vec2(cos(angle) / aspect, sin(angle)) * reach_i;
				sum += texture(screen_tex, uv + tap).rgb;
				weight += 1.0;
			}
			colour = mix(base, sum / weight, clamp(blur_mix * 1.2, 0.0, 1.0));
		}
		// The refracted edge: red and blue are bent opposite ways across the edge of the beam.
		float edge = exp(-pow((across - width) / 0.035, 2.0)) * step(0.0, along) * (1.0 - step(beam_length, along));
		if (edge > 0.02) {
			vec2 normal = vec2(-direction.y, direction.x) * sign(v.x * direction.y - v.y * direction.x);
			vec2 bend = normal * refraction * edge * strength / scale;
			colour.r = mix(colour.r, texture(screen_tex, uv + bend).r, edge * strength);
			colour.b = mix(colour.b, texture(screen_tex, uv - bend).b, edge * strength);
			colour += vec3(0.10, 0.14, 0.18) * edge * strength;
		}
		ALBEDO = colour * (1.0 - dark_mix);
	}
}
