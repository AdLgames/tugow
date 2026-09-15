// modal-gen - a model from a shape and a material, with no recording.
//
//   modal-gen --shape bar --material steel --length 0.3 --thickness 0.01 \
//             --out models/steel_bar.modal
//
// The fitter turns a recording into a model. This turns a description into
// one, which matters for two reasons the build plan already names: §11 wants
// a CC0 starter library, and hand-authoring models is called impractical —
// the three that exist took someone an afternoon and follow power laws exact
// to four decimal places, which is a generator run by hand.
//
// It does not replace the fitter and cannot. A generated model is an
// idealised object of that shape and material; a fitted one is *your* mug,
// with its chip and its handle. The week 2 gate asks whether a fitted mug is
// recognisable as that mug, and nothing here answers it.

#include <cstdio>
#include <cstring>
#include <string>

#include "generate.h"
#include "modal/model.h"

namespace {

void usage() {
    std::printf(
        "modal-gen --shape SHAPE --material MATERIAL [dimensions] [options]\n"
        "\n"
        "  shapes     bar    a rod, bar, pipe, railing, cutlery\n"
        "             plate  a tile, pane, sheet, tray\n"
        "             shell  a mug, glass, bowl, bell, bottle\n"
        "\n"
        "  dimensions --length M      bar length, plate long side\n"
        "             --width M       plate short side (default: square)\n"
        "             --thickness M   bar depth, plate thickness, shell wall\n"
        "             --radius M      shell radius, or round-bar radius\n"
        "             --bore M        inner radius of a tubular bar\n"
        "             --height M      shell height (default: twice the radius)\n"
        "             --round         a bar with a circular cross-section\n"
        "\n"
        "  options    --out FILE      where to write (default: stdout)\n"
        "             --name NAME     model name (default: from shape+material)\n"
        "             --modes N       how many to keep (default 24)\n"
        "             --fundamental HZ  retune the series to this pitch,\n"
        "                               keeping every ratio\n"
        "             --strikes N     write N strike positions along the object\n"
        "             --contact MS    override the contact time reference\n"
        "             --rate HZ       sample rate the band is checked against\n"
        "             --list          print the shapes and materials and stop\n");
}

void list_options() {
    std::printf("shapes\n");
    for (const char* name : {"bar", "plate", "shell"}) {
        modal::gen::Family family;
        modal::gen::parse_family(name, family);
        std::printf("  %-7s needs %s\n", name,
                    modal::gen::describe_dimensions(family).c_str());
    }
    std::printf("\nmaterials\n");
    std::printf("  %-11s %8s %8s %9s %7s\n", "name", "E(GPa)", "rho", "c(m/s)", "tau@1k");
    for (const modal::gen::Material& m : modal::gen::materials()) {
        std::printf("  %-11s %8.0f %8.0f %9.0f %7.2f\n", m.name.c_str(), m.youngs_gpa,
                    m.density, m.wave_speed(), m.tau_1k);
    }
}

}  // namespace

int main(int argc, char** argv) {
    modal::gen::Request request;
    std::string shape_name, material_name, out_path;
    bool listed = false;

    for (int i = 1; i < argc; ++i) {
        const std::string flag = argv[i];
        const bool has_value = i + 1 < argc;
        auto value = [&]() { return std::string(argv[++i]); };
        if (flag == "--shape" && has_value) shape_name = value();
        else if (flag == "--material" && has_value) material_name = value();
        else if (flag == "--out" && has_value) out_path = value();
        else if (flag == "--name" && has_value) request.name = value();
        else if (flag == "--length" && has_value) request.shape.dimensions.length = std::stod(value());
        else if (flag == "--width" && has_value) request.shape.dimensions.width = std::stod(value());
        else if (flag == "--thickness" && has_value) request.shape.dimensions.thickness = std::stod(value());
        else if (flag == "--radius" && has_value) request.shape.dimensions.radius = std::stod(value());
        else if (flag == "--bore" && has_value) request.shape.dimensions.bore = std::stod(value());
        else if (flag == "--height" && has_value) request.shape.dimensions.height = std::stod(value());
        else if (flag == "--round") request.shape.round_section = true;
        else if (flag == "--modes" && has_value) request.max_modes = std::stoi(value());
        else if (flag == "--fundamental" && has_value) request.fundamental = std::stod(value());
        else if (flag == "--strikes" && has_value) request.strike_positions = std::stoi(value());
        else if (flag == "--contact" && has_value) request.contact_time_ref_ms = std::stod(value());
        else if (flag == "--rate" && has_value) request.sample_rate = std::stod(value());
        else if (flag == "--list") { list_options(); listed = true; }
        else if (flag == "-h" || flag == "--help") { usage(); return 0; }
        else {
            std::fprintf(stderr, "unknown or incomplete argument: %s\n", flag.c_str());
            return 1;
        }
    }
    if (listed) return 0;

    if (shape_name.empty() || material_name.empty()) {
        usage();
        return 1;
    }
    if (!modal::gen::parse_family(shape_name, request.shape.family)) {
        std::fprintf(stderr, "no such shape: %s — try --list\n", shape_name.c_str());
        return 1;
    }
    request.material = modal::gen::find_material(material_name);
    if (request.material == nullptr) {
        std::fprintf(stderr, "no such material: %s — try --list\n", material_name.c_str());
        return 1;
    }
    if (request.name.empty()) request.name = material_name + "_" + shape_name;

    modal::gen::Result result = modal::gen::generate(request);
    if (!result.ok) {
        std::fprintf(stderr, "error: %s\n", result.error.c_str());
        if (!result.error.empty() && result.error.find("--") != std::string::npos) {
            std::fprintf(stderr, "a %s needs %s\n", shape_name.c_str(),
                         modal::gen::describe_dimensions(request.shape.family).c_str());
        }
        return 1;
    }
    for (const std::string& note : result.notes) {
        std::fprintf(stderr, "note: %s\n", note.c_str());
    }

    std::string source = shape_name + " of " + material_name + ", generated by modal-gen";
    if (request.fundamental > 0.0) source += ", retuned to the given fundamental";
    const std::string json = modal::gen::to_json(result.model, source);

    // Never write a file the runtime cannot open. The loader is the authority
    // on that, so it gets asked before anything reaches disk.
    modal::LoadResult check = modal::load_from_string(json, request.sample_rate);
    if (!check.ok) {
        std::fprintf(stderr, "error: the generated model does not load: %s\n",
                     check.error.c_str());
        return 1;
    }
    for (const std::string& warning : check.warnings) {
        std::fprintf(stderr, "note: %s\n", warning.c_str());
    }

    if (out_path.empty()) {
        std::fputs(json.c_str(), stdout);
    } else {
        std::FILE* file = std::fopen(out_path.c_str(), "wb");
        if (file == nullptr) {
            std::fprintf(stderr, "error: could not write %s\n", out_path.c_str());
            return 1;
        }
        std::fwrite(json.data(), 1, json.size(), file);
        std::fclose(file);
    }

    const modal::Model& model = result.model;
    std::fprintf(stderr, "%s — %zu modes, %.1f Hz to %.0f Hz, longest ring %.2f s%s\n",
                 model.name.c_str(), model.modes.size(), model.modes.front().f,
                 model.modes.back().f, model.modes.front().tau,
                 result.strikes_are_analytic ? ", strike map from real mode shapes" : "");
    return 0;
}
