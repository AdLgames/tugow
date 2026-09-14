// Modal model: an ordered list of (frequency, decay, amplitude) triples.
//
// Loading and validation live off the audio thread, so this half of the
// library is allowed the STL. Nothing in here is called from _mix.
#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace modal {

// One damped sinusoid. See BUILD_PLAN section 1.1.
struct Mode {
    double f = 0.0;    // Hz
    double tau = 0.0;  // 1/e decay time, seconds
    double a = 0.0;    // linear amplitude, normalised so the loudest is 1
};

// A strike position and the per-mode gains measured there.
struct StrikePosition {
    double u = 0.0, v = 0.0;
    std::vector<double> gains;
};

// Per-material excitation constants.
struct Material {
    double contact_time_ref_ms = 0.15;
    double roughness = 0.3;
    double rolling_gain = 0.6;
    double scrape_gain = 1.0;
};

// Biquad coefficients for one mode at one sample rate. Computed in double
// and narrowed once: r sits very close to 1 for long decays and the
// precision matters by the time it has been squared into a2.
struct Coefficients {
    float b0 = 0.0f, a1 = 0.0f, a2 = 0.0f;
};

// Limits from BUILD_PLAN section 4.2.
constexpr int kMaxModesInFile = 256;
constexpr double kMinFrequency = 20.0;
constexpr double kNyquistFraction = 0.45;
constexpr double kMinTau = 0.001;
constexpr double kMaxTau = 10.0;

struct Model {
    std::string name;
    std::string source;
    double fit_quality = 0.0;
    std::vector<Mode> modes;
    std::vector<StrikePosition> strike_positions;
    Material material;

    // Coefficients for the current sample rate. Never stored in the file: a
    // model fitted at 48 kHz has to work at 44.1 kHz.
    std::vector<Coefficients> coefficients(double sample_rate) const;
};

// What happened during a load. Modes outside the usable band are dropped
// with a warning rather than failing the load, so a 48 kHz model still opens
// at 44.1 kHz; anything that makes the file meaningless is an error.
struct LoadResult {
    bool ok = false;
    std::string error;
    std::vector<std::string> warnings;
    Model model;
};

LoadResult load_from_string(const std::string& json, double sample_rate);
LoadResult load_from_file(const std::string& path, double sample_rate);

// Coefficients for a single mode. Exposed for tests, which check the
// recursion against the analytic impulse response.
Coefficients coefficients_for(const Mode& mode, double sample_rate);

}  // namespace modal
