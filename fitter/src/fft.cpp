#include "fft.h"

#include <cmath>

namespace modal {

bool is_power_of_two(size_t n) { return n != 0 && (n & (n - 1)) == 0; }

void fft_forward(std::vector<float>& real, std::vector<float>& imag) {
    const size_t n = real.size();
    if (!is_power_of_two(n) || imag.size() != n) return;

    // Bit reversal.
    for (size_t i = 1, j = 0; i < n; ++i) {
        size_t bit = n >> 1;
        for (; j & bit; bit >>= 1) j ^= bit;
        j ^= bit;
        if (i < j) {
            std::swap(real[i], real[j]);
            std::swap(imag[i], imag[j]);
        }
    }

    for (size_t len = 2; len <= n; len <<= 1) {
        const double angle = -2.0 * M_PI / static_cast<double>(len);
        const double wr = std::cos(angle);
        const double wi = std::sin(angle);
        for (size_t i = 0; i < n; i += len) {
            double cr = 1.0, ci = 0.0;
            for (size_t k = 0; k < len / 2; ++k) {
                const size_t a = i + k;
                const size_t b = a + len / 2;
                const double tr = real[b] * cr - imag[b] * ci;
                const double ti = real[b] * ci + imag[b] * cr;
                real[b] = static_cast<float>(real[a] - tr);
                imag[b] = static_cast<float>(imag[a] - ti);
                real[a] = static_cast<float>(real[a] + tr);
                imag[a] = static_cast<float>(imag[a] + ti);
                const double next_cr = cr * wr - ci * wi;
                ci = cr * wi + ci * wr;
                cr = next_cr;
            }
        }
    }
}

void fft_magnitude(const std::vector<float>& windowed, std::vector<float>& magnitude) {
    std::vector<float> real = windowed;
    std::vector<float> imag(windowed.size(), 0.0f);
    fft_forward(real, imag);
    const size_t bins = windowed.size() / 2 + 1;
    magnitude.resize(bins);
    for (size_t k = 0; k < bins; ++k) {
        magnitude[k] = std::sqrt(real[k] * real[k] + imag[k] * imag[k]);
    }
}

}  // namespace modal
