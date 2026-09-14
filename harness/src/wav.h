// A WAV writer, because the harness has no dependencies either. 16-bit PCM,
// which is what every tool will open without comment.
#pragma once

#include <cstdint>
#include <cstdio>
#include <string>
#include <vector>

namespace modal {

inline bool write_wav(const std::string& path, const std::vector<float>& samples,
                      int sample_rate, int channels) {
    FILE* file = std::fopen(path.c_str(), "wb");
    if (file == nullptr) return false;

    const uint32_t data_bytes = static_cast<uint32_t>(samples.size() * 2);
    const uint32_t byte_rate = static_cast<uint32_t>(sample_rate * channels * 2);
    auto u32 = [&](uint32_t v) { std::fwrite(&v, 4, 1, file); };
    auto u16 = [&](uint16_t v) { std::fwrite(&v, 2, 1, file); };

    std::fwrite("RIFF", 1, 4, file);
    u32(36 + data_bytes);
    std::fwrite("WAVEfmt ", 1, 8, file);
    u32(16);
    u16(1);  // PCM
    u16(static_cast<uint16_t>(channels));
    u32(static_cast<uint32_t>(sample_rate));
    u32(byte_rate);
    u16(static_cast<uint16_t>(channels * 2));
    u16(16);
    std::fwrite("data", 1, 4, file);
    u32(data_bytes);

    for (float value : samples) {
        // Clamped rather than wrapped: a sample past full scale should sound
        // loud, not inside out.
        const float limited = value > 1.0f ? 1.0f : (value < -1.0f ? -1.0f : value);
        u16(static_cast<uint16_t>(static_cast<int16_t>(limited * 32767.0f)));
    }
    std::fclose(file);
    return true;
}

}  // namespace modal
