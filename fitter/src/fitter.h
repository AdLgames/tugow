// WAV in, modal model out. Steps 1 to 10 of build plan section 5.1.
//
// Every stage is separately callable so the tests can drive them against
// synthesised signals whose right answer is known. A fit is only trustworthy
// if you can show it recovering something you put in yourself.
#pragma once

#include <string>
#include <vector>

#include "modal/model.h"

namespace modal {

struct FitSettings {
    // Analysis runs at the file's own sample rate rather than resampling to
    // 48 kHz as the plan has it. Frequencies are absolute, so nothing needs
    // converting, and a resampler in front of the analysis would low-pass
    // the decay tail that the whole fit is measuring.
    int window = 4096;
    int hop = 512;
    int zero_pad = 2;        // 2x, so an 8192-point transform on a 4096 window
    int peak_frame = 2;      // past the broadband click, before the decay
    double peak_floor_db = -65.0;
    double track_floor_db = -75.0;
    int max_lost_frames = 3;
    int min_tracked_frames = 8;
    double min_r_squared = 0.80;
    // How far apart two peaks must be to be two peaks, in units of the
    // window's own bin spacing. The Blackman-Harris main lobe is eight bins
    // wide, so anything inside four bins of a louder peak is that peak's
    // shoulder rather than a mode of its own. Without this, each real mode
    // contributes a handful of neighbours that decay at its rate — and so
    // fit a perfect exponential and pass every test downstream.
    double min_peak_separation_bins = 4.0;
    double merge_tolerance = 0.01;  // 1% in frequency
    int max_modes = 32;
    double onset_floor_db = -40.0;
};

// One candidate mode as it comes out of the analysis, with the evidence for
// it. The evidence is kept so a rejection can say why.
struct Candidate {
    double f = 0.0;
    double a = 0.0;
    double tau = 0.0;
    double r_squared = 0.0;
    int tracked_frames = 0;
    std::string rejected;  // empty when kept
};

struct FitReport {
    bool ok = false;
    std::string error;
    std::vector<std::string> warnings;
    std::vector<Candidate> candidates;  // every one, kept and rejected
    Model model;
    double fit_quality = 0.0;  // amplitude-weighted mean R squared
    int sample_rate = 0;
};

// Audio as the fitter wants it: mono, float, one strike.
struct Clip {
    std::vector<float> samples;
    int sample_rate = 0;
};

bool load_wav(const std::string& path, Clip& out, std::string& error);

// Step 2. Returns the index of the first sample past the onset backoff.
int find_onset(const Clip& clip, double floor_db);

// Steps 3 to 10.
FitReport fit(const Clip& clip, const FitSettings& settings);

// How well a model matches the clip it came from: resynthesise and compare.
struct Verification {
    double spectral_convergence_db = 0.0;  // mean log-magnitude distance
    double decay_rms_error_db = 0.0;
    std::vector<float> resynthesis;
    std::vector<float> difference;
};

Verification verify(const Clip& clip, const Model& model, const FitSettings& settings);

}  // namespace modal
