// modal-fit — a recording in, a .modal model out.
//
//   modal-fit --in mug.wav --out models/mug.modal --verify

#include <cmath>
#include <cstdio>
#include <string>
#include <vector>

#include "../../harness/src/wav.h"
#include "fitter.h"

namespace {

struct Options {
    std::string in_path;
    std::string out_path;
    std::string verify_path;
    bool verify = false;
    bool explain = false;
    modal::FitSettings settings;
};

void usage() {
    std::printf(
        "modal-fit --in FILE.wav [--out FILE.modal] [options]\n"
        "  --modes N      how many modes to keep (default 32)\n"
        "  --verify       resynthesise and report how close it is\n"
        "  --verify-wav F write original | resynth | difference to F\n"
        "  --explain      list every candidate, including the rejected ones\n");
}

bool parse(int argc, char** argv, Options& out) {
    for (int i = 1; i < argc; ++i) {
        const std::string flag = argv[i];
        const bool has_value = i + 1 < argc;
        auto value = [&]() { return std::string(argv[++i]); };
        if (flag == "--in" && has_value) out.in_path = value();
        else if (flag == "--out" && has_value) out.out_path = value();
        else if (flag == "--verify-wav" && has_value) { out.verify_path = value(); out.verify = true; }
        else if (flag == "--modes" && has_value) out.settings.max_modes = std::stoi(value());
        else if (flag == "--verify") out.verify = true;
        else if (flag == "--explain") out.explain = true;
        else if (flag == "-h" || flag == "--help") { usage(); return false; }
        else {
            std::fprintf(stderr, "unknown or incomplete argument: %s\n", flag.c_str());
            return false;
        }
    }
    if (out.in_path.empty()) {
        usage();
        return false;
    }
    return true;
}

std::string escape(const std::string& text) {
    std::string out;
    for (char c : text) {
        if (c == '"' || c == '\\') out.push_back('\\');
        out.push_back(c);
    }
    return out;
}

bool write_modal(const std::string& path, const modal::Model& model, const std::string& source,
                 const std::string& name) {
    FILE* file = std::fopen(path.c_str(), "wb");
    if (file == nullptr) return false;
    std::fprintf(file, "{\n  \"format\": \"modal\",\n  \"version\": 1,\n");
    std::fprintf(file, "  \"name\": \"%s\",\n", escape(name).c_str());
    std::fprintf(file, "  \"source\": \"fitted from %s\",\n", escape(source).c_str());
    std::fprintf(file, "  \"fit_quality\": %.4f,\n", model.fit_quality);
    std::fprintf(file, "  \"modes\": [\n");
    for (size_t i = 0; i < model.modes.size(); ++i) {
        std::fprintf(file, "    { \"f\": %.2f, \"tau\": %.5f, \"a\": %.5f }%s\n", model.modes[i].f,
                     model.modes[i].tau, model.modes[i].a,
                     i + 1 == model.modes.size() ? "" : ",");
    }
    std::fprintf(file, "  ],\n  \"material\": {\n");
    std::fprintf(file, "    \"contact_time_ref_ms\": %.3f,\n", model.material.contact_time_ref_ms);
    std::fprintf(file, "    \"roughness\": %.3f,\n", model.material.roughness);
    std::fprintf(file, "    \"rolling_gain\": %.3f,\n", model.material.rolling_gain);
    std::fprintf(file, "    \"scrape_gain\": %.3f\n  }\n}\n", model.material.scrape_gain);
    std::fclose(file);
    return true;
}

std::string stem(const std::string& path) {
    const size_t slash = path.find_last_of("/\\");
    const std::string file = slash == std::string::npos ? path : path.substr(slash + 1);
    const size_t dot = file.find_last_of('.');
    return dot == std::string::npos ? file : file.substr(0, dot);
}

}  // namespace

int main(int argc, char** argv) {
    Options options;
    if (!parse(argc, argv, options)) return 1;

    modal::Clip clip;
    std::string error;
    if (!modal::load_wav(options.in_path, clip, error)) {
        std::fprintf(stderr, "error: %s\n", error.c_str());
        return 1;
    }
    std::printf("%s — %.2f s at %d Hz\n", options.in_path.c_str(),
                clip.samples.size() / static_cast<double>(clip.sample_rate), clip.sample_rate);

    const modal::FitReport report = modal::fit(clip, options.settings);
    for (const std::string& warning : report.warnings) {
        std::fprintf(stderr, "warning: %s\n", warning.c_str());
    }

    if (options.explain) {
        std::printf("\n%zu candidates:\n", report.candidates.size());
        for (const modal::Candidate& candidate : report.candidates) {
            if (candidate.rejected.empty()) {
                std::printf("  keep    %8.1f Hz  tau %6.3f  R2 %.3f  %d frames\n", candidate.f,
                            candidate.tau, candidate.r_squared, candidate.tracked_frames);
            } else {
                std::printf("  reject  %8.1f Hz  %s\n", candidate.f, candidate.rejected.c_str());
            }
        }
        std::printf("\n");
    }

    if (!report.ok) {
        std::fprintf(stderr, "error: %s\n", report.error.c_str());
        return 1;
    }

    std::printf("%zu modes, fit quality %.3f\n", report.model.modes.size(), report.fit_quality);
    for (size_t i = 0; i < report.model.modes.size() && i < 12; ++i) {
        std::printf("  %2zu  %8.1f Hz   tau %6.3f s   a %.3f\n", i, report.model.modes[i].f,
                    report.model.modes[i].tau, report.model.modes[i].a);
    }
    if (report.model.modes.size() > 12) {
        std::printf("  ... %zu more\n", report.model.modes.size() - 12);
    }

    if (options.verify) {
        const modal::Verification check = modal::verify(clip, report.model, options.settings);
        std::printf("\nverification\n");
        std::printf("  spectral distance  %.2f dB   (lower is closer)\n",
                    check.spectral_convergence_db);
        std::printf("  decay envelope RMS %.2f dB\n", check.decay_rms_error_db);
        if (!options.verify_path.empty()) {
            // Original, resynthesis and difference end to end, with a short
            // gap, because hearing them next to each other is the only test
            // anyone actually believes.
            std::vector<float> side_by_side;
            const int gap = clip.sample_rate / 4;
            const modal::Clip& c = clip;
            const int onset = modal::find_onset(c, options.settings.onset_floor_db);
            for (size_t i = onset; i < c.samples.size(); ++i) side_by_side.push_back(c.samples[i]);
            side_by_side.insert(side_by_side.end(), gap, 0.0f);
            side_by_side.insert(side_by_side.end(), check.resynthesis.begin(),
                                check.resynthesis.end());
            side_by_side.insert(side_by_side.end(), gap, 0.0f);
            side_by_side.insert(side_by_side.end(), check.difference.begin(),
                                check.difference.end());
            double peak = 0.0;
            for (float v : side_by_side) peak = std::max(peak, static_cast<double>(std::fabs(v)));
            if (peak > 0.0) {
                for (float& v : side_by_side) v = static_cast<float>(v * 0.9 / peak);
            }
            modal::write_wav(options.verify_path, side_by_side, clip.sample_rate, 1);
            std::printf("  wrote %s — original, resynthesis, difference\n",
                        options.verify_path.c_str());
        }
    }

    if (!options.out_path.empty()) {
        if (!write_modal(options.out_path, report.model, options.in_path, stem(options.out_path))) {
            std::fprintf(stderr, "error: could not write %s\n", options.out_path.c_str());
            return 1;
        }
        std::printf("\nwrote %s\n", options.out_path.c_str());
    }
    return 0;
}
