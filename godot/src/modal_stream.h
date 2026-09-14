// The audio side: an AudioStream whose playback renders the voice pool.
//
// Put one on an AudioStreamPlayer and the whole engine is audible. _mix is
// the real-time thread; everything it calls is bound by the rules in section
// 2.1 of the build plan.
#pragma once

#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/audio_stream_playback.hpp>

namespace godot {

class ModalAudioStreamPlayback : public AudioStreamPlayback {
    GDCLASS(ModalAudioStreamPlayback, AudioStreamPlayback)

public:
    virtual void _start(double from_pos) override;
    virtual void _stop() override;
    virtual bool _is_playing() const override;
    virtual int32_t _mix(AudioFrame* buffer, double rate_scale, int32_t frames) override;

protected:
    static void _bind_methods() {}

private:
    bool playing_ = false;
    // Mono is rendered once and copied to both channels. Sized at
    // construction; _mix never grows it.
    float scratch_[4096] = {};
};

class ModalAudioStream : public AudioStream {
    GDCLASS(ModalAudioStream, AudioStream)

public:
    virtual Ref<AudioStreamPlayback> _instantiate_playback() const override;
    virtual String _get_stream_name() const override;
    virtual double _get_length() const override;
    virtual bool _is_monophonic() const override;

protected:
    static void _bind_methods() {}
};

}  // namespace godot
