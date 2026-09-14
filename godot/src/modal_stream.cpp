#include "modal_stream.h"

#include <godot_cpp/classes/audio_server.hpp>
#include <godot_cpp/core/class_db.hpp>

#include "modal_server.h"

using namespace godot;

void ModalAudioStreamPlayback::_start(double) { playing_ = true; }
void ModalAudioStreamPlayback::_stop() { playing_ = false; }
bool ModalAudioStreamPlayback::_is_playing() const { return playing_; }

int32_t ModalAudioStreamPlayback::_mix(AudioFrame* buffer, float, int32_t frames) {
    // Real-time thread. No allocation, no locks, no logging, no Godot object
    // creation, and nothing that can throw.
    //
    // rate_scale is deliberately ignored. It is the host asking for pitch
    // shifting, and a modal voice is pitched by its coefficients, not by
    // resampling — obeying it would detune every object in the scene.
    if (!playing_) return 0;

    ModalServer* server = ModalServer::get_singleton();
    const int32_t capacity = static_cast<int32_t>(sizeof(scratch_) / sizeof(scratch_[0]));
    int32_t done = 0;
    while (done < frames) {
        const int32_t block = frames - done < capacity ? frames - done : capacity;
        for (int32_t i = 0; i < block; ++i) scratch_[i] = 0.0f;
        if (server != nullptr) server->mix_into(scratch_, block);
        for (int32_t i = 0; i < block; ++i) {
            buffer[done + i].left = scratch_[i];
            buffer[done + i].right = scratch_[i];
        }
        done += block;
    }
    return frames;
}

Ref<AudioStreamPlayback> ModalAudioStream::_instantiate_playback() const {
    Ref<ModalAudioStreamPlayback> playback;
    playback.instantiate();
    ModalServer* server = ModalServer::get_singleton();
    if (server != nullptr) server->prepare(AudioServer::get_singleton()->get_mix_rate());
    return playback;
}

String ModalAudioStream::_get_stream_name() const { return "Modal"; }

// Never ends. It is an output for a physics world, not a recording.
double ModalAudioStream::_get_length() const { return 0.0; }
bool ModalAudioStream::_is_monophonic() const { return true; }
