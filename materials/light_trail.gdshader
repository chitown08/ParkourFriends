// A light trail (player/light_trail.gd): a ribbon of light along where a
// player has been. It turns to face the camera and keeps at least
// `screen_width` of the screen wide however far off it is (so it doesn't
// need to be big up close to be seen from across the city), it isn't
// shaded or hidden by the haze, and it's faint near the camera (the
// player's right there) and fades out at its old end (vertex alpha).
// (light_trail_through.gdshader draws it again, fainter, through walls.)
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

#include "res://materials/light_trail.gdshaderinc"
