// modal-render — strike a model and write the result to a WAV.
//
//   modal-render --model models/ceramic.modal --velocity 2.0 --out hit.wav
//
// No Godot, no audio device. The point of week one is to hear the engine
// before anything is built on top of it.

#include <cmath>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

#include "modal/bank.h"
#include "modal/excitation.h"
#include "modal/model.h"
#include "wav.h"

namespace {

struct Options {
    std::string model_path;
    std::string out_path = "hit.wav";
    double velocity = 2.0;
    double impulse = 0.0;  // 0 means derive from velocity
    double sample_rate = 48000.0;
    double seconds = 2.0;
    double gain = 0.5;
    uint32_t max_modes = modal::kMaxModes;
    bool report_only = false;
};

void usage() {
    std::printf(
        "modal-render --model FILE [options]\n"
        "  --velocity V     impact velocity in m/s (default 2.0)\n"
        "  --impulse J      impulse in N.s; default is 0.1 x velocity\n"
        "  --out FILE       output WAV (default hit.wav)\n"
        "  --rate HZ        sample rate (default 48000)\n"
        "  --seconds S      render length (default 2.0)\n"
        "  --gain G         output gain (default 0.5)\n"
        "  --modes N        cap the mode count, for level-of-detail checks\n"
        "  --report         print what the model contains and stop\n");
}

bool parse(int argc, char** argv, Options& out) {
    for (int i = 1; i < argc; ++i) {
        const std::string flag = argv[i];
        const bool has_value = i + 1 < argc;
        auto value = [&]() { return std::string(argv[++i]); };
        if (flag == "--model" && has_value) out.model_path = value();
        else if (flag == "--out" && has_value) out.out_path = value();
        else if (flag == "--velocity" && has_value) out.velocity = std::stod(value());
        else if (flag == "--impulse" && has_value) out.impulse = std::stod(value());
        else if (flag == "--rate" && has_value) out.sample_rate = std::stod(value());
        else if (flag == "--seconds" && has_value) out.seconds = std::stod(value());
        else if (flag == "--gain" && has_value) out.gain = std::stod(value());
        else if (flag == "--modes" && has_value) out.max_modes = static_cast<uint32_t>(std::stoul(value()));
        else if (flag == "--report") out.report_only = true;
        else if (flag == "-h" || flag == "--help") { usage(); return false; }
        else {
            std::fprintf(stderr, "unknown or incomplete argument: %s\n", flag.c_str());
            return false;
        }
    }
    if (out.model_path.empty()) {
        usage();
        return false;
    }
    return true;
}

// Where the spectral energy sits, in Hz. The whole velocity model stands or
// falls on this number rising with velocity, so the harness prints it.
double spectral_centroid(const std::vector<float>& samples, double sample_rate) {
    // A Goertzel sweep is enough and needs no FFT: this is a diagnostic
    // printed once, not something in the audio path.
    const int bins = 256;
    const double lowest = 40.0;
    const double highest = 0.45 * sample_rate;
    double weighted = 0.0;
    double total = 0.0;
    for (int b = 0; b < bins; ++b) {
        const double t = static_cast<double>(b) / (bins - 1);
        const double frequency = lowest * std::pow(highest / lowest, t);
        const double omega = 2.0 * M_PI * frequency / sample_rate;
        const double coefficient = 2.0 * std::cos(omega);
        double s1 = 0.0, s2 = 0.0;
        for (float sample : samples) {
            const double s = sample + coefficient * s1 - s2;
            s2 = s1;
            s1 = s;
        }
        const double power = s1 * s1 + s2 * s2 - coefficient * s1 * s2;
        const double magnitude = std::sqrt(power > 0.0 ? power : 0.0);
        weighted += frequency * magnitude;
        total += magnitude;
    }
    return total > 0.0 ? weighted / total : 0.0;
}

}  // namespace

int main(int argc, char** argv) {
    Options options;
    if (!parse(argc, argv, options)) return 1;

    modal::LoadResult loaded = modal::load_from_file(options.model_path, options.sample_rate);
    for (const std::string& warning : loaded.warnings) {
        std::fprintf(stderr, "warning: %s\n", warning.c_str());
    }
    if (!loaded.ok) {
        std::fprintf(stderr, "error: %s\n", loaded.error.c_str());
        return 1;
    }
    const modal::Model& model = loaded.model;

    if (options.report_only) {
        std::printf("%s — %zu modes, contact reference %.3f ms\n", model.name.c_str(),
                    model.modes.size(), model.material.contact_time_ref_ms);
        for (size_t i = 0; i < model.modes.size(); ++i) {
            std::printf("  %2zu  %8.1f Hz   tau %6.3f s   a %.3f\n", i, model.modes[i].f,
                        model.modes[i].tau, model.modes[i].a);
        }
        return 0;
    }

    modal::Bank bank;
    modal::bank_set(bank, model, options.sample_rate, options.max_modes, nullptr);

    // A plausible impulse for a small object at this speed. The harness is
    // not a physics engine; the point is that the same J at different
    // velocities still changes the timbre, because the contact time does.
    const double impulse = options.impulse > 0.0 ? options.impulse : 0.1 * options.velocity;
    const modal::Pulse pulse = modal::make_pulse(impulse, model.material.contact_time_ref_ms,
                                                 options.velocity, options.sample_rate);

    const int frames = static_cast<int>(options.seconds * options.sample_rate);
    std::vector<float> excitation(frames, 0.0f);
    modal::pulse_render(pulse, 0, excitation.data(), frames);
    std::vector<float> out(frames, 0.0f);
    modal::bank_process(bank, excitation.data(), out.data(), frames);

    if (!modal::bank_is_finite(bank)) {
        std::fprintf(stderr, "error: the bank went non-finite — check the coefficients\n");
        return 1;
    }

    double peak = 0.0;
    for (float sample : out) peak = std::max(peak, static_cast<double>(std::fabs(sample)));
    const double scale = peak > 0.0 ? options.gain / peak : 0.0;
    for (float& sample : out) sample = static_cast<float>(sample * scale);

    if (!modal::write_wav(options.out_path, out, static_cast<int>(options.sample_rate), 1)) {
        std::fprintf(stderr, "error: could not write %s\n", options.out_path.c_str());
        return 1;
    }

    std::printf("%s  v=%.2f m/s  contact %.3f ms (%d samples)  peak %.4f  centroid %.0f Hz  -> %s\n",
                model.name.c_str(), options.velocity,
                modal::contact_seconds(model.material.contact_time_ref_ms, options.velocity) * 1e3,
                pulse.frames, peak, spectral_centroid(out, options.sample_rate),
                options.out_path.c_str());
    return 0;
}
