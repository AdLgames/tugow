#include "modal/excitation.h"

#include <algorithm>
#include <cmath>

namespace modal {

double contact_seconds(double contact_time_ref_ms, double velocity) {
    const double reference = contact_time_ref_ms * 1e-3;
    // Hertz gives t_c proportional to v^(-1/5). A standing-still contact has
    // no impact velocity to speak of, so the low end is clamped rather than
    // allowed to divide by zero.
    const double safe_velocity = std::max(velocity, 1e-4);
    const double scaled = reference * std::pow(kReferenceVelocity / safe_velocity, 0.2);
    return std::clamp(scaled, kMinContactSeconds, kMaxContactSeconds);
}

namespace {

// Hann, evaluated at the centre of sample n. Centre sampling is what lets
// the width be fractional: at a width of one sample the single centre lands
// on the peak of the window rather than on its leading zero.
double window_at(int n, double width) {
    const double position = (n + 0.5) / width;
    if (position <= 0.0 || position >= 1.0) return 0.0;
    return 0.5 * (1.0 - std::cos(2.0 * M_PI * position));
}

}  // namespace

float Pulse::sample(int n) const {
    if (n < 0 || n >= frames) return 0.0f;
    return static_cast<float>(window_at(n, width) * scale);
}

Pulse make_pulse(double impulse, double contact_time_ref_ms, double velocity,
                 double sample_rate) {
    Pulse pulse;
    pulse.impulse = impulse;
    const double seconds = contact_seconds(contact_time_ref_ms, velocity);
    pulse.width = std::max(kMinPulseWidth, seconds * sample_rate);
    pulse.frames = std::max(1, static_cast<int>(std::ceil(pulse.width)));

    double total = 0.0;
    for (int n = 0; n < pulse.frames; ++n) total += window_at(n, pulse.width);
    // A width of exactly one sample puts its only centre at the window's
    // peak, so the sum is never zero, but a guard costs nothing and a silent
    // impact is a bug nobody can find.
    pulse.scale = total > 0.0 ? impulse / total : impulse;
    return pulse;
}

int pulse_render(const Pulse& pulse, int start_frame, float* out, int frames) {
    int written = 0;
    for (int i = 0; i < frames; ++i) {
        const int n = start_frame + i;
        out[i] = pulse.sample(n);
        if (n < pulse.frames) ++written;
    }
    return written;
}

}  // namespace modal
