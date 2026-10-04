#version 300 es
// A stone dropped in a pond: where you clicked to pick a wallpaper, a short
// train of rings spreads and dies away, bending whatever is on screen as it
// passes. Nothing is drawn over the picture -- each pixel is just read from
// slightly further in or out along the radius -- apart from a faint sheen so
// the rings still show on flat color.
//
// A template: config/look_feel.lua fills in the @...@ values and switches the
// result on as the screen shader for a few seconds after a wallpaper is picked.
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
uniform vec2 screen_size;                    // this monitor, in pixels
uniform vec2 pointer_pressed_positions[32];  // recent clicks, newest first, as fractions of it
uniform float pointer_pressed_times[32];     // seconds since each of them
uniform float time;                          // seconds since switch-on, up to a second fast
uniform int wl_output;                       // id of the monitor being drawn
out vec4 fragColor;

const int   MONITOR    = @MONITOR@;  // the monitor the wallpaper was picked on
const float LEFT       = @LEFT@;     // switch-off is this long after switch-on, s
// The latest picks: where the cursor was just before, px, and how long before
// switch-on the picker registered it, s.
const vec3  PICKS[4]   = vec3[4](@PICKS@);

const float LIFE       = 2.8;    // seconds until the water is still again
const float DELAY      = 0.12;   // the stone lands this long after the button goes down
const float SPEED      = 420.0;  // how fast the rings travel, px/s
const float WAVELENGTH = 120.0;  // crest to crest, px
const float TRAIN      = 160.0;  // how far the rings trail behind the front, px
const float DEPTH      = 10.0;   // most a pixel is displaced, px
const float SHEEN      = 0.035;  // brightness swing from trough to crest
const float REACH      = 80.0;   // how far a click may be from where the cursor was just before, px
const int   CLICKS     = 8;      // how many recent clicks are looked at

// Whether a click, `ago` seconds before switch-on, is one of the picks. The
// picker registers a click when the button comes back up, so the press is a
// little older than the pick; and `ago` is derived from `time`, so it can read
// up to a second short.
bool picked(vec2 at, float ago) {
    for (int j = 0; j < 4; j++) {
        float lead = ago - PICKS[j].z;
        if (distance(at, PICKS[j].xy) < REACH && lead > -1.0 && lead < 0.7)
            return true;
    }
    return false;
}

void main() {
    fragColor = texture(tex, v_texcoord);
    if (wl_output != MONITOR)
        return;

    // Ripples are timed off the clicks themselves, which Hyprland reports
    // exactly. `time` is not exact -- it starts anywhere between 0 and 1 -- so
    // it only does loose jobs: matching clicks to picks above, and settling
    // everything ahead of switch-off.
    float settle = 1.0 - smoothstep(LEFT - 0.7, LEFT - 0.2, time);

    vec2 px = v_texcoord * screen_size;
    vec2 push = vec2(0.0);
    float lift = 0.0;
    for (int i = 0; i < CLICKS; i++) {
        float age = pointer_pressed_times[i] - DELAY;
        vec2 at = pointer_pressed_positions[i] * screen_size;
        if (age <= 0.0 || age >= LIFE || !picked(at, pointer_pressed_times[i] - time))
            continue;

        vec2 to = px - at;
        float r = length(to);
        float t = age / LIFE;

        // Height of the water here: a sine wave inside a soft window that
        // rides TRAIN behind the front, easing in and then fading with age.
        float s = r - SPEED * age;
        float window = exp(-2.0 * pow((s + TRAIN) / TRAIN, 2.0));
        float h = sin(6.2831853 * s / WAVELENGTH) * window
                * pow(1.0 - t, 1.5) * smoothstep(0.0, 0.04, t) * settle;

        push += (r > 0.0 ? to / r : vec2(0.0)) * h;
        lift += h;
    }

    fragColor = texture(tex, v_texcoord + push * DEPTH / screen_size);
    fragColor.rgb += lift * SHEEN;
}
