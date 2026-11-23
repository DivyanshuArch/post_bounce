shader_type canvas_item;

uniform vec4 vignette_color : source_color = vec4(0.047, 0.071, 0.059, 0.44);
uniform float inner_radius : hint_range(0.0, 1.0) = 0.36;
uniform float outer_radius : hint_range(0.0, 1.5) = 0.82;

uniform vec4 moon_color : source_color = vec4(0.91, 0.89, 0.83, 0.08);
uniform vec2 moon_pos = vec2(0.1, 0.1);
uniform float moon_radius : hint_range(0.0, 1.5) = 0.6;

void fragment() {
    // 1. Soft radial vignette from center to edges
    vec2 center_uv = UV - vec2(0.5);
    float dist_center = length(center_uv);
    float vig = smoothstep(inner_radius, outer_radius, dist_center);

    // 2. Soft subtle moon glow from upper-left
    float dist_moon = distance(UV, moon_pos);
    float moon_glow = (1.0 - smoothstep(0.0, moon_radius, dist_moon)) * moon_color.a;

    vec4 col = vec4(vignette_color.rgb, vignette_color.a * vig);
    col.rgb = mix(col.rgb, moon_color.rgb, moon_glow);
    col.a = max(col.a, moon_glow);

    COLOR = col;
}
