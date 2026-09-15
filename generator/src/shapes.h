// The shape of a thing, and therefore the frequencies it rings at.
//
// This half is real physics rather than a fitted curve. A free-free bar's
// modes stand in the ratio of the squares of the roots of
// cos(x)cosh(x) = 1 — 1 : 2.757 : 5.404 : 8.933 — and nothing about taste or
// calibration enters into it. Give the dimensions and the wave speed and the
// frequencies follow.
//
// What each family is good for is the interesting part, because a shape with
// a closed form is not always the shape you have:
//
//   bar    a rod, a bar, a pipe struck across its length, a railing, cutlery
//   plate  a tile, a pane, a sheet, a tray
//   shell  a mug, a glass, a bell, a bowl, a bottle — anything hollow round
//
// A shell is the one that needs care, and the governing dimension is its
// height. Its circumferential ring modes alone are 1 : 2.83 : 5.42 : 8.77 —
// very stretched, and only a handful fit under the Nyquist limit. But a shell
// of finite height also bends along its axis, and those axial modes go as
// 1/height^2:
//
//   shallow and wide (a bowl, a bell, the rim of a wine glass) puts the axial
//   modes far above the ring ones, leaving the clean stretched series that
//   makes a bell a bell and lets a wine glass sing one note;
//
//   tall and narrow (a tumbler, a vase, a length of pipe) brings them down
//   among the ring modes, filling the gaps and giving the dense, less
//   stretched series that crockery actually has.
//
// So --height is not a detail. It is the difference between a bell and a mug.
//
// A real mug is a shell with a base and a handle welded to it, and neither
// of those is in the closed form. The ratios come out close and the absolute
// pitch comes out high, which is why `--fundamental` exists: take the series
// from the physics and the pitch from the object in front of you.
#pragma once

#include <string>
#include <vector>

#include "materials.h"

namespace modal::gen {

enum class Family { Bar, Plate, Shell };

// The dimensions a shape might need. Which ones matter depends on the family,
// and `describe_dimensions` says which.
struct Dimensions {
    double length = 0.0;     // m — bar length, plate long side
    double width = 0.0;      // m — plate short side; defaults to length
    double thickness = 0.0;  // m — bar depth in bending, plate thickness, shell wall
    double radius = 0.0;     // m — shell radius, or rod radius for a round bar
    double bore = 0.0;       // m — inner radius of a tubular bar; 0 for solid
    double height = 0.0;     // m — shell height; defaults to twice the radius.
                             //     Short rings like a bell, tall like a tube.
};

struct ShapeSpec {
    Family family = Family::Bar;
    Dimensions dimensions;
    // Round rather than rectangular cross-section, for a bar.
    bool round_section = false;
};

// One mode of a shape, before a material's damping is applied.
struct ShapeMode {
    double frequency = 0.0;
    // Where this mode is quiet, along the object's principal axis, as
    // positions in 0..1. Used to build genuine strike gains for the families
    // whose mode shapes have a closed form.
    int node_count = 0;
};

// Parses a family name. Returns false for anything unknown, so the caller can
// list what there is.
bool parse_family(const std::string& name, Family& out);
std::string family_name(Family family);

// What this family needs, for the error message when it does not get it.
std::string describe_dimensions(Family family);
bool validate(const ShapeSpec& spec, std::string& error);

// The mode frequencies, in ascending order. `count` is an upper bound; a
// family may return fewer if its series runs past the usable band.
std::vector<ShapeMode> mode_series(const ShapeSpec& spec, const Material& material, int count);

// The gain of mode `index` at a strike `position` along the object, 0..1.
//
// For a free-free bar this is the real mode shape, so striking at a node
// genuinely fails to excite that mode — which is the effect the strike map in
// the GUI has had no data for until now. For the other families it falls back
// to a smooth approximation and says so through `has_analytic_mode_shapes`.
double mode_gain_at(const ShapeSpec& spec, int index, double position);
bool has_analytic_mode_shapes(Family family);

}  // namespace modal::gen
