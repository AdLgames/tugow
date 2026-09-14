#include "modal/voice.h"

#include <algorithm>
#include <cmath>

#include "modal/simd.h"

namespace modal {

uint32_t modes_for(const LodSettings& lod, float distance, float pool_pressure) {
    if (pool_pressure > lod.pressure_threshold) return lod.distant_modes;
    if (distance < lod.near_metres) return lod.near_modes;
    if (distance < lod.mid_metres) return lod.mid_modes;
    if (distance < lod.far_metres) return lod.far_modes;
    return lod.distant_modes;
}

void VoicePool::resize(int voices, double sample_rate) {
    sample_rate_ = sample_rate;
    voices_.assign(static_cast<size_t>(std::clamp(voices, kMinVoices, kMaxVoices)), Voice{});
    // Scratch big enough for any block the host is likely to ask for. Asked
    // for more than this, mix works in pieces rather than allocating.
    excitation_.assign(2048, 0.0f);
    voice_out_.assign(2048, 0.0f);
}

void VoicePool::set_models(const Model* const* models, int count) {
    models_.assign(models, models + count);
}

int VoicePool::find_free() const {
    for (size_t i = 0; i < voices_.size(); ++i) {
        if (!voices_[i].active) return static_cast<int>(i);
    }
    return -1;
}

int VoicePool::steal() const {
    // The quietest voice that is old enough to take.
    const uint64_t protected_frames = static_cast<uint64_t>(kProtectedSeconds * sample_rate_);
    int best = -1;
    float quietest = 0.0f;
    for (size_t i = 0; i < voices_.size(); ++i) {
        const Voice& voice = voices_[i];
        if (frame_ - voice.started_at < protected_frames) continue;
        if (best < 0 || voice.energy < quietest) {
            quietest = voice.energy;
            best = static_cast<int>(i);
        }
    }
    return best;
}

uint32_t VoicePool::start(const ContactEvent& event) {
    if (event.model_id >= models_.size() || models_[event.model_id] == nullptr) {
        ++dropped_;
        return 0;
    }
    const Model& model = *models_[event.model_id];

    // A continuous contact that is already sounding is refreshed rather than
    // restarted, or a rolling marble would start a voice sixty times a
    // second and steal one every time the pool filled.
    if (event.voice_hint != 0) {
        for (Voice& voice : voices_) {
            if (voice.active && voice.tag == event.voice_hint) {
                if (event.type == ContactType::Release) {
                    voice.continuous = false;
                    return voice.tag;
                }
                voice.gain = event.normal_force;
                voice.pan = event.pan;
                return voice.tag;
            }
        }
    }

    int index = find_free();
    if (index < 0) {
        index = steal();
        if (index < 0) {
            // Everything in the pool is younger than the protection window,
            // which means a great many things just happened at once. Losing
            // this one is better than cutting off a voice that started a
            // millisecond ago.
            ++dropped_;
            return 0;
        }
        ++stolen_;
    }

    Voice& voice = voices_[static_cast<size_t>(index)];
    const int active = active_voices();
    const float pressure = voices_.empty()
                               ? 1.0f
                               : static_cast<float>(active) / static_cast<float>(voices_.size());
    const uint32_t modes = modes_for(lod, event.distance, pressure);

    bank_set(voice.bank, model, sample_rate_, modes, nullptr);
    voice.decay = bank_slowest_decay(voice.bank);
    voice.model_id = event.model_id;
    voice.tag = event.voice_hint;
    voice.started_at = frame_;
    voice.gain = 1.0f;
    voice.pan = event.pan;
    voice.continuous = event.type == ContactType::Roll || event.type == ContactType::Scrape;
    voice.pulse_frame = 0;

    // Contact velocity stands in for the impact velocity: the harder the
    // blow, the shorter the contact, the brighter the result.
    const double velocity = event.type == ContactType::Impact
                                ? std::max<double>(event.impulse, 1e-3) * 10.0
                                : std::max<double>(event.tangential_vel, 1e-3);
    voice.pulse = make_pulse(std::max<double>(event.impulse, 1e-4),
                             model.material.contact_time_ref_ms, velocity, sample_rate_);
    // An upper bound on what this voice can be worth, used for stealing and
    // culling. Measuring the output would cost more than it saves.
    voice.energy = static_cast<float>(std::max<double>(event.impulse, 1e-4));
    voice.active = true;
    // A release for an event that never got a voice must not match the next
    // voice to be allocated, so a tagless start reports the tag it was given.
    return event.voice_hint != 0 ? event.voice_hint : 1u;
}

void VoicePool::mix(float* out, int frames) {
    // Denormals flushed for the whole callback, restored on the way out.
    FlushDenormals flush;

    while (frames > 0) {
        const int block = std::min<int>(frames, static_cast<int>(excitation_.size()));
        for (Voice& voice : voices_) {
            if (!voice.active) continue;

            for (int i = 0; i < block; ++i) {
                excitation_[i] = voice.pulse.sample(voice.pulse_frame + i);
            }
            voice.pulse_frame += block;

            bank_process_simd(voice.bank, excitation_.data(), voice_out_.data(), block);

            // One bad coefficient otherwise poisons the mix for the rest of
            // the session, and the report is never reproducible.
            if (!bank_is_finite(voice.bank)) {
                bank_reset(voice.bank);
                voice.active = false;
                ++nan_resets_;
                continue;
            }

            const float gain = voice.gain * master_gain;
            for (int i = 0; i < block; ++i) out[i] += voice_out_[i] * gain;

            voice.energy *= std::pow(voice.decay, static_cast<float>(block));
            if (!voice.continuous && voice.energy < kSilenceThreshold) {
                voice.active = false;
                bank_reset(voice.bank);
            }
        }

        // Two hundred impacts at once will exceed full scale, and hard
        // clipping sounds like a bug report. This is the cheap tanh shape:
        // linear until it is not, and never above one.
        for (int i = 0; i < block; ++i) {
            const float x = out[i];
            out[i] = x / (1.0f + std::fabs(x));
        }

        out += block;
        frames -= block;
        frame_ += static_cast<uint64_t>(block);
    }
}

int VoicePool::active_voices() const {
    int count = 0;
    for (const Voice& voice : voices_) {
        if (voice.active) ++count;
    }
    return count;
}

}  // namespace modal
