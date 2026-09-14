// Attach under a RigidBody3D and its collisions make sound.
//
// Contacts are read in _integrate_forces, on the physics thread, and pushed
// to the audio thread through the lock-free queue. Nothing here touches the
// voice pool directly.
#pragma once

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/physics_direct_body_state3d.hpp>
#include <godot_cpp/classes/rigid_body3d.hpp>
#include <godot_cpp/templates/vector.hpp>

#include "modal/queue.h"

namespace godot {

class ModalBody : public Node3D {
    GDCLASS(ModalBody, Node3D)

public:
    ModalBody();

    virtual void _ready() override;
    virtual PackedStringArray _get_configuration_warnings() const override;

    // Called from the parent body's _integrate_forces.
    void read_contacts(PhysicsDirectBodyState3D* state);

    void set_model_path(const String& path);
    String get_model_path() const { return model_path_; }
    void set_gain(float gain) { gain_ = gain; }
    float get_gain() const { return gain_; }
    void set_max_events_per_frame(int events) { max_events_per_frame_ = events; }
    int get_max_events_per_frame() const { return max_events_per_frame_; }
    void set_enable_rolling(bool on) { enable_rolling_ = on; }
    bool get_enable_rolling() const { return enable_rolling_; }
    void set_enable_scraping(bool on) { enable_scraping_ = on; }
    bool get_enable_scraping() const { return enable_scraping_; }

    // Below these a contact is not worth a voice.
    static constexpr float kImpactVelocity = 0.15f;
    static constexpr float kScrapeVelocity = 0.05f;
    // Two contacts this close on consecutive ticks are the same contact.
    // Godot gives no stable contact ids, so proximity is what there is.
    static constexpr float kSameContactMetres = 0.05f;

protected:
    static void _bind_methods();

private:
    struct Remembered {
        Vector3 position;
        uint32_t voice = 0;
        bool seen_this_tick = false;
        bool used = false;
    };

    int find_remembered(const Vector3& position);

    String model_path_;
    int model_id_ = -1;
    float gain_ = 1.0f;
    int max_events_per_frame_ = 8;
    bool enable_rolling_ = true;
    bool enable_scraping_ = true;

    // Fixed size, because this runs every physics tick and must not
    // allocate any more than the audio thread does.
    static constexpr int kRemembered = 8;
    Remembered remembered_[kRemembered];
};

}  // namespace godot
