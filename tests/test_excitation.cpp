// The excitation is where the realism lives, so it is where the tests are.
#include "doctest.h"

#include <cmath>
#include <vector>

#include "modal/bank.h"
#include "modal/excitation.h"
#include "modal/model.h"

namespace {

constexpr double kRate = 48000.0;

double sum_of(const modal::Pulse& pulse) {
    double total = 0.0;
    for (int n = 0; n < pulse.frames; ++n) total += pulse.sample(n);
    return total;
}

// Energy-weighted mean frequency. Rising with velocity is the whole claim.
double centroid(const std::vector<float>& samples) {
    const int bins = 192;
    const double lowest = 50.0, highest = 0.45 * kRate;
    double weighted = 0.0, total = 0.0;
    for (int b = 0; b < bins; ++b) {
        const double t = static_cast<double>(b) / (bins - 1);
        const double f = lowest * std::pow(highest / lowest, t);
        const double coefficient = 2.0 * std::cos(2.0 * M_PI * f / kRate);
        double s1 = 0.0, s2 = 0.0;
        for (float sample : samples) {
            const double s = sample + coefficient * s1 - s2;
            s2 = s1;
            s1 = s;
        }
        const double power = s1 * s1 + s2 * s2 - coefficient * s1 * s2;
        const double magnitude = std::sqrt(power > 0.0 ? power : 0.0);
        weighted += f * magnitude;
        total += magnitude;
    }
    return total > 0.0 ? weighted / total : 0.0;
}

}  // namespace

TEST_CASE("the pulse delivers the impulse it was asked for") {
    // A Hann window averages one half, so dividing by the sample count would
    // deliver half the impulse — quietly, and at every velocity, so nothing
    // would look wrong except that hard hits are weak.
    for (double velocity : {0.25, 1.0, 4.0, 16.0}) {
        for (double impulse : {0.1, 1.0, 7.5}) {
            const auto pulse = modal::make_pulse(impulse, 0.15, velocity, kRate);
            CHECK(sum_of(pulse) == doctest::Approx(impulse).epsilon(0.001));
        }
    }
}

TEST_CASE("a single sample pulse is still the whole impulse") {
    // The shortest contact is clamped at 0.05 ms, which is still two samples
    // at 48 kHz — a one-frame pulse needs a rate low enough that the clamp
    // rounds to one. The case exists because n / frames divides by zero in
    // the window when frames is 1, so that path returns the impulse whole.
    const auto pulse = modal::make_pulse(2.0, 0.001, 50.0, 8000.0);
    REQUIRE(pulse.frames == 1);
    CHECK(sum_of(pulse) == doctest::Approx(2.0).epsilon(0.001));
    CHECK(pulse.sample(0) == doctest::Approx(2.0));
}

TEST_CASE("the shortest contact is never shorter than one sample") {
    for (double rate : {8000.0, 44100.0, 48000.0, 192000.0}) {
        const auto pulse = modal::make_pulse(1.0, 0.001, 1e6, rate);
        CHECK(pulse.frames >= 1);
        CHECK(sum_of(pulse) == doctest::Approx(1.0).epsilon(0.001));
    }
}

TEST_CASE("contact time follows Hertz: a harder hit is a shorter contact") {
    const double slow = modal::contact_seconds(0.15, 0.5);
    const double fast = modal::contact_seconds(0.15, 8.0);
    CHECK(fast < slow);
    // t_c is proportional to v^(-1/5), so sixteen times the velocity is
    // 16^0.2 = 1.741 times shorter.
    CHECK(slow / fast == doctest::Approx(std::pow(16.0, 0.2)).epsilon(0.001));
}

TEST_CASE("contact time is clamped at both ends") {
    CHECK(modal::contact_seconds(0.15, 1e9) == doctest::Approx(modal::kMinContactSeconds));
    CHECK(modal::contact_seconds(20.0, 1e-9) == doctest::Approx(modal::kMaxContactSeconds));
    CHECK(modal::contact_seconds(0.15, 0.0) > 0.0);
}

TEST_CASE("a softer material has a longer contact at the same velocity") {
    CHECK(modal::contact_seconds(1.2, 2.0) > modal::contact_seconds(0.08, 2.0));
}

TEST_CASE("higher velocity produces a higher spectral centroid") {
    // The gate the whole engine rests on. Equal impulse at every velocity, so
    // the only thing that can move the centroid is the contact time.
    modal::Model model;
    for (int i = 0; i < 16; ++i) {
        model.modes.push_back({1180.0 * (1.0 + 2.3 * i), 0.6, 1.0 / (1.0 + 0.8 * i)});
    }

    double previous = 0.0;
    for (double velocity : {0.5, 2.0, 8.0}) {
        modal::Bank bank;
        modal::bank_set(bank, model, kRate, modal::kMaxModes, nullptr);
        const auto pulse = modal::make_pulse(1.0, 0.12, velocity, kRate);
        std::vector<float> x(8192, 0.0f), y(8192, 0.0f);
        modal::pulse_render(pulse, 0, x.data(), 8192);
        modal::bank_process(bank, x.data(), y.data(), 8192);

        // Normalised, so this cannot pass on loudness alone.
        double peak = 0.0;
        for (float sample : y) peak = std::max(peak, static_cast<double>(std::fabs(sample)));
        for (float& sample : y) sample = static_cast<float>(sample / peak);

        const double measured = centroid(y);
        CHECK(measured > previous);
        previous = measured;
    }
}

TEST_CASE("velocity still separates when the contact is only samples wide") {
    // The week one gate caught this. Steel at 2 m/s is a 3.4 sample contact
    // and at 8 m/s a 2.5 sample one; rounding both to a whole number made
    // them the same pulse, and the two velocities came out bit for bit
    // identical — the exact failure the contact time model exists to avoid,
    // hidden at precisely the velocities a game spends its time at.
    const double steel = 0.08;
    const auto slow = modal::make_pulse(1.0, steel, 2.0, kRate);
    const auto fast = modal::make_pulse(1.0, steel, 8.0, kRate);
    CHECK(slow.width < 4.0);
    CHECK(fast.width < 3.0);
    CHECK(slow.width > fast.width);

    std::vector<float> a(64, 0.0f), b(64, 0.0f);
    modal::pulse_render(slow, 0, a.data(), 64);
    modal::pulse_render(fast, 0, b.data(), 64);
    bool differs = false;
    for (int n = 0; n < 64; ++n) {
        if (a[n] != b[n]) differs = true;
    }
    CHECK(differs);

    // And the narrower one is the brighter one.
    CHECK(centroid(b) > centroid(a));
}

TEST_CASE("the pulse narrows smoothly, with no steps") {
    // A step in width is a step in timbre, and a row of identical impacts
    // across a velocity ramp is what that sounds like.
    //
    // Above roughly 10 m/s on steel the contact time hits its 0.05 ms floor
    // and the width stops moving. That is the clamp doing its job rather
    // than the quantisation coming back, so the ramp is checked as never
    // widening, and as strictly narrowing while it is still off the floor.
    const double floor_width = modal::kMinContactSeconds * kRate;
    double previous = 1e9;
    int narrowed = 0;
    for (int i = 0; i <= 40; ++i) {
        const double velocity = 0.25 * std::pow(64.0, i / 40.0);
        const auto pulse = modal::make_pulse(1.0, 0.08, velocity, kRate);
        CHECK(pulse.width <= previous);
        if (previous > floor_width * 1.001 && pulse.width > floor_width * 1.001) {
            CHECK(pulse.width < previous);
            ++narrowed;
        }
        previous = pulse.width;
    }
    // Most of the ramp is off the floor, or this case proves nothing.
    CHECK(narrowed > 25);
    CHECK(previous == doctest::Approx(floor_width));
}

TEST_CASE("rendering past the end of a pulse writes silence, not garbage") {
    const auto pulse = modal::make_pulse(1.0, 0.15, 1.0, kRate);
    std::vector<float> out(pulse.frames + 64, 1.0f);
    const int written = modal::pulse_render(pulse, 0, out.data(), static_cast<int>(out.size()));
    CHECK(written == pulse.frames);
    for (size_t n = pulse.frames; n < out.size(); ++n) CHECK(out[n] == 0.0f);
}
