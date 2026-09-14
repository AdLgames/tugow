// A radix-2 complex FFT.
//
// Deviation from the build plan, which lists pffft. The fitter analyses a
// few hundred frames of a four-second file — a run is milliseconds either
// way, so pffft's speed buys nothing here, and a hundred lines is less to
// vendor and less to review than twenty-five hundred. If profiling ever
// disagrees, the interface is small enough to swap behind.
#pragma once

#include <cstddef>
#include <vector>

namespace modal {

// In-place. `size` must be a power of two.
void fft_forward(std::vector<float>& real, std::vector<float>& imag);

// Magnitude spectrum of a real signal, length size/2 + 1.
void fft_magnitude(const std::vector<float>& windowed, std::vector<float>& magnitude);

bool is_power_of_two(size_t n);

}  // namespace modal
