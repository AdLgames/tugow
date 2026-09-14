// The bank is checked against the closed form rather than against itself.
// An impulse response that is nearly right sounds like a different material.
#include "doctest.h"

#include <cmath>
#include <vector>

#include "modal/bank.h"
#include "modal/model.h"

namespace {

constexpr double kRate = 48000.0;

modal::Model one_mode(double f, double tau, double a) {
    modal::Model model;
    model.modes.push_back({f, tau, a});
    return model;
}

std::vector<float> strike(modal::Bank& bank, int frames) {
    std::vector<float> x(frames, 0.0f);
    std::vector<float> y(frames, 0.0f);
    x[0] = 1.0f;
    modal::bank_process(bank, x.data(), y.data(), frames);
    return y;
}

}  // namespace

TEST_CASE("one mode matches the analytic impulse response") {
    // Against the poles the filter actually has, not the ones it was asked
    // for. Rounding a1 to float32 moves omega by about 8e-8 radians per
    // sample, which is nothing on its own and a third of a milliradian of
    // phase by the four thousandth sample. Comparing against exact double
    // poles measures that drift rather than whether the recursion is right,
    // and the recursion is what this case is for. The coefficients get their
    // own case below.
    const double f = 1245.3, tau = 0.5, a = 1.0;
    modal::Bank bank;
    modal::bank_set(bank, one_mode(f, tau, a), kRate, modal::kMaxModes, nullptr);
    const auto y = strike(bank, 4096);

    const double r = std::sqrt(-static_cast<double>(bank.a2[0]));
    const double omega = std::acos(static_cast<double>(bank.a1[0]) / (2.0 * r));
    const double b0 = static_cast<double>(bank.b0[0]);

    // h[n] = b0 * r^n * sin((n+1) * omega) / sin(omega)
    for (int n = 0; n < 4096; ++n) {
        const double expected = b0 * std::pow(r, n) * std::sin((n + 1) * omega) / std::sin(omega);
        CHECK(y[n] == doctest::Approx(expected).epsilon(1e-4));
    }
}

TEST_CASE("the poles land where the mode asked them to") {
    // The other half of the case above: float32 coefficients are close
    // enough that neither the pitch nor the decay is audibly wrong.
    const double f = 1245.3, tau = 0.5;
    modal::Bank bank;
    modal::bank_set(bank, one_mode(f, tau, 1.0), kRate, modal::kMaxModes, nullptr);

    const double r = std::sqrt(-static_cast<double>(bank.a2[0]));
    const double omega = std::acos(static_cast<double>(bank.a1[0]) / (2.0 * r));
    CHECK(omega * kRate / (2.0 * M_PI) == doctest::Approx(f).epsilon(1e-6));
    CHECK(-1.0 / (std::log(r) * kRate) == doctest::Approx(tau).epsilon(1e-4));
}

TEST_CASE("the response peaks at the mode's amplitude") {
    // This is what keeps the relative level of the modes the same as in the
    // file. Get b0 wrong and every model comes out balanced differently.
    for (double a : {1.0, 0.5, 0.25}) {
        modal::Bank bank;
        modal::bank_set(bank, one_mode(1000.0, 0.5, a), kRate, modal::kMaxModes, nullptr);
        const auto y = strike(bank, 8192);
        double peak = 0.0;
        for (float sample : y) peak = std::max(peak, static_cast<double>(std::fabs(sample)));
        CHECK(peak == doctest::Approx(a).epsilon(0.01));
    }
}

TEST_CASE("the measured decay matches the tau it was given, within 2 percent") {
    for (double tau : {0.05, 0.25, 1.0, 4.0}) {
        modal::Bank bank;
        modal::bank_set(bank, one_mode(1000.0, tau, 1.0), kRate, modal::kMaxModes, nullptr);
        const auto y = strike(bank, static_cast<int>(kRate * tau * 3.0));

        // Peak of the envelope in the first cycle, and again after one tau.
        auto peak_near = [&](int centre) {
            const int half = static_cast<int>(kRate / 1000.0);
            double peak = 0.0;
            for (int n = std::max(0, centre - half);
                 n < std::min<int>(y.size(), centre + half); ++n) {
                peak = std::max(peak, static_cast<double>(std::fabs(y[n])));
            }
            return peak;
        };
        const double start = peak_near(static_cast<int>(kRate / 4000.0));
        const double later = peak_near(static_cast<int>(kRate * tau));
        const double measured = -1.0 / std::log(later / start);
        CHECK(measured == doctest::Approx(1.0).epsilon(0.02));
    }
}

TEST_CASE("modes are truncated from the quiet end") {
    modal::Model model;
    model.modes.push_back({500.0, 0.5, 1.0});
    model.modes.push_back({1500.0, 0.5, 0.5});
    model.modes.push_back({2500.0, 0.5, 0.25});

    modal::Bank all;
    modal::bank_set(all, model, kRate, modal::kMaxModes, nullptr);
    CHECK(all.active_modes == 3);

    modal::Bank fewer;
    modal::bank_set(fewer, model, kRate, 2, nullptr);
    CHECK(fewer.active_modes == 2);
    // The loudest mode survives, which is only true because the loader sorts.
    CHECK(fewer.b0[0] == doctest::Approx(all.b0[0]));
}

TEST_CASE("a bank never keeps more modes than a voice has room for") {
    modal::Model model;
    for (int i = 0; i < modal::kMaxModesInFile; ++i) {
        model.modes.push_back({200.0 + 50.0 * i, 0.5, 1.0 / (1.0 + i)});
    }
    modal::Bank bank;
    modal::bank_set(bank, model, kRate, 10000, nullptr);
    CHECK(bank.active_modes == modal::kMaxModes);
}

TEST_CASE("unused slots are silent, so a reused voice carries nothing over") {
    modal::Model wide;
    for (int i = 0; i < 8; ++i) wide.modes.push_back({500.0 + 300.0 * i, 0.5, 1.0});
    modal::Bank bank;
    modal::bank_set(bank, wide, kRate, modal::kMaxModes, nullptr);
    strike(bank, 1024);

    modal::bank_set(bank, one_mode(1000.0, 0.5, 1.0), kRate, modal::kMaxModes, nullptr);
    CHECK(bank.active_modes == 1);
    for (uint32_t k = 1; k < modal::kMaxModes; ++k) {
        CHECK(bank.b0[k] == 0.0f);
        CHECK(bank.y1[k] == 0.0f);
    }
}

TEST_CASE("strike gains scale the modes they belong to") {
    modal::Model model;
    model.modes.push_back({1000.0, 0.5, 1.0});
    const double gains[] = {0.25};
    modal::Bank bank;
    modal::bank_set(bank, model, kRate, modal::kMaxModes, gains);
    const auto y = strike(bank, 4096);
    double peak = 0.0;
    for (float sample : y) peak = std::max(peak, static_cast<double>(std::fabs(sample)));
    CHECK(peak == doctest::Approx(0.25).epsilon(0.01));
}

TEST_CASE("the finiteness check notices a poisoned bank") {
    modal::Bank bank;
    modal::bank_set(bank, one_mode(1000.0, 0.5, 1.0), kRate, modal::kMaxModes, nullptr);
    CHECK(modal::bank_is_finite(bank));
    bank.y1[0] = std::nanf("");
    CHECK_FALSE(modal::bank_is_finite(bank));
}
