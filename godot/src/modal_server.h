// The singleton everything else talks to.
//
// Holds the loaded models, the voice pool, and the queue between the physics
// thread and the audio thread. One of each, because there is one audio
// output and one physics world.
#pragma once

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/variant/string.hpp>

#include "modal/queue.h"
#include "modal/voice.h"

namespace godot {

class ModalServer : public Node {
    GDCLASS(ModalServer, Node)

public:
    ModalServer();
    ~ModalServer();

    static ModalServer* get_singleton() { return singleton_; }

    // Loading happens here, on whichever thread asked, never on the audio
    // thread. Returns the model id, or -1.
    int load_model(const String& path);
    void unload_models();
    int model_count() const;

    void set_voice_limit(int voices);
    int get_voice_limit() const;
    void set_lod_distances(float near_metres, float mid_metres, float far_metres);
    void set_gain(float gain);
    float get_gain() const;

    int get_active_voices() const;
    int get_dropped_events() const;
    int get_stolen_voices() const;

    // Called by ModalBody from the physics thread. Never blocks; returns
    // false when the queue is full, and the caller has already sorted so the
    // loudest are the ones that got in.
    bool push_event(const modal::ContactEvent& event);

    // Called by the playback from the audio thread. Drains the queue and
    // renders. Nothing in here allocates.
    void mix_into(float* out, int frames);

    // The pool's sample rate is fixed when the audio device opens.
    void prepare(double sample_rate);

protected:
    static void _bind_methods();

private:
    static ModalServer* singleton_;

    modal::ContactQueue<1024> queue_;
    modal::VoicePool pool_;
    std::vector<modal::Model> models_;
    // Path to id, so fifty objects of the same kind are one model and not
    // fifty copies of it.
    HashMap<String, int> by_path_;
    std::vector<const modal::Model*> model_pointers_;
    int voice_limit_ = modal::kDefaultVoices;
    double sample_rate_ = 48000.0;
    bool prepared_ = false;
};

}  // namespace godot
