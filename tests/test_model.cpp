// One case per invariant in BUILD_PLAN section 4.2. A loader that accepts a
// broken file produces a sound nobody can explain later.
#include "doctest.h"

#include <string>

#include "modal/model.h"

namespace {

constexpr double kRate = 48000.0;

std::string file(const std::string& modes, const std::string& extra = "") {
    return "{\"format\":\"modal\",\"version\":1,\"name\":\"t\",\"modes\":" + modes +
           (extra.empty() ? "" : "," + extra) + "}";
}

const char* kOneMode = "[{\"f\":1000,\"tau\":0.5,\"a\":1.0}]";

}  // namespace

TEST_CASE("a well formed file loads") {
    const auto result = modal::load_from_string(file(kOneMode), kRate);
    REQUIRE(result.ok);
    CHECK(result.model.modes.size() == 1);
    CHECK(result.model.modes[0].f == doctest::Approx(1000.0));
}

TEST_CASE("malformed input is rejected rather than guessed at") {
    CHECK_FALSE(modal::load_from_string("", kRate).ok);
    CHECK_FALSE(modal::load_from_string("{", kRate).ok);
    CHECK_FALSE(modal::load_from_string("[1,2,3]", kRate).ok);
    CHECK_FALSE(modal::load_from_string("{\"format\":\"wav\",\"version\":1}", kRate).ok);
    CHECK_FALSE(modal::load_from_string("{\"format\":\"modal\",\"version\":2}", kRate).ok);
}

TEST_CASE("1. modes are present and within the length limit") {
    CHECK_FALSE(modal::load_from_string(file("[]"), kRate).ok);
    CHECK_FALSE(modal::load_from_string("{\"format\":\"modal\",\"version\":1}", kRate).ok);

    std::string many = "[";
    for (int i = 0; i < modal::kMaxModesInFile + 1; ++i) {
        if (i) many += ",";
        many += "{\"f\":1000,\"tau\":0.5,\"a\":1.0}";
    }
    many += "]";
    CHECK_FALSE(modal::load_from_string(file(many), kRate).ok);
}

TEST_CASE("2. modes end up sorted by amplitude, and the strike gains follow") {
    const auto result = modal::load_from_string(
        file("[{\"f\":1000,\"tau\":0.5,\"a\":0.4},"
             " {\"f\":2000,\"tau\":0.5,\"a\":1.0}]",
             "\"strike_positions\":[{\"u\":0,\"v\":0,\"gains\":[0.1,0.9]}]"),
        kRate);
    REQUIRE(result.ok);
    CHECK(result.warnings.size() == 1);
    CHECK(result.model.modes[0].f == doctest::Approx(2000.0));
    // The gains are positional, so reordering the modes without reordering
    // these would quietly apply the wrong gain to every mode.
    CHECK(result.model.strike_positions[0].gains[0] == doctest::Approx(0.9));
    CHECK(result.model.strike_positions[0].gains[1] == doctest::Approx(0.1));
}

TEST_CASE("3. a mode outside the band is dropped with a warning, not an error") {
    // 20 kHz is fine at 48 kHz and impossible at 44.1 — the same file has to
    // load at both, which is why this is not fatal.
    const auto at48 = modal::load_from_string(
        file("[{\"f\":1000,\"tau\":0.5,\"a\":1.0},{\"f\":20000,\"tau\":0.5,\"a\":0.5}]"), 48000.0);
    REQUIRE(at48.ok);
    CHECK(at48.model.modes.size() == 2);

    const auto at44 = modal::load_from_string(
        file("[{\"f\":1000,\"tau\":0.5,\"a\":1.0},{\"f\":20000,\"tau\":0.5,\"a\":0.5}]"), 44100.0);
    REQUIRE(at44.ok);
    CHECK(at44.model.modes.size() == 1);
    CHECK(at44.warnings.size() == 1);

    // Below 20 Hz goes the same way.
    const auto low = modal::load_from_string(
        file("[{\"f\":1000,\"tau\":0.5,\"a\":1.0},{\"f\":5,\"tau\":0.5,\"a\":0.5}]"), kRate);
    REQUIRE(low.ok);
    CHECK(low.model.modes.size() == 1);

    // But a file with nothing left is an error, not a silent model.
    CHECK_FALSE(modal::load_from_string(file("[{\"f\":30000,\"tau\":0.5,\"a\":1.0}]"), kRate).ok);
}

TEST_CASE("3b. dropping a mode drops its strike gain with it") {
    const auto result = modal::load_from_string(
        file("[{\"f\":1000,\"tau\":0.5,\"a\":1.0},{\"f\":20000,\"tau\":0.5,\"a\":0.5}]",
             "\"strike_positions\":[{\"u\":0,\"v\":0,\"gains\":[0.7,0.3]}]"),
        44100.0);
    REQUIRE(result.ok);
    REQUIRE(result.model.modes.size() == 1);
    CHECK(result.model.strike_positions[0].gains.size() == 1);
    CHECK(result.model.strike_positions[0].gains[0] == doctest::Approx(0.7));
}

TEST_CASE("4. tau must be inside the physical range") {
    CHECK_FALSE(modal::load_from_string(file("[{\"f\":1000,\"tau\":0.0001,\"a\":1.0}]"), kRate).ok);
    CHECK_FALSE(modal::load_from_string(file("[{\"f\":1000,\"tau\":25.0,\"a\":1.0}]"), kRate).ok);
    CHECK(modal::load_from_string(file("[{\"f\":1000,\"tau\":10.0,\"a\":1.0}]"), kRate).ok);
}

TEST_CASE("5. amplitudes are positive, bounded, and normalised on load") {
    CHECK_FALSE(modal::load_from_string(file("[{\"f\":1000,\"tau\":0.5,\"a\":0.0}]"), kRate).ok);
    CHECK_FALSE(modal::load_from_string(file("[{\"f\":1000,\"tau\":0.5,\"a\":-0.5}]"), kRate).ok);
    CHECK_FALSE(modal::load_from_string(file("[{\"f\":1000,\"tau\":0.5,\"a\":1.5}]"), kRate).ok);

    const auto quiet = modal::load_from_string(
        file("[{\"f\":1000,\"tau\":0.5,\"a\":0.5},{\"f\":2000,\"tau\":0.5,\"a\":0.25}]"), kRate);
    REQUIRE(quiet.ok);
    CHECK(quiet.model.modes[0].a == doctest::Approx(1.0));
    CHECK(quiet.model.modes[1].a == doctest::Approx(0.5));
}

TEST_CASE("6. every strike position carries one gain per mode") {
    CHECK_FALSE(modal::load_from_string(
                    file(kOneMode, "\"strike_positions\":[{\"u\":0,\"v\":0,\"gains\":[1.0,0.5]}]"),
                    kRate)
                    .ok);
    CHECK_FALSE(modal::load_from_string(
                    file(kOneMode, "\"strike_positions\":[{\"u\":0,\"v\":0,\"gains\":[]}]"), kRate)
                    .ok);
}

TEST_CASE("7. strike positions lie in the unit square") {
    CHECK_FALSE(modal::load_from_string(
                    file(kOneMode, "\"strike_positions\":[{\"u\":1.5,\"v\":0,\"gains\":[1.0]}]"),
                    kRate)
                    .ok);
    CHECK_FALSE(modal::load_from_string(
                    file(kOneMode, "\"strike_positions\":[{\"u\":0,\"v\":-0.1,\"gains\":[1.0]}]"),
                    kRate)
                    .ok);
}

TEST_CASE("coefficients are never stored, so a model loads at any rate") {
    const modal::Mode mode{1000.0, 0.5, 1.0};
    const auto at48 = modal::coefficients_for(mode, 48000.0);
    const auto at44 = modal::coefficients_for(mode, 44100.0);
    CHECK(at48.a1 != doctest::Approx(at44.a1));
    // Both poles stay strictly inside the unit circle, or the mode grows
    // without bound instead of decaying.
    CHECK(-at48.a2 < 1.0f);
    CHECK(-at44.a2 < 1.0f);
}

TEST_CASE("a ten second decay still leaves the pole inside the circle in float32") {
    const modal::Mode mode{1000.0, modal::kMaxTau, 1.0};
    const auto c = modal::coefficients_for(mode, 192000.0);
    CHECK(-c.a2 < 1.0f);
    CHECK(-c.a2 > 0.99f);
}
