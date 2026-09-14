#include "modal/bank.h"

#include <algorithm>
#include <cmath>

#include "modal/simd.h"

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

// --- SIMD ---------------------------------------------------------------

namespace modal {

void bank_process_simd(Bank& bank, const float* x, float* out, int frames) {
    // Rounded up to four. The unused slots hold zero coefficients, set in
    // bank_set, so they contribute nothing and there is no tail loop.
    const uint32_t modes = (bank.active_modes + 3u) & ~3u;
    for (int i = 0; i < frames; ++i) {
        float4 acc = f4_zero();
        const float4 xi = f4_set1(x[i]);
        for (uint32_t k = 0; k < modes; k += 4) {
            float4 y = f4_mul(f4_load(&bank.b0[k]), xi);
            y = f4_fma(f4_load(&bank.a1[k]), f4_load(&bank.y1[k]), y);
            y = f4_fma(f4_load(&bank.a2[k]), f4_load(&bank.y2[k]), y);
            f4_store(&bank.y2[k], f4_load(&bank.y1[k]));
            f4_store(&bank.y1[k], y);
            acc = f4_add(acc, y);
        }
        out[i] = f4_hsum(acc);
    }
}

float bank_slowest_decay(const Bank& bank) {
    // a2 is -r squared, so r is the square root of its negation. The largest
    // r is the mode that outlives the rest, and the voice is not silent
    // until that one is.
    float slowest = 0.0f;
    for (uint32_t k = 0; k < bank.active_modes; ++k) {
        const float r_squared = -bank.a2[k];
        if (r_squared > slowest) slowest = r_squared;
    }
    return std::sqrt(slowest);
}

FlushDenormals::FlushDenormals() {
#if defined(MODAL_SIMD_SSE2)
    saved_ = _mm_getcsr();
    _mm_setcsr(saved_ | 0x8040u);  // flush to zero, denormals are zero
#elif defined(MODAL_SIMD_NEON) && defined(__aarch64__)
    uint64_t fpcr = 0;
    __asm__ __volatile__("mrs %0, fpcr" : "=r"(fpcr));
    saved_ = static_cast<unsigned int>(fpcr);
    const uint64_t flushing = fpcr | (1ull << 24);  // FZ
    __asm__ __volatile__("msr fpcr, %0" : : "r"(flushing));
#endif
}

FlushDenormals::~FlushDenormals() {
#if defined(MODAL_SIMD_SSE2)
    _mm_setcsr(saved_);
#elif defined(MODAL_SIMD_NEON) && defined(__aarch64__)
    const uint64_t restored = saved_;
    __asm__ __volatile__("msr fpcr, %0" : : "r"(restored));
#endif
}

}  // namespace modal
