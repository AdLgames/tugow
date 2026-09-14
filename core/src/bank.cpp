#include "modal/bank.h"

#include <algorithm>
#include <cmath>

namespace modal {

void bank_reset(Bank& bank) {
    for (uint32_t k = 0; k < kMaxModes; ++k) {
        bank.y1[k] = 0.0f;
        bank.y2[k] = 0.0f;
    }
}

void bank_set(Bank& bank, const Model& model, double sample_rate, uint32_t max_modes,
              const double* gains) {
    const uint32_t count =
        std::min<uint32_t>(std::min<uint32_t>(max_modes, kMaxModes),
                           static_cast<uint32_t>(model.modes.size()));
    for (uint32_t k = 0; k < count; ++k) {
        Mode mode = model.modes[k];
        if (gains != nullptr) mode.a *= gains[k];
        const Coefficients c = coefficients_for(mode, sample_rate);
        bank.b0[k] = c.b0;
        bank.a1[k] = c.a1;
        bank.a2[k] = c.a2;
    }
    // Unused slots are silenced rather than left stale, so the SIMD path can
    // run to a multiple of four without a tail loop and without hearing
    // whatever the last voice left behind.
    for (uint32_t k = count; k < kMaxModes; ++k) {
        bank.b0[k] = 0.0f;
        bank.a1[k] = 0.0f;
        bank.a2[k] = 0.0f;
    }
    bank.active_modes = count;
    bank_reset(bank);
}

void bank_process(Bank& bank, const float* x, float* out, int frames) {
    const uint32_t modes = bank.active_modes;
    for (int i = 0; i < frames; ++i) {
        float acc = 0.0f;
        const float xi = x[i];
        for (uint32_t k = 0; k < modes; ++k) {
            const float y = bank.b0[k] * xi + bank.a1[k] * bank.y1[k] + bank.a2[k] * bank.y2[k];
            bank.y2[k] = bank.y1[k];
            bank.y1[k] = y;
            acc += y;
        }
        out[i] = acc;
    }
}

bool bank_is_finite(const Bank& bank) {
    for (uint32_t k = 0; k < bank.active_modes; ++k) {
        if (!std::isfinite(bank.y1[k]) || !std::isfinite(bank.y2[k])) return false;
    }
    return true;
}

}  // namespace modal
