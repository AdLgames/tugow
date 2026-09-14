// The fitter is tested against signals it cannot argue with: modes are put
// in, and the same modes have to come back out. A recording tells you the
// result sounds plausible; only a synthesised signal tells you the numbers
// are right, because only there is the right answer known.
#include "doctest.h"

#include <algorithm>
#include <cmath>
#include <random>
#include <vector>

#include "fitter.h"
#include "modal/bank.h"
#include "modal/model.h"

namespace {

constexpr int kRate = 48000;

struct Ingredient {
    double f, tau, a;
};

// A struck object, built by hand rather than by the engine, so a fault in
// the resonator bank cannot cancel out against a fault in the fitter.
modal::Clip synthesise(const std::vector<Ingredient>& modes, double seconds, double noise = 0.0,
                       unsigned seed = 1) {
    modal::Clip clip;
    clip.sample_rate = kRate;
    const int frames = static_cast<int>(seconds * kRate);
    clip.samples.assign(frames, 0.0f);
    for (const Ingredient& mode : modes) {
        const double omega = 2.0 * M_PI * mode.f / kRate;
        for (int n = 0; n < frames; ++n) {
            const double t = static_cast<double>(n) / kRate;
            clip.samples[n] += static_cast<float>(mode.a * std::exp(-t / mode.tau) *
                                                  std::sin(omega * n));
        }
    }
    if (noise > 0.0) {
        std::mt19937 rng(seed);
        std::normal_distribution<double> gaussian(0.0, noise);
        for (float& sample : clip.samples) sample += static_cast<float>(gaussian(rng));
    }
    // A quarter second of silence in front, so the onset detector has
    // something to find rather than starting on sample zero by luck.
    clip.samples.insert(clip.samples.begin(), kRate / 4, 0.0f);
    return clip;
}

// The fitted mode nearest a frequency, or nothing.
const modal::Mode* nearest(const modal::Model& model, double f) {
    const modal::Mode* best = nullptr;
    double closest = 1e9;
    for (const modal::Mode& mode : model.modes) {
        const double distance = std::abs(mode.f - f);
        if (distance < closest) {
            closest = distance;
            best = &mode;
        }
    }
    return best;
}

}  // namespace

TEST_CASE("a single mode comes back with the frequency and decay it went in with") {
    const modal::Clip clip = synthesise({{1245.3, 0.8, 1.0}}, 2.5);
    const modal::FitReport report = modal::fit(clip, {});
    REQUIRE(report.ok);
    REQUIRE(report.model.modes.size() >= 1);

    const modal::Mode* mode = nearest(report.model, 1245.3);
    REQUIRE(mode != nullptr);
    CHECK(mode->f == doctest::Approx(1245.3).epsilon(0.005));
    CHECK(mode->tau == doctest::Approx(0.8).epsilon(0.10));
    CHECK(report.fit_quality > 0.9);
}

TEST_CASE("several modes come back, in the right order of loudness") {
    const std::vector<Ingredient> truth = {
        {800.0, 1.2, 1.00}, {1930.0, 0.7, 0.55}, {3410.0, 0.4, 0.30}, {5120.0, 0.25, 0.18},
    };
    const modal::Clip clip = synthesise(truth, 3.0);
    const modal::FitReport report = modal::fit(clip, {});
    REQUIRE(report.ok);
    CHECK(report.model.modes.size() >= 4);

    for (const Ingredient& expected : truth) {
        const modal::Mode* mode = nearest(report.model, expected.f);
        REQUIRE(mode != nullptr);
        CHECK(mode->f == doctest::Approx(expected.f).epsilon(0.005));
        CHECK(mode->tau == doctest::Approx(expected.tau).epsilon(0.15));
    }

    // The loader's invariant, produced rather than fixed up afterwards.
    for (size_t i = 1; i < report.model.modes.size(); ++i) {
        CHECK(report.model.modes[i - 1].a >= report.model.modes[i].a);
    }
    CHECK(report.model.modes.front().a == doctest::Approx(1.0));

    // And the loudest fitted mode is the loudest mode that went in.
    CHECK(report.model.modes.front().f == doctest::Approx(800.0).epsilon(0.01));
}

TEST_CASE("what the fitter writes is what the loader accepts") {
    // The two halves are written against the same spec and could drift
    // apart; a fitted model that its own loader rejects is the worst
    // version of that.
    const modal::Clip clip = synthesise({{700.0, 1.0, 1.0}, {2150.0, 0.6, 0.5}}, 2.5);
    const modal::FitReport report = modal::fit(clip, {});
    REQUIRE(report.ok);

    std::string json = "{\"format\":\"modal\",\"version\":1,\"name\":\"t\",\"modes\":[";
    for (size_t i = 0; i < report.model.modes.size(); ++i) {
        if (i) json += ",";
        json += "{\"f\":" + std::to_string(report.model.modes[i].f) +
                ",\"tau\":" + std::to_string(report.model.modes[i].tau) +
                ",\"a\":" + std::to_string(report.model.modes[i].a) + "}";
    }
    json += "]}";
    const modal::LoadResult loaded = modal::load_from_string(json, kRate);
    CHECK(loaded.ok);
    CHECK(loaded.warnings.empty());
}

TEST_CASE("a decay is measured, not assumed") {
    // Same frequency, four different decay times. If the fit were reading
    // anything but the envelope these would all come back the same.
    for (double tau : {0.15, 0.5, 1.5, 3.0}) {
        const modal::Clip clip = synthesise({{1500.0, tau, 1.0}}, tau * 3.0 + 0.5);
        const modal::FitReport report = modal::fit(clip, {});
        REQUIRE(report.ok);
        const modal::Mode* mode = nearest(report.model, 1500.0);
        REQUIRE(mode != nullptr);
        CHECK(mode->tau == doctest::Approx(tau).epsilon(0.15));
    }
}

TEST_CASE("noise is rejected rather than fitted") {
    modal::Clip clip;
    clip.sample_rate = kRate;
    clip.samples.assign(kRate, 0.0f);
    std::mt19937 rng(7);
    std::normal_distribution<double> gaussian(0.0, 0.2);
    for (float& sample : clip.samples) sample = static_cast<float>(gaussian(rng));

    const modal::FitReport report = modal::fit(clip, {});
    // Either nothing survives, or so little does that the warning fires. A
    // confident model built out of white noise is the failure to avoid.
    if (report.ok) {
        CHECK(report.model.modes.size() < 4);
        bool warned = false;
        for (const std::string& warning : report.warnings) {
            if (warning.find("may not be modal") != std::string::npos) warned = true;
        }
        CHECK(warned);
    }
}

TEST_CASE("a mode survives being buried in noise") {
    const modal::Clip clip = synthesise({{1200.0, 1.0, 1.0}}, 2.5, 0.01);
    const modal::FitReport report = modal::fit(clip, {});
    REQUIRE(report.ok);
    const modal::Mode* mode = nearest(report.model, 1200.0);
    REQUIRE(mode != nullptr);
    CHECK(mode->f == doctest::Approx(1200.0).epsilon(0.01));
}

TEST_CASE("a near-degenerate pair is merged into one mode") {
    // Two modes 0.7% apart are a near-degenerate pair, not two modes, and
    // keeping both spends the mode budget twice on the same thing. They have
    // to be far enough apart for the window to see two of them: 55 Hz at
    // 8 kHz is resolvable and inside the 1% merge tolerance.
    const modal::Clip clip = synthesise({{8000.0, 1.0, 1.0}, {8055.0, 1.0, 1.0}}, 2.5);
    const modal::FitReport report = modal::fit(clip, {});
    REQUIRE(report.ok);
    int near = 0;
    for (const modal::Mode& mode : report.model.modes) {
        if (mode.f > 7900.0 && mode.f < 8160.0) ++near;
    }
    CHECK(near == 1);
    // At the amplitude-weighted middle of the two, not at one of them.
    CHECK(report.model.modes.front().f == doctest::Approx(8027.5).epsilon(0.002));
}

TEST_CASE("two modes far enough apart stay two modes") {
    const modal::Clip clip = synthesise({{8000.0, 1.0, 1.0}, {8400.0, 1.0, 1.0}}, 2.5);
    const modal::FitReport report = modal::fit(clip, {});
    REQUIRE(report.ok);
    CHECK(report.model.modes.size() == 2);
    CHECK(nearest(report.model, 8000.0)->f == doctest::Approx(8000.0).epsilon(0.001));
    CHECK(nearest(report.model, 8400.0)->f == doctest::Approx(8400.0).epsilon(0.001));
}

TEST_CASE("an unresolvable pair is refused rather than guessed at") {
    // 8 Hz apart is far inside the window's resolving power, so the two
    // modes arrive as one peak whose magnitude beats at their difference
    // frequency. That is not an exponential decay, and the honest answer is
    // to say so: an earlier version of this fitter produced five confident
    // modes here, none of which were in the signal.
    //
    // This is the limitation section 5.4 of the plan hands to the matrix
    // pencil method in v2. It is a limit of STFT peak picking, not a bug.
    const modal::Clip clip = synthesise({{2000.0, 1.0, 1.0}, {2008.0, 1.0, 0.9}}, 3.0);
    const modal::FitReport report = modal::fit(clip, {});
    if (report.ok) {
        // If anything does survive it must at least be near the pair, not a
        // spread of phantoms either side of it.
        for (const modal::Mode& mode : report.model.modes) {
            CHECK(mode.f > 1980.0);
            CHECK(mode.f < 2030.0);
        }
    } else {
        CHECK(report.error.find("may not be modal") != std::string::npos);
    }
}

TEST_CASE("a clean signal produces no phantom modes") {
    // The count matters as much as the values. Four modes in should be four
    // candidates out; window leakage that decays at a mode's own rate fits a
    // perfect exponential and passes every test after it, so it has to be
    // stopped at the picking stage or not at all.
    const modal::Clip clip = synthesise(
        {{800.0, 1.2, 1.0}, {1930.0, 0.7, 0.55}, {3410.0, 0.4, 0.30}, {5120.0, 0.25, 0.18}}, 3.0);
    const modal::FitReport report = modal::fit(clip, {});
    REQUIRE(report.ok);
    CHECK(report.candidates.size() == 4);
    CHECK(report.model.modes.size() == 4);
    for (const modal::Candidate& candidate : report.candidates) {
        CHECK(candidate.r_squared > 0.999);
    }
}

TEST_CASE("the mode count is capped where it was asked to be") {
    std::vector<Ingredient> many;
    for (int i = 0; i < 20; ++i) many.push_back({400.0 + 411.0 * i, 0.8, 1.0 / (1.0 + 0.3 * i)});
    const modal::Clip clip = synthesise(many, 2.5);

    modal::FitSettings settings;
    settings.max_modes = 6;
    const modal::FitReport report = modal::fit(clip, settings);
    REQUIRE(report.ok);
    CHECK(report.model.modes.size() <= 6);
    // The six kept are the six loudest, which is what makes truncation safe.
    CHECK(report.model.modes.front().f == doctest::Approx(400.0).epsilon(0.01));
}

TEST_CASE("the onset is found past leading silence") {
    modal::Clip clip = synthesise({{1000.0, 0.5, 1.0}}, 1.5);
    const int onset = modal::find_onset(clip, -40.0);
    // A quarter second of silence was prepended, less the 128 sample backoff.
    CHECK(onset > kRate / 4 - 400);
    CHECK(onset < kRate / 4 + 400);
}

TEST_CASE("unusable input is refused with a reason, not a bad model") {
    modal::Clip empty;
    empty.sample_rate = kRate;
    empty.samples.assign(1000, 0.0f);
    const modal::FitReport tiny = modal::fit(empty, {});
    CHECK_FALSE(tiny.ok);
    CHECK_FALSE(tiny.error.empty());

    modal::Clip silent;
    silent.sample_rate = kRate;
    silent.samples.assign(kRate, 0.0f);
    CHECK_FALSE(modal::fit(silent, {}).ok);

    modal::Clip rateless;
    rateless.samples.assign(kRate, 0.1f);
    CHECK_FALSE(modal::fit(rateless, {}).ok);
}

TEST_CASE("every rejected candidate says why it was rejected") {
    const modal::Clip clip = synthesise({{900.0, 1.0, 1.0}, {2700.0, 0.5, 0.4}}, 2.5, 0.005);
    const modal::FitReport report = modal::fit(clip, {});
    REQUIRE(report.ok);
    CHECK(report.candidates.size() >= report.model.modes.size());
    for (const modal::Candidate& candidate : report.candidates) {
        if (!candidate.rejected.empty()) CHECK(candidate.rejected.size() > 4);
    }
}

TEST_CASE("what is fitted is the strike, not the object alone") {
    // A mode is only as loud in the recording as the strike made it, and a
    // soft strike is a long contact, which is a low-passed excitation. So a
    // model fitted from a gentle tap comes out dull, and it is not the
    // fitter being wrong — it is the recording.
    //
    // Locked down here because it looks like a bug and is not, and because
    // it is the reason the recording guidance says to hit the object hard
    // with something small.
    auto high_mode_amplitude = [](double contact_ms) {
        std::vector<Ingredient> object = {
            {1000.0, 1.0, 1.0}, {3000.0, 0.6, 0.5}, {7000.0, 0.35, 0.4}};
        modal::Clip clip;
        clip.sample_rate = kRate;
        const int frames = kRate * 2;
        clip.samples.assign(frames, 0.0f);
        // Struck with a Hann pulse of the given width rather than a spike.
        const int width = std::max(1, static_cast<int>(contact_ms * 1e-3 * kRate));
        for (const Ingredient& mode : object) {
            const double omega = 2.0 * M_PI * mode.f / kRate;
            for (int n = 0; n < frames; ++n) {
                double excitation = 0.0;
                for (int j = 0; j < width && j <= n; ++j) {
                    const double w = width == 1 ? 1.0
                                                : 0.5 * (1.0 - std::cos(2.0 * M_PI * j / width));
                    excitation += w * std::sin(omega * (n - j));
                }
                const double t = static_cast<double>(n) / kRate;
                clip.samples[n] +=
                    static_cast<float>(mode.a * std::exp(-t / mode.tau) * excitation / width);
            }
        }
        clip.samples.insert(clip.samples.begin(), kRate / 4, 0.0f);
        const modal::FitReport report = modal::fit(clip, {});
        REQUIRE(report.ok);
        for (const modal::Mode& mode : report.model.modes) {
            if (std::abs(mode.f - 7000.0) < 200.0) return mode.a;
        }
        return -1.0;  // not excited enough to be found at all
    };

    const double hard = high_mode_amplitude(0.05);
    const double soft = high_mode_amplitude(1.0);
    CHECK(hard > 0.2);
    // A millisecond of contact does not merely make the 7 kHz mode quieter,
    // it puts it under the picking floor: the fit comes back with one mode
    // where the object has three. Fit from a soft strike and the model is
    // missing the part of the object that makes it sound like itself.
    CHECK(soft < hard);
}

TEST_CASE("verification scores a good fit better than a wrong one") {
    const modal::Clip clip = synthesise({{1100.0, 1.0, 1.0}, {2650.0, 0.6, 0.5}}, 2.5);
    const modal::FitReport report = modal::fit(clip, {});
    REQUIRE(report.ok);

    const modal::Verification good = modal::verify(clip, report.model, {});

    // The same model with every frequency moved a fifth. It is still a
    // plausible object; it is not this one.
    modal::Model wrong = report.model;
    for (modal::Mode& mode : wrong.modes) mode.f *= 1.5;
    const modal::Verification bad = modal::verify(clip, wrong, {});

    CHECK(good.spectral_convergence_db < bad.spectral_convergence_db);
}
