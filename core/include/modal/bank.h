// The resonator bank: one two-pole section per mode.
//
// This runs on the audio thread. No allocation, no locks, no I/O, no
// exceptions. Everything it touches is supplied by the caller.
#pragma once

#include <cstdint>

#include "modal/model.h"

namespace modal {

// A voice holds as many modes as the file gave it, up to this. Structure of
// arrays, because the SIMD path wants four consecutive modes per load.
constexpr uint32_t kMaxModes = 48;

struct Bank {
    alignas(16) float b0[kMaxModes] = {};
    alignas(16) float a1[kMaxModes] = {};
    alignas(16) float a2[kMaxModes] = {};
    alignas(16) float y1[kMaxModes] = {};
    alignas(16) float y2[kMaxModes] = {};
    uint32_t active_modes = 0;
};

// Load coefficients into a bank, quietest modes first to be dropped. `gains`
// may be null; when given it scales each mode and must have at least as many
// entries as the model has modes.
void bank_set(Bank& bank, const Model& model, double sample_rate, uint32_t max_modes,
              const double* gains);

void bank_reset(Bank& bank);

// x and out may not overlap. out is written, not accumulated.
void bank_process(Bank& bank, const float* x, float* out, int frames);

// True when the state has gone non-finite. One bad coefficient otherwise
// poisons the mix for the rest of the session and the report is never
// reproducible.
bool bank_is_finite(const Bank& bank);

}  // namespace modal

namespace modal {

// The same arithmetic, four modes at a time. Identical output to
// bank_process within float rounding, which the tests hold it to.
void bank_process_simd(Bank& bank, const float* x, float* out, int frames);

// How fast this bank's slowest mode decays, as a per-sample multiplier. The
// voice pool uses it to know when a voice has gone quiet without measuring
// its output.
float bank_slowest_decay(const Bank& bank);

}  // namespace modal
