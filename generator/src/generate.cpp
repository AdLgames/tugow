#include "generate.h"

#include <algorithm>
#include <cmath>
#include <sstream>

namespace modal::gen {
namespace {

std::string number(double value, int digits) {
    std::ostringstream text;
    text.setf(std::ios::fixed);
    text.precision(digits);
    text << value;
    std::string out = text.str();
    // Trim trailing zeros so the file reads like something a person wrote.
    if (out.find('.') != std::string::npos) {
        out.erase(out.find_last_not_of('0') + 1);
        if (!out.empty() && out.back() == '.') out.pop_back();
    }
    return out.empty() ? "0" : out;
}

// A harder, stiffer material makes a shorter contact for the same strike.
// Referenced to the three models the library already had: steel 0.08 ms at
// 200 GPa, glass 0.12 at 70, ceramic 0.15 at 90. Stiffness alone does not
// order those three, so this leans on the measured values where they exist
// and interpolates only where they do not.
double default_contact_ms(const Material& material) {
    if (material.name == "steel") return 0.08;
    if (material.name == "glass") return 0.12;
    if (material.name == "ceramic") return 0.15;
    if (material.name == "aluminium") return 0.09;
    if (material.name == "brass") return 0.10;
    if (material.name == "stone") return 0.20;
    return 0.12;
}

}  // namespace

Result generate(const Request& request) {
    Result result;
    if (request.material == nullptr) {
        result.error = "no material";
        return result;
    }
    std::string shape_error;
    if (!validate(request.shape, shape_error)) {
        result.error = shape_error;
        return result;
    }
    if (request.max_modes <= 0) {
        result.error = "--modes must be positive";
        return result;
    }

    const Material& material = *request.material;

    // Ask for more than are wanted: the band filter below will drop the ones
    // this sample rate cannot carry, and a shell's series climbs fast enough
    // that half of them can go.
    const std::vector<ShapeMode> series =
        mode_series(request.shape, material, request.max_modes * 3);
    if (series.empty()) {
        result.error = "the shape produced no modes";
        return result;
    }

    double scale = 1.0;
    if (request.fundamental > 0.0) {
        scale = request.fundamental / series.front().frequency;
    }

    const double ceiling = kNyquistFraction * request.sample_rate;
    const double root = series.front().frequency * scale;

    std::vector<int> kept_indices;
    for (size_t i = 0; i < series.size(); ++i) {
        if (static_cast<int>(result.model.modes.size()) >= request.max_modes) break;
        const double frequency = series[i].frequency * scale;
        if (frequency < kMinFrequency) continue;
        if (frequency > ceiling) break;  // the series only climbs

        Mode mode;
        mode.f = frequency;
        // tau = tau_1k * (f/1000)^-p, the empirical law in materials.cpp.
        mode.tau = material.tau_1k * std::pow(frequency / 1000.0, -material.decay_exponent);
        mode.tau = std::min(std::max(mode.tau, kMinTau), kMaxTau);
        // a = (f/f0)^-q, normalised to 1 at the fundamental.
        mode.a = std::pow(frequency / root, -material.amplitude_exponent);
        result.model.modes.push_back(mode);
        kept_indices.push_back(static_cast<int>(i));
    }

    if (result.model.modes.empty()) {
        result.error = "every mode fell outside 20 Hz to " + number(ceiling, 0) +
                       " Hz at this sample rate";
        return result;
    }

    // Merge modes too close together to be two modes.
    //
    // A square plate's (m,n) and (n,m) are the same frequency exactly, and a
    // resonator bank given both spends two of its forty-eight slots producing
    // one partial at double amplitude. The tolerance is the fitter's own
    // `merge_tolerance` — one per cent — so a generated model and a fitted one
    // agree about what counts as one mode.
    //
    // Real plates are never quite square and their degeneracies split, which
    // is audible as a slow beat. Representing that honestly needs the
    // asymmetry as an input rather than a fudge here, so this merges and the
    // caller can pass a --width that differs if they want the beat.
    {
        constexpr double kMergeTolerance = 0.01;
        std::vector<Mode> merged;
        std::vector<int> merged_sources;
        int collapsed = 0;
        for (size_t i = 0; i < result.model.modes.size(); ++i) {
            const Mode& mode = result.model.modes[i];
            if (!merged.empty() &&
                std::abs(mode.f - merged.back().f) <= kMergeTolerance * merged.back().f) {
                // Amplitudes add; the survivor keeps the lower frequency and
                // the longer decay, which is the one that is still audible.
                merged.back().a += mode.a;
                merged.back().tau = std::max(merged.back().tau, mode.tau);
                ++collapsed;
                continue;
            }
            merged.push_back(mode);
            merged_sources.push_back(kept_indices[i]);
        }
        if (collapsed > 0) {
            result.model.modes = merged;
            kept_indices = merged_sources;
            result.notes.push_back("merged " + std::to_string(collapsed) +
                                   " degenerate modes within 1%");
        }
    }
    if (static_cast<int>(result.model.modes.size()) < request.max_modes) {
        result.notes.push_back(
            "kept " + std::to_string(result.model.modes.size()) + " of " +
            std::to_string(request.max_modes) + " modes; the rest ran past " +
            number(ceiling, 0) + " Hz");
    }

    // Sorted by amplitude descending, then normalised so the loudest is
    // exactly 1. The loader does both anyway, but it warns when it has to —
    // and a generator whose output makes the runtime complain is a generator
    // that has not finished the job. Merging is what breaks the order: two
    // degenerate modes add, and the survivor can outrank a mode below it.
    {
        std::vector<size_t> order(result.model.modes.size());
        for (size_t i = 0; i < order.size(); ++i) order[i] = i;
        std::stable_sort(order.begin(), order.end(), [&](size_t x, size_t y) {
            return result.model.modes[x].a > result.model.modes[y].a;
        });
        std::vector<Mode> sorted;
        std::vector<int> sorted_sources;
        sorted.reserve(order.size());
        sorted_sources.reserve(order.size());
        for (size_t i : order) {
            sorted.push_back(result.model.modes[i]);
            sorted_sources.push_back(kept_indices[i]);
        }
        result.model.modes = sorted;
        kept_indices = sorted_sources;
    }

    const double loudest = result.model.modes.front().a;
    if (loudest > 0.0) {
        for (Mode& mode : result.model.modes) mode.a /= loudest;
    }

    // Strike positions, from the mode shapes. For a bar these are real: the
    // gain of mode k at position u is that mode's displacement there, so a
    // strike at a node genuinely misses the mode. No model in this repository
    // has carried strike gains before, because the fitter sees one strike per
    // recording and cannot measure a map from it.
    if (request.strike_positions > 0) {
        result.strikes_are_analytic = has_analytic_mode_shapes(request.shape.family);
        for (int p = 0; p < request.strike_positions; ++p) {
            // Spread across the half-length: a free-free bar is symmetric, so
            // the far half measures nothing the near half has not.
            const double u = (request.strike_positions == 1)
                                 ? 0.0
                                 : 0.5 * static_cast<double>(p) / (request.strike_positions - 1);
            StrikePosition position;
            position.u = u;
            position.v = 0.5;
            for (size_t k = 0; k < kept_indices.size(); ++k) {
                position.gains.push_back(mode_gain_at(request.shape, kept_indices[k], u));
            }
            result.model.strike_positions.push_back(position);
        }
        if (!result.strikes_are_analytic) {
            result.notes.push_back(
                "strike gains for a " + family_name(request.shape.family) +
                " are a standing-wave approximation, not measured mode shapes");
        }
    }

    result.model.name = request.name;
    result.model.material.contact_time_ref_ms = request.contact_time_ref_ms > 0.0
                                                    ? request.contact_time_ref_ms
                                                    : default_contact_ms(material);
    // Roughness and the contact gains are not derivable from shape; these are
    // the library's existing values for the nearest material.
    result.model.material.roughness = material.name == "glass" ? 0.12 : 0.3;
    result.model.material.rolling_gain = 0.5;
    result.model.material.scrape_gain = 1.0;
    // Nothing was fitted, so there is no fit quality to report. Zero is what
    // the hand-authored models carry and what the GUI reads as "not fitted".
    result.model.fit_quality = 0.0;
    result.ok = true;
    return result;
}

std::string to_json(const Model& model, const std::string& source_note) {
    std::ostringstream out;
    out << "{\n";
    out << "  \"format\": \"modal\",\n";
    out << "  \"version\": 1,\n";
    out << "  \"name\": \"" << model.name << "\",\n";
    out << "  \"source\": \"" << source_note << "\",\n";
    out << "  \"fit_quality\": " << number(model.fit_quality, 4) << ",\n";
    out << "  \"modes\": [\n";
    for (size_t i = 0; i < model.modes.size(); ++i) {
        const Mode& mode = model.modes[i];
        out << "    {\n";
        out << "      \"f\": " << number(mode.f, 4) << ",\n";
        out << "      \"tau\": " << number(mode.tau, 6) << ",\n";
        out << "      \"a\": " << number(mode.a, 6) << "\n";
        out << "    }" << (i + 1 < model.modes.size() ? "," : "") << "\n";
    }
    out << "  ],\n";

    if (!model.strike_positions.empty()) {
        out << "  \"strike_positions\": [\n";
        for (size_t p = 0; p < model.strike_positions.size(); ++p) {
            const StrikePosition& position = model.strike_positions[p];
            out << "    {\n";
            out << "      \"u\": " << number(position.u, 4) << ",\n";
            out << "      \"v\": " << number(position.v, 4) << ",\n";
            out << "      \"gains\": [";
            for (size_t k = 0; k < position.gains.size(); ++k) {
                out << number(position.gains[k], 5)
                    << (k + 1 < position.gains.size() ? ", " : "");
            }
            out << "]\n";
            out << "    }" << (p + 1 < model.strike_positions.size() ? "," : "") << "\n";
        }
        out << "  ],\n";
    }

    out << "  \"material\": {\n";
    out << "    \"contact_time_ref_ms\": " << number(model.material.contact_time_ref_ms, 4) << ",\n";
    out << "    \"roughness\": " << number(model.material.roughness, 4) << ",\n";
    out << "    \"rolling_gain\": " << number(model.material.rolling_gain, 4) << ",\n";
    out << "    \"scrape_gain\": " << number(model.material.scrape_gain, 4) << "\n";
    out << "  }\n";
    out << "}\n";
    return out.str();
}

}  // namespace modal::gen
