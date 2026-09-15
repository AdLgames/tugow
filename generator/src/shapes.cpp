#include "shapes.h"

#include <algorithm>
#include <cmath>

namespace modal::gen {
namespace {

// Roots of cos(x)cosh(x) = 1, which are where a free-free bar's boundary
// conditions land. Past the fifth they converge on (2n+1)pi/2 to more decimal
// places than a bar's dimensions are ever known to.
double beta_l(int n) {
    static const double roots[] = {4.730040745, 7.853204624, 10.995607838,
                                   14.137165491, 17.278759657};
    if (n < 5) return roots[n];
    return (2.0 * (n + 1) + 1.0) * M_PI / 2.0;
}

// Radius of gyration of the cross-section, which is the only thing about a
// bar's shape that its bending modes care about. A tube and a solid rod of
// the same kappa ring identically, which is why a scaffold pole and a
// broomstick are different sounds for a reason you can write down.
double radius_of_gyration(const ShapeSpec& spec) {
    const Dimensions& d = spec.dimensions;
    if (spec.round_section) {
        if (d.bore > 0.0) return std::sqrt(d.radius * d.radius + d.bore * d.bore) / 2.0;
        return d.radius / 2.0;
    }
    return d.thickness / std::sqrt(12.0);
}

// Flexural rigidity term shared by the plate modes.
double plate_speed(const Material& material) {
    const double nu = material.poisson;
    return material.wave_speed() / std::sqrt(12.0 * (1.0 - nu * nu));
}

}  // namespace

bool parse_family(const std::string& name, Family& out) {
    if (name == "bar") { out = Family::Bar; return true; }
    if (name == "plate") { out = Family::Plate; return true; }
    if (name == "shell") { out = Family::Shell; return true; }
    return false;
}

std::string family_name(Family family) {
    switch (family) {
        case Family::Bar: return "bar";
        case Family::Plate: return "plate";
        case Family::Shell: return "shell";
    }
    return "bar";
}

std::string describe_dimensions(Family family) {
    switch (family) {
        case Family::Bar:
            return "--length and --thickness (or --radius for a round section, "
                   "plus --bore for a tube)";
        case Family::Plate:
            return "--length, --thickness, and optionally --width";
        case Family::Shell:
            return "--radius and --thickness";
    }
    return "";
}

bool validate(const ShapeSpec& spec, std::string& error) {
    const Dimensions& d = spec.dimensions;
    auto positive = [&](double value, const char* what) {
        if (value > 0.0) return true;
        error = std::string(what) + " must be positive";
        return false;
    };
    switch (spec.family) {
        case Family::Bar:
            if (!positive(d.length, "--length")) return false;
            if (spec.round_section) {
                if (!positive(d.radius, "--radius")) return false;
                if (d.bore >= d.radius) {
                    error = "--bore must be smaller than --radius";
                    return false;
                }
            } else if (!positive(d.thickness, "--thickness")) {
                return false;
            }
            return true;
        case Family::Plate:
            if (!positive(d.length, "--length")) return false;
            if (!positive(d.thickness, "--thickness")) return false;
            return true;
        case Family::Shell:
            if (!positive(d.radius, "--radius")) return false;
            if (!positive(d.thickness, "--thickness")) return false;
            if (d.thickness >= d.radius) {
                error = "--thickness must be smaller than --radius for a shell";
                return false;
            }
            return true;
    }
    return true;
}

std::vector<ShapeMode> mode_series(const ShapeSpec& spec, const Material& material, int count) {
    std::vector<ShapeMode> out;
    const Dimensions& d = spec.dimensions;
    const double c = material.wave_speed();

    switch (spec.family) {
        case Family::Bar: {
            // f_n = (pi * kappa * c / 8L^2) * m_n^2, the standard free-free
            // flexural series. The ratios 1 : 2.757 : 5.404 are the signature
            // of a struck bar and are why a xylophone note needs its
            // overtones tuned out by undercutting.
            const double kappa = radius_of_gyration(spec);
            const double base = M_PI * kappa * c / (8.0 * d.length * d.length);
            for (int n = 0; n < count; ++n) {
                // m_n = 3.0112, 5, 7, 9 ... which is 2(n+1)+1 past the first.
                const double m = (n == 0) ? 3.0112 : (2.0 * (n + 1) + 1.0);
                ShapeMode mode;
                mode.frequency = base * m * m;
                mode.node_count = n + 2;  // a free-free bar's nth mode has n+2 nodes
                out.push_back(mode);
            }
            break;
        }
        case Family::Plate: {
            // Simply supported, which is the rectangular plate that has a
            // closed form. A tile resting on a floor is nearer free-edged and
            // its ratios differ in the detail, but the character — a dense,
            // rapidly thickening 2D series rather than a bar's sparse one —
            // is the part that makes a plate sound like a plate.
            const double width = d.width > 0.0 ? d.width : d.length;
            const double base = (M_PI / 2.0) * d.thickness * plate_speed(material);
            std::vector<double> frequencies;
            const int span = std::max(4, static_cast<int>(std::sqrt(count * 2.0)) + 2);
            for (int m = 1; m <= span; ++m) {
                for (int n = 1; n <= span; ++n) {
                    const double term = (m * m) / (d.length * d.length) +
                                        (n * n) / (width * width);
                    frequencies.push_back(base * term);
                }
            }
            std::sort(frequencies.begin(), frequencies.end());
            for (int i = 0; i < count && i < static_cast<int>(frequencies.size()); ++i) {
                ShapeMode mode;
                mode.frequency = frequencies[i];
                mode.node_count = i + 1;
                out.push_back(mode);
            }
            break;
        }
        case Family::Shell: {
            // Two families of motion, combined.
            //
            // Round the rim, the in-plane flexural modes of a thin ring:
            //   f_n = (1/2pi) * n(n^2-1)/sqrt(n^2+1) * (h / (R^2 sqrt12)) * c
            // starting at n = 2, because n = 0 is the ring breathing and n = 1
            // is it translating rather than deforming.
            //
            // Along the axis, the wall bends like a plate strip of the shell's
            // height. A tall thin glass is dominated by the ring modes and is
            // the wine-glass series; a squat mug has its axial modes down in
            // the same range, and they fill in the gaps the ring series leaves.
            //
            // The two are combined as the root of the sum of squares, which is
            // the standard separable approximation for a doubly-stiffened
            // system — exact only when the two motions do not couple, and near
            // enough for everything this generator is for. A full Donnell
            // shell solution would move these by a few per cent and cost a
            // great deal more to get wrong.
            const double height = d.height > 0.0 ? d.height : 2.0 * d.radius;
            const double ring_scale = d.thickness / (d.radius * d.radius * std::sqrt(12.0));
            const double axial_base =
                (M_PI / 2.0) * d.thickness * plate_speed(material) / (height * height);

            std::vector<std::pair<double, int>> found;  // frequency, circumferential n
            const int ring_span = std::max(6, count);
            const int axial_span = std::max(4, count / 2);
            for (int i = 0; i < ring_span; ++i) {
                const double n = i + 2.0;
                const double shape = n * (n * n - 1.0) / std::sqrt(n * n + 1.0);
                const double ring = shape * ring_scale * c / (2.0 * M_PI);
                for (int m = 0; m < axial_span; ++m) {
                    const double axial = axial_base * static_cast<double>(m * m);
                    found.emplace_back(std::sqrt(ring * ring + axial * axial),
                                       static_cast<int>(n));
                }
            }
            std::sort(found.begin(), found.end(),
                      [](const auto& a, const auto& b) { return a.first < b.first; });
            for (int i = 0; i < count && i < static_cast<int>(found.size()); ++i) {
                ShapeMode mode;
                mode.frequency = found[i].first;
                mode.node_count = 2 * found[i].second;  // 2n nodes round the rim
                out.push_back(mode);
            }
            break;
        }
    }
    return out;
}

bool has_analytic_mode_shapes(Family family) {
    return family == Family::Bar;
}

double mode_gain_at(const ShapeSpec& spec, int index, double position) {
    position = std::min(std::max(position, 0.0), 1.0);

    if (spec.family == Family::Bar) {
        // The real free-free mode shape:
        //   Y(x) = cosh(bx) + cos(bx) - sigma (sinh(bx) + sin(bx))
        // normalised so an antinode is 1. Striking a node genuinely fails to
        // excite the mode, which is the whole point of a strike map.
        const double bl = beta_l(index);
        const double sigma = (std::cosh(bl) - std::cos(bl)) / (std::sinh(bl) - std::sin(bl));
        auto shape = [&](double u) {
            const double b = bl * u;
            // cosh overflows past about 710; the bar's high modes reach that
            // well inside the length, and the difference form below is the
            // stable way to evaluate what is really a decaying combination.
            if (b > 30.0) return std::cos(b) - sigma * std::sin(b);
            return std::cosh(b) + std::cos(b) - sigma * (std::sinh(b) + std::sin(b));
        };
        const double value = shape(position);
        // Normalise against the end, which is an antinode for every free-free
        // mode, so gains come out on a comparable scale.
        const double reference = std::abs(shape(0.0));
        return reference > 0.0 ? std::min(std::abs(value) / reference, 1.0) : std::abs(value);
    }

    // Everything else: a smooth standing-wave approximation. It puts nodes in
    // plausible places rather than measured ones, and the generator marks the
    // model accordingly instead of claiming otherwise.
    const double lobes = index + 2.0;
    return std::abs(std::cos(M_PI * lobes * position));
}

}  // namespace modal::gen
