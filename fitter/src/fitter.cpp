#include "fitter.h"

#include <algorithm>
#include <cmath>
#include <map>

#include "fft.h"
#include "modal/bank.h"

#define DR_WAV_IMPLEMENTATION
#include "dr_wav.h"

namespace modal {
namespace {

double db(double linear) { return 20.0 * std::log10(std::max(linear, 1e-12)); }

// Four-term Blackman-Harris, not the Hann the build plan specifies.
//
// Hann's first sidelobe is 31 dB down, and the plan picks peaks at 65 dB
// down — so every real mode is surrounded by leakage well above the
// threshold, and that leakage decays at the mode's own rate, which means it
// fits a perfect exponential and is indistinguishable from a real mode by
// any test downstream. Measured: four synthetic modes produced nineteen
// candidates, and a cluster of sidelobes merged into a phantom louder than
// the fundamental.
//
// Blackman-Harris puts the sidelobes 92 dB down, below the picking floor,
// at the cost of a main lobe twice as wide. That trade is the right way
// round here: the fitter needs to know a peak is real more than it needs to
// separate two peaks a few hertz apart, and §5.4 already concedes closely
// spaced modes to the matrix pencil method in v2.
std::vector<float> analysis_window(int n) {
    std::vector<float> w(n);
    const double a0 = 0.35875, a1 = 0.48829, a2 = 0.14128, a3 = 0.01168;
    for (int i = 0; i < n; ++i) {
        const double t = 2.0 * M_PI * i / (n - 1);
        w[i] = static_cast<float>(a0 - a1 * std::cos(t) + a2 * std::cos(2.0 * t) -
                                  a3 * std::cos(3.0 * t));
    }
    return w;
}

// One STFT frame's magnitude spectrum, zero-padded.
struct Frame {
    std::vector<float> magnitude;
    double seconds = 0.0;
};

std::vector<Frame> analyse(const Clip& clip, const FitSettings& settings, int from) {
    const int fft_size = settings.window * settings.zero_pad;
    const std::vector<float> window = analysis_window(settings.window);
    std::vector<Frame> frames;

    double loudest = 0.0;
    for (int start = from; start + settings.window <= static_cast<int>(clip.samples.size());
         start += settings.hop) {
        std::vector<float> block(fft_size, 0.0f);
        for (int i = 0; i < settings.window; ++i) block[i] = clip.samples[start + i] * window[i];
        Frame frame;
        frame.seconds = static_cast<double>(start - from) / clip.sample_rate;
        fft_magnitude(block, frame.magnitude);
        for (float m : frame.magnitude) loudest = std::max(loudest, static_cast<double>(m));
        frames.push_back(frame);

        // Step 3: stop once the signal has gone.
        double peak = 0.0;
        for (float m : frame.magnitude) peak = std::max(peak, static_cast<double>(m));
        if (loudest > 0.0 && db(peak / loudest) < settings.track_floor_db && frames.size() > 4) {
            break;
        }
    }
    return frames;
}

// Step 4. Parabolic interpolation on the log magnitude, which is what makes
// a 5.9 Hz bin spacing good enough to place a mode to a fraction of a hertz.
bool refine_peak(const std::vector<float>& magnitude, int k, double bin_hz, double& f,
                 double& a) {
    if (k <= 0 || k + 1 >= static_cast<int>(magnitude.size())) return false;
    const double alpha = std::log(std::max<double>(magnitude[k - 1], 1e-20));
    const double beta = std::log(std::max<double>(magnitude[k], 1e-20));
    const double gamma = std::log(std::max<double>(magnitude[k + 1], 1e-20));
    const double denominator = alpha - 2.0 * beta + gamma;
    if (std::abs(denominator) < 1e-20) return false;
    const double delta = 0.5 * (alpha - gamma) / denominator;
    if (!(delta >= -0.5 && delta <= 0.5)) return false;
    f = (k + delta) * bin_hz;
    a = std::exp(beta - 0.25 * (alpha - gamma) * delta);
    return true;
}

// Step 6. Least squares on ln(mag) against time, with the R squared that
// says whether it was an exponential decay at all.
bool fit_decay(const std::vector<double>& seconds, const std::vector<double>& magnitude,
               double& tau, double& amplitude, double& r_squared) {
    const size_t n = seconds.size();
    if (n < 2) return false;
    std::vector<double> y(n);
    for (size_t i = 0; i < n; ++i) y[i] = std::log(std::max(magnitude[i], 1e-20));

    double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
    for (size_t i = 0; i < n; ++i) {
        sx += seconds[i];
        sy += y[i];
        sxx += seconds[i] * seconds[i];
        sxy += seconds[i] * y[i];
    }
    const double denominator = n * sxx - sx * sx;
    if (std::abs(denominator) < 1e-20) return false;
    const double slope = (n * sxy - sx * sy) / denominator;
    const double intercept = (sy - slope * sx) / n;
    if (slope >= 0.0) return false;  // not decaying

    const double mean = sy / n;
    double residual = 0.0, total = 0.0;
    for (size_t i = 0; i < n; ++i) {
        const double predicted = intercept + slope * seconds[i];
        residual += (y[i] - predicted) * (y[i] - predicted);
        total += (y[i] - mean) * (y[i] - mean);
    }
    r_squared = total > 0.0 ? 1.0 - residual / total : 0.0;
    tau = -1.0 / slope;
    amplitude = std::exp(intercept);
    return true;
}

}  // namespace

bool load_wav(const std::string& path, Clip& out, std::string& error) {
    unsigned int channels = 0, rate = 0;
    drwav_uint64 frames = 0;
    float* data = drwav_open_file_and_read_pcm_frames_f32(path.c_str(), &channels, &rate, &frames,
                                                          nullptr);
    if (data == nullptr) {
        error = "could not read " + path + " as a WAV";
        return false;
    }
    out.sample_rate = static_cast<int>(rate);
    out.samples.resize(frames);
    // Downmixed, because a modal fit wants one signal and a stereo pair of
    // the same strike is the same signal twice.
    for (drwav_uint64 i = 0; i < frames; ++i) {
        double sum = 0.0;
        for (unsigned int c = 0; c < channels; ++c) sum += data[i * channels + c];
        out.samples[i] = static_cast<float>(sum / channels);
    }
    drwav_free(data, nullptr);
    if (out.samples.empty()) {
        error = path + " contains no audio";
        return false;
    }
    return true;
}

int find_onset(const Clip& clip, double floor_db) {
    double peak = 0.0;
    for (float sample : clip.samples) peak = std::max(peak, static_cast<double>(std::fabs(sample)));
    if (peak <= 0.0) return 0;
    const double threshold = peak * std::pow(10.0, floor_db / 20.0);
    for (size_t i = 0; i < clip.samples.size(); ++i) {
        if (std::fabs(clip.samples[i]) >= threshold) {
            // Backed off, so the transient itself is inside the first frame
            // rather than half cut off by it.
            return static_cast<int>(i) > 128 ? static_cast<int>(i) - 128 : 0;
        }
    }
    return 0;
}

FitReport fit(const Clip& clip, const FitSettings& settings) {
    FitReport report;
    report.sample_rate = clip.sample_rate;
    if (clip.sample_rate <= 0) {
        report.error = "the clip has no sample rate";
        return report;
    }
    if (static_cast<int>(clip.samples.size()) < settings.window * 4) {
        report.error = "the clip is too short to analyse — needs at least " +
                       std::to_string(settings.window * 4) + " samples";
        return report;
    }

    const int onset = find_onset(clip, settings.onset_floor_db);
    const std::vector<Frame> frames = analyse(clip, settings, onset);
    if (static_cast<int>(frames.size()) <= settings.peak_frame) {
        report.error = "the clip decays too quickly to track — fewer than " +
                       std::to_string(settings.peak_frame + 1) + " analysis frames";
        return report;
    }

    const int fft_size = settings.window * settings.zero_pad;
    const double bin_hz = static_cast<double>(clip.sample_rate) / fft_size;
    const std::vector<float>& picking = frames[settings.peak_frame].magnitude;

    double loudest_bin = 0.0;
    for (float m : picking) loudest_bin = std::max(loudest_bin, static_cast<double>(m));
    if (loudest_bin <= 0.0) {
        report.error = "the analysis frame is silent — check the onset";
        return report;
    }

    // Step 4.
    struct Peak {
        int bin;
        double f;
        double a;
    };
    std::vector<Peak> found;
    for (int k = 1; k + 1 < static_cast<int>(picking.size()); ++k) {
        if (!(picking[k] > picking[k - 1] && picking[k] > picking[k + 1])) continue;
        if (db(picking[k] / loudest_bin) <= settings.peak_floor_db) continue;
        double f = 0.0, a = 0.0;
        if (!refine_peak(picking, k, bin_hz, f, a)) continue;
        found.push_back({k, f, a});
    }

    // Loudest first, then keep only peaks that are clear of every peak
    // already kept. Working down from the loudest is what makes a real mode
    // always win against its own leakage.
    std::sort(found.begin(), found.end(), [](const Peak& x, const Peak& y) { return x.a > y.a; });
    const double separation_hz =
        settings.min_peak_separation_bins * clip.sample_rate / settings.window;
    std::vector<Peak> peaks;
    for (const Peak& peak : found) {
        bool shadowed = false;
        for (const Peak& kept_peak : peaks) {
            if (std::abs(peak.f - kept_peak.f) < separation_hz) {
                shadowed = true;
                break;
            }
        }
        if (!shadowed) peaks.push_back(peak);
    }
    if (peaks.empty()) {
        report.error = "no spectral peaks above the floor — this may not be a modal source";
        return report;
    }

    // Step 5. Follow each peak across the frames, allowing it to go missing
    // briefly: a mode passing through a beat can dip below its neighbour for
    // a frame without being gone.
    for (const Peak& peak : peaks) {
        std::vector<double> seconds;
        std::vector<double> magnitude;
        // Anchored to where the peak was found, not re-centred each frame.
        // A mode does not change frequency, and a search that follows the
        // best bin in a moving window walks two bins per frame — over a few
        // hundred frames a leakage peak strolls onto the mode beside it and
        // comes back carrying that mode's amplitude, which is how a sidelobe
        // ends up outranking a fundamental.
        const int anchor = peak.bin;
        int lost = 0;
        for (size_t frame = static_cast<size_t>(settings.peak_frame); frame < frames.size();
             ++frame) {
            const std::vector<float>& spectrum = frames[frame].magnitude;
            int best = -1;
            double best_magnitude = 0.0;
            for (int k = std::max(1, anchor - 2);
                 k <= std::min<int>(anchor + 2, static_cast<int>(spectrum.size()) - 2); ++k) {
                if (spectrum[k] > best_magnitude) {
                    best_magnitude = spectrum[k];
                    best = k;
                }
            }
            if (best < 0 || db(best_magnitude / loudest_bin) < settings.track_floor_db) {
                if (++lost > settings.max_lost_frames) break;
                continue;
            }
            lost = 0;
            seconds.push_back(frames[frame].seconds);
            magnitude.push_back(best_magnitude);
        }

        Candidate candidate;
        candidate.f = peak.f;
        candidate.a = peak.a;
        candidate.tracked_frames = static_cast<int>(seconds.size());

        // Step 7, stated as the reason rather than a silent drop, so a poor
        // fit can be explained rather than guessed at.
        if (candidate.tracked_frames < settings.min_tracked_frames) {
            candidate.rejected = "tracked for only " + std::to_string(candidate.tracked_frames) +
                                 " frames";
            report.candidates.push_back(candidate);
            continue;
        }
        double tau = 0.0, amplitude = 0.0, r_squared = 0.0;
        if (!fit_decay(seconds, magnitude, tau, amplitude, r_squared)) {
            candidate.rejected = "no decay to fit";
            report.candidates.push_back(candidate);
            continue;
        }
        candidate.tau = tau;
        candidate.a = amplitude;
        candidate.r_squared = r_squared;
        if (r_squared < settings.min_r_squared) {
            candidate.rejected = "R squared " + std::to_string(r_squared) + ", not an exponential";
        } else if (tau < kMinTau * 5.0 || tau > kMaxTau) {
            candidate.rejected = "tau " + std::to_string(tau) + " outside the physical range";
        } else if (candidate.f < kMinFrequency || candidate.f > 18000.0) {
            candidate.rejected = "frequency outside 20 to 18000 Hz";
        }
        report.candidates.push_back(candidate);
    }

    std::vector<Candidate> kept;
    for (const Candidate& candidate : report.candidates) {
        if (candidate.rejected.empty()) kept.push_back(candidate);
    }
    if (kept.empty()) {
        report.error = "no mode survived fitting — this source may not be modal";
        return report;
    }

    // Step 8. Two peaks a fraction of a percent apart are one mode split by
    // beating, not two modes, and keeping both spends the mode budget twice
    // on the same thing.
    // Absorbed into the loudest of a group rather than chained along the
    // frequency axis: chaining lets a run of near neighbours walk a long way
    // from where it started, each one only a percent from the last.
    std::sort(kept.begin(), kept.end(), [](const Candidate& x, const Candidate& y) {
        return x.a > y.a;
    });
    std::vector<Candidate> merged;
    for (const Candidate& candidate : kept) {
        Candidate* into = nullptr;
        for (Candidate& accepted : merged) {
            if (std::abs(candidate.f - accepted.f) / accepted.f < settings.merge_tolerance) {
                into = &accepted;
                break;
            }
        }
        if (into == nullptr) {
            merged.push_back(candidate);
            continue;
        }
        const double total = into->a + candidate.a;
        into->tau = (into->tau * into->a + candidate.tau * candidate.a) / total;
        into->f = (into->f * into->a + candidate.f * candidate.a) / total;
        into->r_squared = (into->r_squared * into->a + candidate.r_squared * candidate.a) / total;
        into->a = total;
    }
    if (merged.size() < kept.size()) {
        report.warnings.push_back("merged " + std::to_string(kept.size() - merged.size()) +
                                  " beating partials");
    }

    // Step 9.
    std::sort(merged.begin(), merged.end(), [](const Candidate& x, const Candidate& y) {
        return x.a > y.a;
    });
    if (static_cast<int>(merged.size()) > settings.max_modes) {
        merged.resize(settings.max_modes);
    }
    if (merged.size() < 4) {
        report.warnings.push_back("fewer than 4 usable modes — this source may not be modal");
    }

    // Step 10.
    const double loudest = merged.front().a;
    double weighted_r = 0.0, weight = 0.0;
    for (const Candidate& candidate : merged) {
        Mode mode;
        mode.f = candidate.f;
        mode.tau = std::clamp(candidate.tau, kMinTau, kMaxTau);
        mode.a = candidate.a / loudest;
        report.model.modes.push_back(mode);
        weighted_r += candidate.r_squared * mode.a;
        weight += mode.a;
    }
    report.fit_quality = weight > 0.0 ? weighted_r / weight : 0.0;
    report.model.fit_quality = report.fit_quality;
    report.ok = true;
    return report;
}

Verification verify(const Clip& clip, const Model& model, const FitSettings& settings) {
    Verification out;
    const int onset = find_onset(clip, settings.onset_floor_db);
    const int frames = static_cast<int>(clip.samples.size()) - onset;
    if (frames <= 0) return out;

    // Struck with a single sample, because the fit was taken from the decay
    // and the excitation that produced it is not known.
    Bank bank;
    bank_set(bank, model, clip.sample_rate, kMaxModes, nullptr);
    std::vector<float> excitation(frames, 0.0f);
    excitation[0] = 1.0f;
    out.resynthesis.assign(frames, 0.0f);
    bank_process(bank, excitation.data(), out.resynthesis.data(), frames);

    std::vector<float> original(clip.samples.begin() + onset, clip.samples.end());
    auto peak_of = [](const std::vector<float>& x) {
        double peak = 0.0;
        for (float v : x) peak = std::max(peak, static_cast<double>(std::fabs(v)));
        return peak;
    };
    const double original_peak = peak_of(original);
    const double resynthesis_peak = peak_of(out.resynthesis);
    if (original_peak > 0.0) {
        for (float& v : original) v = static_cast<float>(v / original_peak);
    }
    if (resynthesis_peak > 0.0) {
        for (float& v : out.resynthesis) v = static_cast<float>(v / resynthesis_peak);
    }

    out.difference.resize(frames);
    for (int i = 0; i < frames; ++i) out.difference[i] = original[i] - out.resynthesis[i];

    // Log-magnitude distance per frame, averaged. Amplitude alone would
    // reward a resynthesis that is loud in the wrong places.
    Clip a{original, clip.sample_rate};
    Clip b{out.resynthesis, clip.sample_rate};
    const std::vector<Frame> fa = analyse(a, settings, 0);
    const std::vector<Frame> fb = analyse(b, settings, 0);
    const size_t common = std::min(fa.size(), fb.size());
    double distance = 0.0;
    size_t counted = 0;
    for (size_t f = 0; f < common; ++f) {
        const size_t bins = std::min(fa[f].magnitude.size(), fb[f].magnitude.size());
        double frame_peak = 0.0;
        for (size_t k = 0; k < bins; ++k) {
            frame_peak = std::max(frame_peak, static_cast<double>(fa[f].magnitude[k]));
        }
        if (frame_peak <= 0.0) continue;
        // Only where the original has something to be compared with. Averaged
        // over every bin, the number is dominated by near-silent ones where
        // both signals are floor noise and the difference means nothing, and
        // a good fit and a bad one score much the same.
        const double floor = frame_peak * std::pow(10.0, -60.0 / 20.0);
        for (size_t k = 0; k < bins; ++k) {
            if (fa[f].magnitude[k] < floor) continue;
            distance += std::abs(db(fa[f].magnitude[k]) - db(fb[f].magnitude[k]));
            ++counted;
        }
    }
    out.spectral_convergence_db = counted > 0 ? distance / counted : 0.0;

    // Envelope error, in dB, over windows of a millisecond.
    const int step = std::max(1, clip.sample_rate / 1000);
    double squared = 0.0;
    int windows = 0;
    for (int i = 0; i + step <= frames; i += step) {
        double ea = 0.0, eb = 0.0;
        for (int k = 0; k < step; ++k) {
            ea += original[i + k] * original[i + k];
            eb += out.resynthesis[i + k] * out.resynthesis[i + k];
        }
        const double difference = db(std::sqrt(ea / step)) - db(std::sqrt(eb / step));
        squared += difference * difference;
        ++windows;
    }
    out.decay_rms_error_db = windows > 0 ? std::sqrt(squared / windows) : 0.0;
    return out;
}

}  // namespace modal
