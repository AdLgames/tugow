// What the resonators are struck with.
//
// The single most important part of the engine. A one-sample impulse scaled
// by collision energy gives the same timbre at every velocity, only louder,
// and real objects sound brighter when hit harder rather than just louder.
//
// Hertzian contact theory gives contact duration t_c proportional to
// v^(-1/5): a harder impact is a shorter contact, a shorter contact is a
// wider excitation bandwidth, and a wider bandwidth reaches more of the high
// modes. Modelling the duration gets the brightness for free — no filter, no
// second parameter to keep in step with the first.
#pragma once

#include <cstdint>

namespace modal {

// Clamps on contact time, seconds. Below the first the pulse is a single
// sample at any sane rate; above the second nothing audible is left.
constexpr double kMinContactSeconds = 0.05e-3;
constexpr double kMaxContactSeconds = 20.0e-3;
constexpr double kReferenceVelocity = 1.0;  // m/s, where t_ref is measured

// Contact duration at an impact velocity, from the material's reference.
double contact_seconds(double contact_time_ref_ms, double velocity);

// A Hann pulse whose samples sum to `impulse`.
//
// Its width is fractional, in samples, and that matters more than it looks.
// A hard material at speed has a contact of two or three samples at 48 kHz,
// and rounding that to a whole number throws away the velocity resolution
// exactly where the plan wants it most: steel at 2 m/s and at 8 m/s both
// round to three samples and come out identical. Keeping the width
// fractional and sampling the window at its centres keeps the spectrum
// moving continuously with velocity.
//
// The window is normalised against its own sum rather than by an assumed
// average, so the impulse is delivered whole at any width — a Hann window
// averages one half, and dividing by the sample count instead would quietly
// deliver half the energy at every velocity.
struct Pulse {
    double impulse = 1.0;
    double width = 1.0;  // samples, fractional
    double scale = 1.0;  // impulse / sum of the window
    int frames = 1;      // samples to render, ceil(width)

    float sample(int n) const;
};

// The narrowest the window may be. Below one sample the centre lands on a
// zero of the window and the pulse vanishes.
constexpr double kMinPulseWidth = 1.0;

Pulse make_pulse(double impulse, double contact_time_ref_ms, double velocity,
                 double sample_rate);

// Writes the pulse into `out`, zero-padding past its end. Returns how many
// frames of it were written, so a caller can tell when it has finished.
int pulse_render(const Pulse& pulse, int start_frame, float* out, int frames);

}  // namespace modal
