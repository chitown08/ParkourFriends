// A light trail seen through walls (fainter: its `strength`), so you can
// find a friend behind a building. See light_trail.gdshader.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, blend_mix;

#include "res://materials/light_trail.gdshaderinc"
