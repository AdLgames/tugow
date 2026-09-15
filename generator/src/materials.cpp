#include "materials.h"

#include <cmath>

namespace modal::gen {

double Material::wave_speed() const {
    return std::sqrt(youngs_gpa * 1e9 / density);
}

const std::vector<Material>& materials() {
    // The damping constants are not invented. Each of the three hand-authored
    // models in `models/` follows tau = C * f^-p exactly, with no spread at
    // all across fourteen to eighteen modes, and those are the fitted values
    // referred to 1 kHz:
    //
    //     ceramic_mug    tau_1k 1.63   p 0.700
    //     glass_tumbler  tau_1k 2.85   p 0.550
    //     steel_pipe     tau_1k 4.42   p 0.420
    //
    // So the generator reproduces the library it is extending rather than
    // introducing a second opinion about what ceramic sounds like. The
    // materials that were not in that library are placed by ear against the
    // three that were, and are marked below.
    static const std::vector<Material> table = {
        // name        E(GPa)  rho    nu     tau_1k   p      q
        {"steel",       200.0, 7850.0, 0.30,   4.42, 0.420, 0.803},
        {"glass",        70.0, 2500.0, 0.22,   2.85, 0.550, 0.860},
        {"ceramic",      90.0, 2400.0, 0.22,   1.63, 0.700, 0.897},
        // Interpolated, not measured. Aluminium rings nearly as freely as
        // steel but is lighter and dies sooner; brass is heavier and duller;
        // stone barely rings at all, which is why a dropped paving slab is a
        // thud and a dropped bottle is a note.
        {"aluminium",    69.0, 2700.0, 0.33,   3.10, 0.450, 0.820},
        {"brass",       100.0, 8500.0, 0.34,   2.40, 0.480, 0.830},
        {"stone",        50.0, 2700.0, 0.25,   0.35, 0.850, 0.920},
    };
    return table;
}

const Material* find_material(const std::string& name) {
    for (const Material& material : materials()) {
        if (material.name == name) return &material;
    }
    return nullptr;
}

}  // namespace modal::gen
