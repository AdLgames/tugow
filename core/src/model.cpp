#include "modal/model.h"

#include <algorithm>
#include <cmath>
#include <fstream>
#include <sstream>

#include "json.h"

namespace modal {
namespace {

bool read_number(const json::Value& node, const char* key, double& out) {
    const json::Value& child = node[key];
    if (!child.is_number()) return false;
    out = child.number;
    return true;
}

std::string say(double value) {
    std::ostringstream text;
    text << value;
    return text.str();
}

}  // namespace

Coefficients coefficients_for(const Mode& mode, double sample_rate) {
    // Everything here is double and narrowed once at the end. r is within a
    // few parts per million of 1.0 for a ten-second decay, and squaring it
    // in float32 loses the difference that makes the decay right.
    const double omega = 2.0 * M_PI * mode.f / sample_rate;
    const double r = std::exp(-1.0 / (mode.tau * sample_rate));
    Coefficients out;
    out.a1 = static_cast<float>(2.0 * r * std::cos(omega));
    out.a2 = static_cast<float>(-(r * r));
    // b0 = a·sin(omega) makes the impulse response peak at a, which is what
    // keeps the relative level of the modes the same as in the file.
    out.b0 = static_cast<float>(mode.a * std::sin(omega));
    return out;
}

std::vector<Coefficients> Model::coefficients(double sample_rate) const {
    std::vector<Coefficients> out;
    out.reserve(modes.size());
    for (const Mode& mode : modes) out.push_back(coefficients_for(mode, sample_rate));
    return out;
}

LoadResult load_from_string(const std::string& text, double sample_rate) {
    LoadResult result;

    json::Value root;
    std::string parse_error;
    if (!json::parse(text, root, parse_error)) {
        result.error = "not valid JSON: " + parse_error;
        return result;
    }
    if (!root.is_object()) {
        result.error = "the top level is not an object";
        return result;
    }
    if (root["format"].string != "modal") {
        result.error = "not a modal file: \"format\" is not \"modal\"";
        return result;
    }
    if (root["version"].number != 1.0) {
        result.error = "unsupported version " + say(root["version"].number);
        return result;
    }
    if (sample_rate <= 0.0) {
        result.error = "sample rate must be positive";
        return result;
    }

    Model model;
    model.name = root["name"].string;
    model.source = root["source"].string;
    model.fit_quality = root["fit_quality"].number;

    // 1. modes non-empty, length <= 256.
    const json::Value& modes = root["modes"];
    if (!modes.is_array() || modes.array.empty()) {
        result.error = "\"modes\" is missing or empty";
        return result;
    }
    if (static_cast<int>(modes.array.size()) > kMaxModesInFile) {
        result.error = "too many modes: " + std::to_string(modes.array.size()) +
                       ", the limit is " + std::to_string(kMaxModesInFile);
        return result;
    }

    // A mode is kept or dropped, but the file's own indexing has to survive
    // either way — the strike gains are positional.
    const double highest = kNyquistFraction * sample_rate;
    std::vector<bool> kept(modes.array.size(), false);
    for (size_t i = 0; i < modes.array.size(); ++i) {
        const json::Value& entry = modes.array[i];
        Mode mode;
        if (!entry.is_object() || !read_number(entry, "f", mode.f) ||
            !read_number(entry, "tau", mode.tau) || !read_number(entry, "a", mode.a)) {
            result.error = "mode " + std::to_string(i) + " is missing f, tau or a";
            return result;
        }
        // 4. tau in range. Out of range is an error: it is a broken file
        //    rather than a mode this sample rate cannot reach.
        if (!(mode.tau >= kMinTau && mode.tau <= kMaxTau)) {
            result.error = "mode " + std::to_string(i) + " has tau " + say(mode.tau) +
                           ", outside " + say(kMinTau) + " to " + say(kMaxTau);
            return result;
        }
        // 5. amplitude positive and no greater than 1.
        if (!(mode.a > 0.0 && mode.a <= 1.0)) {
            result.error = "mode " + std::to_string(i) + " has amplitude " + say(mode.a) +
                           ", outside 0 to 1";
            return result;
        }
        // 3. frequency inside the usable band — a warning, not an error, so a
        //    model fitted at 48 kHz still loads at 44.1 kHz.
        if (mode.f < kMinFrequency || mode.f > highest) {
            result.warnings.push_back("dropped mode " + std::to_string(i) + " at " +
                                      say(mode.f) + " Hz: outside " + say(kMinFrequency) +
                                      " to " + say(highest) + " Hz at this sample rate");
            continue;
        }
        kept[i] = true;
        model.modes.push_back(mode);
    }
    if (model.modes.empty()) {
        result.error = "every mode was outside the usable band at " + say(sample_rate) + " Hz";
        return result;
    }

    // 6 and 7. Strike gains are per mode and positional, so they are filtered
    //          by the same decision the modes were.
    if (root.has("strike_positions")) {
        const json::Value& positions = root["strike_positions"];
        if (!positions.is_array()) {
            result.error = "\"strike_positions\" is not an array";
            return result;
        }
        for (size_t p = 0; p < positions.array.size(); ++p) {
            const json::Value& entry = positions.array[p];
            StrikePosition position;
            if (!entry.is_object() || !read_number(entry, "u", position.u) ||
                !read_number(entry, "v", position.v)) {
                result.error = "strike position " + std::to_string(p) + " is missing u or v";
                return result;
            }
            if (position.u < 0.0 || position.u > 1.0 || position.v < 0.0 || position.v > 1.0) {
                result.error = "strike position " + std::to_string(p) + " is outside the unit square";
                return result;
            }
            const json::Value& gains = entry["gains"];
            if (!gains.is_array() || gains.array.size() != modes.array.size()) {
                result.error = "strike position " + std::to_string(p) + " has " +
                               std::to_string(gains.array.size()) + " gains for " +
                               std::to_string(modes.array.size()) + " modes";
                return result;
            }
            for (size_t i = 0; i < gains.array.size(); ++i) {
                if (!gains.array[i].is_number()) {
                    result.error = "strike position " + std::to_string(p) + " has a gain that is not a number";
                    return result;
                }
                if (kept[i]) position.gains.push_back(gains.array[i].number);
            }
            model.strike_positions.push_back(position);
        }
    }

    if (root.has("material")) {
        const json::Value& material = root["material"];
        read_number(material, "contact_time_ref_ms", model.material.contact_time_ref_ms);
        read_number(material, "roughness", model.material.roughness);
        read_number(material, "rolling_gain", model.material.rolling_gain);
        read_number(material, "scrape_gain", model.material.scrape_gain);
        if (model.material.contact_time_ref_ms <= 0.0) {
            result.error = "contact_time_ref_ms must be positive";
            return result;
        }
    }

    // 2. Sorted by amplitude descending. This is what makes the level-of-
    //    detail truncation safe: dropping the tail always drops the quietest.
    //    The strike gains are reordered with it or they stop lining up.
    std::vector<size_t> order(model.modes.size());
    for (size_t i = 0; i < order.size(); ++i) order[i] = i;
    std::stable_sort(order.begin(), order.end(), [&](size_t x, size_t y) {
        return model.modes[x].a > model.modes[y].a;
    });
    const bool already_sorted = std::is_sorted(order.begin(), order.end());
    if (!already_sorted) {
        result.warnings.push_back("modes were not sorted by amplitude; sorted on load");
        std::vector<Mode> sorted;
        sorted.reserve(order.size());
        for (size_t i : order) sorted.push_back(model.modes[i]);
        model.modes = sorted;
        for (StrikePosition& position : model.strike_positions) {
            std::vector<double> gains;
            gains.reserve(order.size());
            for (size_t i : order) gains.push_back(position.gains[i]);
            position.gains = gains;
        }
    }

    // 5, continued. Normalise so the loudest mode is exactly 1.
    const double loudest = model.modes.front().a;
    if (loudest <= 0.0) {
        result.error = "every mode has zero amplitude";
        return result;
    }
    if (std::abs(loudest - 1.0) > 1e-9) {
        for (Mode& mode : model.modes) mode.a /= loudest;
    }

    result.ok = true;
    result.model = model;
    return result;
}

LoadResult load_from_file(const std::string& path, double sample_rate) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        LoadResult result;
        result.error = "could not open " + path;
        return result;
    }
    std::ostringstream text;
    text << file.rdbuf();
    return load_from_string(text.str(), sample_rate);
}

}  // namespace modal
