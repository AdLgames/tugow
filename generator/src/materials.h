// What a thing is made of.
//
// Two halves, and they are not equally solid.
//
// The elastic constants are textbook and set the frequencies: a wave travels
// through steel at 5050 m/s and through glass at 5290, and that is not a
// matter of taste. Frequencies generated from them are as right as the
// dimensions they are given.
//
// The damping is empirical and says so. A single loss factor would give
// tau proportional to 1/f, and real objects do not do that — measured on the
// three hand-authored models in this repository, tau falls as f^-0.42 for
// steel, f^-0.55 for glass and f^-0.70 for ceramic. The physics behind that
// spread is a mixture of internal friction, thermoelastic loss and radiation
// into the air, and modelling it properly is a research project. Two
// constants per material reproduce it, and the file says which two.
#pragma once

#include <string>
#include <vector>

namespace modal::gen {

struct Material {
    std::string name;

    // Elastic constants. These set the frequencies.
    double youngs_gpa = 0.0;    // E, GPa
    double density = 0.0;       // rho, kg/m^3
    double poisson = 0.3;       // nu, for plate and shell stiffness

    // Damping, empirical: tau(f) = tau_1k * (f / 1000)^(-decay_exponent).
    double tau_1k = 0.5;        // 1/e decay of a 1 kHz mode, seconds
    double decay_exponent = 0.7;

    // Modal amplitude rolloff: a(f) = (f / f0)^(-amplitude_exponent).
    // A struck object's high modes are quieter than its low ones; how much
    // quieter is a property of the strike as much as the material, and this
    // is the default for a firm strike near an antinode.
    double amplitude_exponent = 0.85;

    // Longitudinal wave speed, m/s. Everything about the frequencies comes
    // through here.
    double wave_speed() const;
};

// Every material the generator knows. Rigid bodies that ring, only: the
// build plan lists cloth, flesh, foliage and liquids as non-goals, and a
// modal model of a cushion would be a confident lie.
const std::vector<Material>& materials();

// Looks a material up by name. Returns null when there is no such material,
// so a caller can list what there is instead of guessing.
const Material* find_material(const std::string& name);

}  // namespace modal::gen
