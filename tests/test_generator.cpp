// The generator, checked against textbook answers rather than against itself.
//
// Its whole claim is that the frequencies come from physics, so the tests are
// the physics: the free-free bar's ratios are the squares of the roots of
// cos(x)cosh(x) = 1 and are printed in every acoustics text; the ring series
// is n(n^2-1)/sqrt(n^2+1). If those hold and the loader accepts the output,
// the generator is doing what it says.
#include "doctest.h"

#include <algorithm>
#include <cmath>
#include <string>

#include "generate.h"
#include "materials.h"
#include "modal/model.h"
#include "shapes.h"

namespace {

constexpr double kRate = 48000.0;

modal::gen::Request bar_request(const char* material = "steel") {
    modal::gen::Request request;
    request.shape.family = modal::gen::Family::Bar;
    request.shape.dimensions.length = 0.30;
    request.shape.dimensions.thickness = 0.01;
    request.material = modal::gen::find_material(material);
    request.name = "test_bar";
    request.max_modes = 8;
    return request;
}

}  // namespace

TEST_CASE("a free-free bar has the textbook mode ratios") {
    // 1 : 2.756 : 5.404 : 8.933 : 13.35, from (m_n/m_1)^2 with
    // m = 3.0112, 5, 7, 9, 11. These are not tunable — a struck bar is
    // strongly inharmonic and that is why a xylophone bar has to be
    // undercut to bring its second mode into a musical interval.
    const modal::Material* steel = nullptr;
    const modal::gen::Material* material = modal::gen::find_material("steel");
    REQUIRE(material != nullptr);
    (void)steel;

    modal::gen::ShapeSpec spec;
    spec.family = modal::gen::Family::Bar;
    spec.dimensions.length = 0.30;
    spec.dimensions.thickness = 0.01;

    const auto modes = modal::gen::mode_series(spec, *material, 5);
    REQUIRE(modes.size() == 5);
    const double f0 = modes[0].frequency;
    CHECK(modes[1].frequency / f0 == doctest::Approx(2.7565).epsilon(0.001));
    CHECK(modes[2].frequency / f0 == doctest::Approx(5.4039).epsilon(0.001));
    CHECK(modes[3].frequency / f0 == doctest::Approx(8.9330).epsilon(0.001));
    CHECK(modes[4].frequency / f0 == doctest::Approx(13.344).epsilon(0.001));
}

TEST_CASE("a bar's pitch scales as the physics says") {
    const modal::gen::Material* material = modal::gen::find_material("steel");
    modal::gen::ShapeSpec spec;
    spec.family = modal::gen::Family::Bar;
    spec.dimensions.length = 0.30;
    spec.dimensions.thickness = 0.01;
    const double base = modal::gen::mode_series(spec, *material, 1)[0].frequency;

    // f goes as 1/L^2: twice as long is two octaves down.
    spec.dimensions.length = 0.60;
    CHECK(modal::gen::mode_series(spec, *material, 1)[0].frequency ==
          doctest::Approx(base / 4.0).epsilon(1e-6));

    // and linearly in thickness.
    spec.dimensions.length = 0.30;
    spec.dimensions.thickness = 0.02;
    CHECK(modal::gen::mode_series(spec, *material, 1)[0].frequency ==
          doctest::Approx(base * 2.0).epsilon(1e-6));
}

TEST_CASE("a shallow shell is the bell and wine-glass ring series") {
    // Axial stiffness goes as 1/height^2, so a shallow shell puts its axial
    // modes far above its ring ones and what is left in the low range is the
    // pure ring series. This is why a bell and the rim of a wine glass ring
    // on one clear stretched series, and a tall tumbler does not.
    const modal::gen::Material* material = modal::gen::find_material("glass");
    modal::gen::ShapeSpec spec;
    spec.family = modal::gen::Family::Shell;
    spec.dimensions.radius = 0.035;
    spec.dimensions.thickness = 0.001;
    spec.dimensions.height = 0.015;

    const auto modes = modal::gen::mode_series(spec, *material, 4);
    REQUIRE(modes.size() == 4);
    auto ring = [](double n) { return n * (n * n - 1.0) / std::sqrt(n * n + 1.0); };
    const double f0 = modes[0].frequency;
    CHECK(modes[1].frequency / f0 == doctest::Approx(ring(3) / ring(2)).epsilon(1e-9));
    CHECK(modes[2].frequency / f0 == doctest::Approx(ring(4) / ring(2)).epsilon(1e-9));
    CHECK(modes[3].frequency / f0 == doctest::Approx(ring(5) / ring(2)).epsilon(1e-9));

    // A wine glass of these dimensions rings in the hundreds of hertz, not
    // the tens or the thousands. This is the sanity check that the constants
    // are assembled the right way up.
    CHECK(f0 > 300.0);
    CHECK(f0 < 900.0);
}

TEST_CASE("a tall shell has axial modes the ring series does not") {
    // A mug is a cylinder tall enough that its axial modes land among its
    // ring modes and fill in the gaps — the difference between a bell and a
    // piece of crockery, and the reason --height exists.
    const modal::gen::Material* material = modal::gen::find_material("ceramic");
    modal::gen::ShapeSpec spec;
    spec.family = modal::gen::Family::Shell;
    spec.dimensions.radius = 0.040;
    spec.dimensions.thickness = 0.005;
    spec.dimensions.height = 0.09;

    const auto squat = modal::gen::mode_series(spec, *material, 8);
    REQUIRE(squat.size() == 8);
    // The second mode must be much closer than the ring series' 2.83, or the
    // axial family is not contributing anything.
    CHECK(squat[1].frequency / squat[0].frequency < 2.0);
    // Ascending, and nothing degenerate.
    for (size_t i = 1; i < squat.size(); ++i) {
        CHECK(squat[i].frequency > squat[i - 1].frequency);
    }
}

TEST_CASE("a striking position at a node does not excite its mode") {
    modal::gen::ShapeSpec spec;
    spec.family = modal::gen::Family::Bar;
    spec.dimensions.length = 0.30;
    spec.dimensions.thickness = 0.01;

    // Every free-free mode is an antinode at the end, so a strike there
    // excites all of them.
    CHECK(modal::gen::mode_gain_at(spec, 0, 0.0) == doctest::Approx(1.0));
    CHECK(modal::gen::mode_gain_at(spec, 1, 0.0) == doctest::Approx(1.0));

    // The fundamental's node sits at 0.2242 of the length — the classic
    // suspension point for a xylophone bar, chosen precisely because a bar
    // hung there is not damped at its loudest mode.
    CHECK(modal::gen::mode_gain_at(spec, 0, 0.2242) < 0.02);
    // And the middle is an antinode for the fundamental of a free-free bar.
    CHECK(modal::gen::mode_gain_at(spec, 0, 0.5) > 0.5);
}

TEST_CASE("every generated model loads") {
    for (const modal::gen::Material& material : modal::gen::materials()) {
        for (const char* shape : {"bar", "plate", "shell"}) {
            modal::gen::Request request;
            REQUIRE(modal::gen::parse_family(shape, request.shape.family));
            request.material = &material;
            request.name = material.name + "_" + shape;
            request.max_modes = 16;
            request.strike_positions = 4;
            request.shape.dimensions.length = 0.25;
            request.shape.dimensions.thickness = 0.004;
            request.shape.dimensions.radius = 0.04;

            modal::gen::Result result = modal::gen::generate(request);
            REQUIRE_MESSAGE(result.ok, request.name << ": " << result.error);
            CHECK(!result.model.modes.empty());

            // The loader is the authority on whether a file is usable, so it
            // is what decides here too.
            const std::string json = modal::gen::to_json(result.model, "test");
            modal::LoadResult loaded = modal::load_from_string(json, kRate);
            REQUIRE_MESSAGE(loaded.ok, request.name << ": " << loaded.error);
            CHECK(loaded.model.modes.size() == result.model.modes.size());
            CHECK(loaded.model.strike_positions.size() == 4u);
            // Amplitudes normalised, loudest first — what the LOD truncation
            // depends on.
            CHECK(loaded.model.modes.front().a == doctest::Approx(1.0));
            for (size_t i = 1; i < loaded.model.modes.size(); ++i) {
                CHECK(loaded.model.modes[i].a <= loaded.model.modes[i - 1].a + 1e-9);
            }
        }
    }
}

TEST_CASE("a square plate's degenerate modes are merged") {
    // (m,n) and (n,m) of a square plate are the same frequency, and a bank
    // given both spends two of its forty-eight slots on one partial.
    modal::gen::Request request;
    request.shape.family = modal::gen::Family::Plate;
    request.shape.dimensions.length = 0.15;
    request.shape.dimensions.thickness = 0.006;
    request.material = modal::gen::find_material("ceramic");
    request.name = "square";
    request.max_modes = 12;

    modal::gen::Result result = modal::gen::generate(request);
    REQUIRE(result.ok);
    // No two modes within the fitter's one per cent merge tolerance.
    for (size_t i = 0; i < result.model.modes.size(); ++i) {
        for (size_t j = i + 1; j < result.model.modes.size(); ++j) {
            const double gap = std::abs(result.model.modes[i].f - result.model.modes[j].f);
            CHECK(gap > 0.01 * std::min(result.model.modes[i].f, result.model.modes[j].f));
        }
    }

    // And the file must not make the loader complain about anything, which
    // merging can otherwise cause by disturbing the amplitude order.
    const std::string json = modal::gen::to_json(result.model, "test");
    modal::LoadResult loaded = modal::load_from_string(json, kRate);
    REQUIRE(loaded.ok);
    for (const std::string& warning : loaded.warnings) FAIL_CHECK(warning);
    CHECK(loaded.warnings.empty());
}

TEST_CASE("retuning moves the pitch and keeps the ratios") {
    modal::gen::Request request = bar_request();
    request.fundamental = 440.0;
    modal::gen::Result tuned = modal::gen::generate(request);
    REQUIRE(tuned.ok);
    CHECK(tuned.model.modes.front().f == doctest::Approx(440.0).epsilon(1e-9));

    modal::gen::Request plain = bar_request();
    modal::gen::Result natural = modal::gen::generate(plain);
    REQUIRE(natural.ok);
    REQUIRE(tuned.model.modes.size() == natural.model.modes.size());
    for (size_t i = 0; i < tuned.model.modes.size(); ++i) {
        CHECK(tuned.model.modes[i].f / tuned.model.modes[0].f ==
              doctest::Approx(natural.model.modes[i].f / natural.model.modes[0].f)
                  .epsilon(1e-9));
    }
}

TEST_CASE("the damping law reproduces the hand-authored library") {
    // Each shipped model follows tau = tau_1k * (f/1000)^-p exactly. The
    // generator carries those same constants, so a generated ceramic object
    // retuned to the mug's fundamental must land on the mug's decay.
    struct Expected { const char* material; double f0; double tau0; };
    const Expected cases[] = {
        {"ceramic", 1245.0, 1.40},
        {"glass", 1180.0, 2.60},
        {"steel", 620.0, 5.40},
    };
    for (const Expected& expected : cases) {
        modal::gen::Request request = bar_request(expected.material);
        request.fundamental = expected.f0;
        modal::gen::Result result = modal::gen::generate(request);
        REQUIRE(result.ok);
        CHECK_MESSAGE(result.model.modes.front().tau ==
                          doctest::Approx(expected.tau0).epsilon(0.01),
                      expected.material);
    }
}

TEST_CASE("a shape without its dimensions fails rather than guessing") {
    modal::gen::Request request;
    request.shape.family = modal::gen::Family::Bar;
    request.material = modal::gen::find_material("steel");
    request.name = "nothing";
    modal::gen::Result result = modal::gen::generate(request);
    CHECK(!result.ok);
    CHECK(result.error.find("--length") != std::string::npos);
}
