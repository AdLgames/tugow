// The voice pool: fixed size, allocated once, never grown.
//
// Everything here runs on the audio thread. No allocation, no locks, no I/O,
// no exceptions. The pool is sized at construction and that is the last time
// memory is touched.
#pragma once

#include <cstdint>
#include <vector>

#include "modal/bank.h"
#include "modal/excitation.h"
#include "modal/queue.h"

namespace modal {

constexpr int kDefaultVoices = 64;
constexpr int kMinVoices = 16;
constexpr int kMaxVoices = 256;

// A voice younger than this is never stolen. Taking a loud impact away
// twenty milliseconds after it started is the worst artefact the pool can
// produce — worse than the sound that wanted the voice being dropped.
constexpr double kProtectedSeconds = 0.020;

// Retired below this. Roughly -80 dBFS.
constexpr float kSilenceThreshold = 1.0e-4f;

struct Voice {
    Bank bank;
    Pulse pulse;
    int pulse_frame = 0;
    uint32_t model_id = 0;
    uint32_t id = 0;  // 0 means free; also what a voice_hint refers to
    uint64_t started_at = 0;
    float energy = 0.0f;   // upper bound on what is left, not a measurement
    float decay = 0.0f;    // per-sample multiplier of the slowest mode
    float gain = 1.0f;
    float pan = 0.0f;
    bool continuous = false;
    bool active = false;
};

// Level of detail. Mode count falls with distance and with how busy the pool
// is; modes are sorted loudest first at load, so truncation always keeps the
// ones that matter.
struct LodSettings {
    float near_metres = 5.0f;
    float mid_metres = 20.0f;
    float far_metres = 50.0f;
    uint32_t near_modes = 48;
    uint32_t mid_modes = 24;
    uint32_t far_modes = 12;
    uint32_t distant_modes = 6;
    float pressure_threshold = 0.75f;  // pool fuller than this drops to distant
};

uint32_t modes_for(const LodSettings& lod, float distance, float pool_pressure);

class VoicePool {
public:
    // The only place memory is touched. Call it before the audio thread
    // exists, never after.
    void resize(int voices, double sample_rate);

    // Models are held by pointer. The pool never loads or frees one; the
    // loading side keeps them alive for as long as the pool can reach them.
    void set_models(const Model* const* models, int count);

    // Consumes the event. Returns the voice id it landed on, or 0 if it was
    // refused — every refusal is counted.
    uint32_t start(const ContactEvent& event);

    // Renders one block, accumulating into `out`. This is the audio
    // callback's body.
    void mix(float* out, int frames);

    int active_voices() const;
    int dropped_events() const { return dropped_; }
    int stolen_voices() const { return stolen_; }
    int nan_resets() const { return nan_resets_; }
    uint64_t frames_rendered() const { return frame_; }
    const std::vector<Voice>& voices() const { return voices_; }

    LodSettings lod;
    float master_gain = 0.35f;

private:
    int find_free() const;
    int steal() const;

    std::vector<Voice> voices_;
    std::vector<const Model*> models_;
    std::vector<float> excitation_;  // scratch, sized once
    std::vector<float> voice_out_;   // scratch, sized once
    double sample_rate_ = 48000.0;
    uint64_t frame_ = 0;
    uint32_t next_id_ = 1;
    int dropped_ = 0;
    int stolen_ = 0;
    int nan_resets_ = 0;
};

}  // namespace modal
