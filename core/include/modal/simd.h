// A four-wide float, over SSE2, NEON, or neither.
//
// Kept behind a handful of inline functions rather than intrinsics scattered
// through the bank, so there is one place to read when a platform misbehaves
// and one place to change when a wider vector is worth having.
#pragma once

#if defined(__SSE2__) || (defined(_M_X64) || (defined(_M_IX86_FP) && _M_IX86_FP >= 2))
#define MODAL_SIMD_SSE2 1
#include <emmintrin.h>
#elif defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__)
#define MODAL_SIMD_NEON 1
#include <arm_neon.h>
#endif

namespace modal {

#if defined(MODAL_SIMD_SSE2)

using float4 = __m128;
inline float4 f4_zero() { return _mm_setzero_ps(); }
inline float4 f4_set1(float v) { return _mm_set1_ps(v); }
inline float4 f4_load(const float* p) { return _mm_load_ps(p); }
inline void f4_store(float* p, float4 v) { _mm_store_ps(p, v); }
inline float4 f4_add(float4 a, float4 b) { return _mm_add_ps(a, b); }
inline float4 f4_mul(float4 a, float4 b) { return _mm_mul_ps(a, b); }
inline float4 f4_fma(float4 a, float4 b, float4 c) { return _mm_add_ps(_mm_mul_ps(a, b), c); }
inline float f4_hsum(float4 v) {
    float4 shuffled = _mm_movehl_ps(v, v);
    float4 sums = _mm_add_ps(v, shuffled);
    shuffled = _mm_shuffle_ps(sums, sums, 0x1);
    sums = _mm_add_ss(sums, shuffled);
    return _mm_cvtss_f32(sums);
}
constexpr const char* simd_name() { return "SSE2"; }

#elif defined(MODAL_SIMD_NEON)

using float4 = float32x4_t;
inline float4 f4_zero() { return vdupq_n_f32(0.0f); }
inline float4 f4_set1(float v) { return vdupq_n_f32(v); }
inline float4 f4_load(const float* p) { return vld1q_f32(p); }
inline void f4_store(float* p, float4 v) { vst1q_f32(p, v); }
inline float4 f4_add(float4 a, float4 b) { return vaddq_f32(a, b); }
inline float4 f4_mul(float4 a, float4 b) { return vmulq_f32(a, b); }
inline float4 f4_fma(float4 a, float4 b, float4 c) { return vmlaq_f32(c, a, b); }
inline float f4_hsum(float4 v) {
#if defined(__aarch64__)
    return vaddvq_f32(v);
#else
    float32x2_t pair = vadd_f32(vget_low_f32(v), vget_high_f32(v));
    return vget_lane_f32(vpadd_f32(pair, pair), 0);
#endif
}
constexpr const char* simd_name() { return "NEON"; }

#else

// No vector unit, or one nobody has written a path for. The scalar fallback
// is the same arithmetic, so the equivalence test still means something and
// the build still works.
struct float4 {
    float v[4];
};
inline float4 f4_zero() { return {{0.0f, 0.0f, 0.0f, 0.0f}}; }
inline float4 f4_set1(float x) { return {{x, x, x, x}}; }
inline float4 f4_load(const float* p) { return {{p[0], p[1], p[2], p[3]}}; }
inline void f4_store(float* p, float4 v) {
    p[0] = v.v[0];
    p[1] = v.v[1];
    p[2] = v.v[2];
    p[3] = v.v[3];
}
inline float4 f4_add(float4 a, float4 b) {
    return {{a.v[0] + b.v[0], a.v[1] + b.v[1], a.v[2] + b.v[2], a.v[3] + b.v[3]}};
}
inline float4 f4_mul(float4 a, float4 b) {
    return {{a.v[0] * b.v[0], a.v[1] * b.v[1], a.v[2] * b.v[2], a.v[3] * b.v[3]}};
}
inline float4 f4_fma(float4 a, float4 b, float4 c) { return f4_add(f4_mul(a, b), c); }
inline float f4_hsum(float4 v) { return v.v[0] + v.v[1] + v.v[2] + v.v[3]; }
constexpr const char* simd_name() { return "scalar"; }

#endif

// Denormals cost up to a hundred times a normal multiply on some CPUs, and a
// bank of decaying resonators produces them constantly as each mode fades
// out. Flushed at the top of the audio callback, restored on the way out so
// nothing else in the process inherits the setting.
class FlushDenormals {
public:
    FlushDenormals();
    ~FlushDenormals();

private:
    unsigned int saved_ = 0;
};

}  // namespace modal
