// The pool runs on the audio thread, where a mistake is a click rather than
// a crash, so the things checked here are the ones nothing else would catch.
#include "doctest.h"

#include <cmath>
#include <vector>

#include "modal/bank.h"
#include "modal/model.h"
#include "modal/voice.h"

namespace {

constexpr double kRate = 48000.0;

modal::Model an_object(double f = 1000.0, double tau = 0.4) {
    modal::Model model;
    for (int i = 0; i < 8; ++i) {
        model.modes.push_back({f * (1.0 + 2.1 * i), tau / (1.0 + 0.5 * i), 1.0 / (1.0 + i)});
    }
    return model;
}

modal::ContactEvent an_impact(float impulse = 1.0f, float distance = 1.0f) {
    modal::ContactEvent event;
    event.model_id = 0;
    event.impulse = impulse;
    event.distance = distance;
    event.type = modal::ContactType::Impact;
    return event;
}

double peak_of(const std::vector<float>& block) {
    double peak = 0.0;
    for (float sample : block) peak = std::max(peak, static_cast<double>(std::fabs(sample)));
    return peak;
}

}  // namespace

TEST_CASE("a struck voice makes a sound and then stops on its own") {
    const modal::Model model = an_object();
    const modal::Model* models[] = {&model};
    modal::VoicePool pool;
    pool.resize(16, kRate);
    pool.set_models(models, 1);

    CHECK(pool.start(an_impact()) != 0);
    CHECK(pool.active_voices() == 1);

    std::vector<float> block(512, 0.0f);
    pool.mix(block.data(), 512);
    CHECK(peak_of(block) > 0.001);

    // Left to run, the voice retires itself rather than sitting in the pool
    // consuming a slot for a sound nobody can hear.
    for (int i = 0; i < 400; ++i) {
        std::fill(block.begin(), block.end(), 0.0f);
        pool.mix(block.data(), 512);
    }
    CHECK(pool.active_voices() == 0);
}

TEST_CASE("a full pool steals the quietest voice, never the newest") {
    const modal::Model model = an_object(500.0, 2.0);
    const modal::Model* models[] = {&model};
    modal::VoicePool pool;
    pool.resize(modal::kMinVoices, kRate);
    pool.set_models(models, 1);

    // Fill it with quiet voices, then let them age past the protection
    // window so they can be taken.
    for (int i = 0; i < modal::kMinVoices; ++i) CHECK(pool.start(an_impact(0.01f)) != 0);
    CHECK(pool.active_voices() == modal::kMinVoices);
    std::vector<float> block(2048, 0.0f);
    for (int i = 0; i < 30; ++i) pool.mix(block.data(), 2048);

    const int before = pool.stolen_voices();
    CHECK(pool.start(an_impact(5.0f)) != 0);
    CHECK(pool.stolen_voices() == before + 1);
}

TEST_CASE("a voice that just started is never stolen") {
    // Taking a loud impact away twenty milliseconds in is the worst artefact
    // the pool can make — worse than dropping the sound asking for a voice.
    const modal::Model model = an_object(500.0, 2.0);
    const modal::Model* models[] = {&model};
    modal::VoicePool pool;
    pool.resize(modal::kMinVoices, kRate);
    pool.set_models(models, 1);

    for (int i = 0; i < modal::kMinVoices; ++i) CHECK(pool.start(an_impact(1.0f)) != 0);
    // No mixing, so nothing has aged at all.
    const int dropped_before = pool.dropped_events();
    CHECK(pool.start(an_impact(9.0f)) == 0);
    CHECK(pool.dropped_events() == dropped_before + 1);
    CHECK(pool.stolen_voices() == 0);
}

TEST_CASE("an unknown model is refused rather than played as silence") {
    modal::VoicePool pool;
    pool.resize(16, kRate);
    modal::ContactEvent event = an_impact();
    event.model_id = 7;
    CHECK(pool.start(event) == 0);
    CHECK(pool.dropped_events() == 1);
}

TEST_CASE("a continuous contact is refreshed, not retriggered") {
    // A marble rolling for a second sends sixty events. Each one starting a
    // fresh voice would be sixty voices and a machine-gun.
    const modal::Model model = an_object();
    const modal::Model* models[] = {&model};
    modal::VoicePool pool;
    pool.resize(16, kRate);
    pool.set_models(models, 1);

    modal::ContactEvent roll = an_impact();
    roll.type = modal::ContactType::Roll;
    roll.normal_force = 1.0f;
    const uint32_t id = pool.start(roll);
    REQUIRE(id != 0);

    for (int i = 0; i < 60; ++i) {
        roll.voice_hint = id;
        CHECK(pool.start(roll) == id);
    }
    CHECK(pool.active_voices() == 1);

    // And a release lets it fade instead of cutting it.
    roll.type = modal::ContactType::Release;
    roll.voice_hint = id;
    CHECK(pool.start(roll) == id);
    std::vector<float> block(2048, 0.0f);
    for (int i = 0; i < 200; ++i) pool.mix(block.data(), 2048);
    CHECK(pool.active_voices() == 0);
}

TEST_CASE("level of detail drops modes with distance and with pressure") {
    modal::LodSettings lod;
    CHECK(modes_for(lod, 1.0f, 0.0f) == lod.near_modes);
    CHECK(modes_for(lod, 10.0f, 0.0f) == lod.mid_modes);
    CHECK(modes_for(lod, 30.0f, 0.0f) == lod.far_modes);
    CHECK(modes_for(lod, 100.0f, 0.0f) == lod.distant_modes);
    // A busy pool overrides distance: everything close is also cheap.
    CHECK(modes_for(lod, 1.0f, 0.95f) == lod.distant_modes);
}

TEST_CASE("a distant impact costs fewer modes than a near one") {
    const modal::Model model = an_object();
    const modal::Model* models[] = {&model};
    modal::VoicePool pool;
    pool.resize(64, kRate);
    pool.set_models(models, 1);

    pool.start(an_impact(1.0f, 1.0f));
    const uint32_t near_modes = pool.voices()[0].bank.active_modes;
    pool.start(an_impact(1.0f, 100.0f));
    uint32_t far_modes = 0;
    for (const modal::Voice& voice : pool.voices()) {
        if (voice.active && voice.bank.active_modes != near_modes) far_modes = voice.bank.active_modes;
    }
    CHECK(far_modes > 0);
    CHECK(far_modes < near_modes);
}

TEST_CASE("the output never leaves the rails, however many voices are running") {
    // Two hundred impacts at once will exceed full scale, and hard clipping
    // sounds like a bug report.
    const modal::Model model = an_object();
    const modal::Model* models[] = {&model};
    modal::VoicePool pool;
    pool.resize(modal::kMaxVoices, kRate);
    pool.set_models(models, 1);
    for (int i = 0; i < modal::kMaxVoices; ++i) pool.start(an_impact(8.0f));

    std::vector<float> block(512, 0.0f);
    for (int b = 0; b < 20; ++b) {
        std::fill(block.begin(), block.end(), 0.0f);
        pool.mix(block.data(), 512);
        for (float sample : block) {
            CHECK(std::isfinite(sample));
            CHECK(std::fabs(sample) <= 1.0f);
        }
    }
}

TEST_CASE("a poisoned voice is retired, not left to spoil the mix") {
    const modal::Model model = an_object();
    const modal::Model* models[] = {&model};
    modal::VoicePool pool;
    pool.resize(16, kRate);
    pool.set_models(models, 1);
    REQUIRE(pool.start(an_impact()) != 0);

    std::vector<float> block(512, 0.0f);
    pool.mix(block.data(), 512);
    // Corrupt the state the way a bad coefficient would.
    const_cast<modal::Voice&>(pool.voices()[0]).bank.y1[0] = std::nanf("");
    std::fill(block.begin(), block.end(), 0.0f);
    pool.mix(block.data(), 512);

    CHECK(pool.nan_resets() == 1);
    CHECK(pool.active_voices() == 0);
    for (float sample : block) CHECK(std::isfinite(sample));
}

TEST_CASE("scalar and SIMD paths agree") {
    // They are two spellings of one recursion, and the moment they disagree
    // a bug reproduces on one machine and not another.
    modal::Model model = an_object(440.0, 1.0);
    modal::Bank scalar, simd;
    modal::bank_set(scalar, model, kRate, modal::kMaxModes, nullptr);
    modal::bank_set(simd, model, kRate, modal::kMaxModes, nullptr);

    std::vector<float> x(4096, 0.0f);
    x[0] = 1.0f;
    for (int i = 100; i < 4096; i += 137) x[i] = 0.25f;

    std::vector<float> a(4096, 0.0f), b(4096, 0.0f);
    modal::bank_process(scalar, x.data(), a.data(), 4096);
    modal::bank_process_simd(simd, x.data(), b.data(), 4096);
    for (int i = 0; i < 4096; ++i) {
        CHECK(b[i] == doctest::Approx(a[i]).epsilon(1e-5));
    }
}

TEST_CASE("the slowest decay is the one that decides when a voice is done") {
    modal::Model model;
    model.modes.push_back({1000.0, 0.05, 1.0});
    model.modes.push_back({2000.0, 4.00, 0.5});
    modal::Bank bank;
    modal::bank_set(bank, model, kRate, modal::kMaxModes, nullptr);
    const double expected = std::exp(-1.0 / (4.0 * kRate));
    CHECK(modal::bank_slowest_decay(bank) == doctest::Approx(expected).epsilon(1e-5));
}
