// Shape plus material plus dimensions, out the other end a `.modal`.
#pragma once

#include <string>
#include <vector>

#include "materials.h"
#include "modal/model.h"
#include "shapes.h"

namespace modal::gen {

struct Request {
    ShapeSpec shape;
    const Material* material = nullptr;
    std::string name;

    int max_modes = 24;
    double sample_rate = 48000.0;

    // Move the whole series so its lowest mode lands here, keeping every
    // ratio. Zero means take the pitch from the dimensions.
    //
    // This exists because the dimensions give the ratios exactly and the
    // absolute pitch only approximately: a real mug has a base and a handle,
    // and neither is in the closed form for a shell. Tuning the fundamental
    // by ear against the object in front of you is not a fudge, it is using
    // each half for what it is good at.
    double fundamental = 0.0;

    // How many strike positions to measure along the object. Zero writes none.
    int strike_positions = 0;

    // Reference contact time for the material, ms. Zero picks a default from
    // the material's stiffness — a harder material means a shorter contact.
    double contact_time_ref_ms = 0.0;
};

struct Result {
    bool ok = false;
    std::string error;
    std::vector<std::string> notes;
    Model model;
    // True when the strike gains come from real mode shapes rather than from
    // the smooth approximation.
    bool strikes_are_analytic = false;
};

Result generate(const Request& request);

// Serialises to the `.modal` JSON that `core/src/model.cpp` reads.
std::string to_json(const Model& model, const std::string& source_note);

}  // namespace modal::gen
