#include "modal_body.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/physics_server3d.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include "modal_server.h"

using namespace godot;

ModalBody::ModalBody() {}

uint32_t ModalBody::mint_token() {
    // Zero means "no contact to refer back to", so it is skipped on wrap.
    static uint32_t next = 1;
    const uint32_t token = next++;
    if (next == 0) next = 1;
    return token;
}

void ModalBody::_ready() {
    if (Engine::get_singleton()->is_editor_hint()) return;
    ModalServer* server = ModalServer::get_singleton();
    if (server != nullptr && !model_path_.is_empty()) {
        model_id_ = server->load_model(model_path_);
    }
    RigidBody3D* body = Object::cast_to<RigidBody3D>(get_parent());
    if (body == nullptr) return;
    body_ = body;
    set_physics_process(true);
    // Turning these on silently would hide the mistake rather than fix it,
    // and a contact monitor the user did not ask for costs them performance.
    // The configuration warning says it instead.
    if (!body->is_contact_monitor_enabled() || body->get_max_contacts_reported() <= 0) {
        UtilityFunctions::push_warning(
            "ModalBody: " + body->get_name() +
            " has contact_monitor off or max_contacts_reported at 0, so it will never "
            "report a contact and this body will be silent.");
    }
}

// Polled rather than hooked. PhysicsServer3D's force-integration callback is
// the other way in, but RigidBody3D already owns that one and taking it would
// break the body's own state sync. Reading the direct state once a tick gets
// the same contacts and leaves the body alone.
void ModalBody::_physics_process(double) {
    if (body_ == nullptr || model_id_ < 0) return;
    PhysicsDirectBodyState3D* state =
        PhysicsServer3D::get_singleton()->body_get_direct_state(body_->get_rid());
    if (state != nullptr) read_contacts(state);
}

PackedStringArray ModalBody::_get_configuration_warnings() const {
    PackedStringArray warnings;
    RigidBody3D* body = Object::cast_to<RigidBody3D>(get_parent());
    if (body == nullptr) {
        warnings.push_back("ModalBody must be a child of a RigidBody3D.");
        return warnings;
    }
    // The single most common integration mistake, said plainly and in the
    // editor rather than discovered as silence at runtime.
    if (!body->is_contact_monitor_enabled()) {
        warnings.push_back("The parent RigidBody3D has contact_monitor off. Contacts are "
                           "never reported, so this body will make no sound.");
    }
    if (body->get_max_contacts_reported() <= 0) {
        warnings.push_back("The parent RigidBody3D has max_contacts_reported at 0. It must be "
                           "greater than zero or contacts are never reported.");
    }
    if (model_path_.is_empty()) {
        warnings.push_back("No model set. Point model_path at a .modal file.");
    }
    return warnings;
}

void ModalBody::set_model_path(const String& path) {
    model_path_ = path;
    update_configuration_warnings();
}

int ModalBody::find_remembered(const Vector3& position) {
    for (int i = 0; i < kRemembered; ++i) {
        if (!remembered_[i].used) continue;
        if (remembered_[i].position.distance_to(position) < kSameContactMetres) return i;
    }
    return -1;
}

void ModalBody::read_contacts(PhysicsDirectBodyState3D* state) {
    ModalServer* server = ModalServer::get_singleton();
    if (server == nullptr || model_id_ < 0 || state == nullptr) return;

    for (int i = 0; i < kRemembered; ++i) remembered_[i].seen_this_tick = false;

    // Gathered first, then ranked, then pushed. The queue cannot drop its
    // quietest entry — it may be being read — so the choice of what to lose
    // is made here, where nothing else can see the list.
    modal::ContactEvent gathered[32];
    int count = 0;
    const int contacts = state->get_contact_count();
    for (int i = 0; i < contacts && count < 32; ++i) {
        const Vector3 impulse = state->get_contact_impulse(i);
        const Vector3 normal = state->get_contact_local_normal(i);
        const Vector3 position = state->get_contact_local_position(i);
        const Vector3 other = state->get_contact_collider_velocity_at_position(i);
        const Vector3 relative = state->get_linear_velocity() - other;
        const float normal_speed = static_cast<float>(Math::abs(relative.dot(normal)));
        const float tangential =
            static_cast<float>((relative - normal * relative.dot(normal)).length());

        const Vector3 world = to_global(position);
        const int known = find_remembered(position);

        modal::ContactEvent event;
        event.model_id = static_cast<uint32_t>(model_id_);
        event.impulse = static_cast<float>(impulse.length()) * gain_;
        event.normal_force = static_cast<float>(impulse.length()) * gain_;
        event.tangential_vel = tangential;
        event.distance = static_cast<float>(world.length());
        event.contact_u = 0.5f;
        event.contact_v = 0.5f;

        if (known < 0) {
            if (normal_speed < kImpactVelocity) continue;
            event.type = modal::ContactType::Impact;
            // Named now, so when this contact turns into a roll next tick it
            // carries on in the voice the impact started rather than
            // beginning a new one sixty times a second.
            event.voice_hint = mint_token();
            for (int slot = 0; slot < kRemembered; ++slot) {
                if (remembered_[slot].used) continue;
                remembered_[slot].used = true;
                remembered_[slot].position = position;
                remembered_[slot].seen_this_tick = true;
                remembered_[slot].token = event.voice_hint;
                break;
            }
        } else {
            remembered_[known].seen_this_tick = true;
            remembered_[known].position = position;
            event.voice_hint = remembered_[known].token;
            if (tangential > kScrapeVelocity) {
                // Rolling if the body's spin matches the ground speed; the
                // surface is being read out rather than dragged across.
                const float spin =
                    static_cast<float>(state->get_angular_velocity().length()) * 0.5f;
                const bool rolling = Math::abs(spin - tangential) < tangential * 0.5f;
                if (rolling && !enable_rolling_) continue;
                if (!rolling && !enable_scraping_) continue;
                event.type = rolling ? modal::ContactType::Roll : modal::ContactType::Scrape;
            } else {
                event.type = modal::ContactType::Release;
            }
        }
        gathered[count++] = event;
    }

    // Anything not touched this tick has ended; tell the pool so its voice
    // fades instead of hanging.
    for (int i = 0; i < kRemembered; ++i) {
        if (!remembered_[i].used || remembered_[i].seen_this_tick) continue;
        if (remembered_[i].token != 0 && count < 32) {
            modal::ContactEvent event;
            event.model_id = static_cast<uint32_t>(model_id_);
            event.voice_hint = remembered_[i].token;
            event.type = modal::ContactType::Release;
            gathered[count++] = event;
        }
        remembered_[i].used = false;
    }

    modal::sort_loudest_first(gathered, count);
    const int limit = max_events_per_frame_ < count ? max_events_per_frame_ : count;
    for (int i = 0; i < limit; ++i) server->push_event(gathered[i]);
}

void ModalBody::_bind_methods() {
    ClassDB::bind_method(D_METHOD("read_contacts", "state"), &ModalBody::read_contacts);
    ClassDB::bind_method(D_METHOD("set_model_path", "path"), &ModalBody::set_model_path);
    ClassDB::bind_method(D_METHOD("get_model_path"), &ModalBody::get_model_path);
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "model_path", PROPERTY_HINT_FILE, "*.modal"),
                 "set_model_path", "get_model_path");

    ClassDB::bind_method(D_METHOD("set_gain", "gain"), &ModalBody::set_gain);
    ClassDB::bind_method(D_METHOD("get_gain"), &ModalBody::get_gain);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "gain"), "set_gain", "get_gain");

    ClassDB::bind_method(D_METHOD("set_max_events_per_frame", "events"),
                         &ModalBody::set_max_events_per_frame);
    ClassDB::bind_method(D_METHOD("get_max_events_per_frame"),
                         &ModalBody::get_max_events_per_frame);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "max_events_per_frame"), "set_max_events_per_frame",
                 "get_max_events_per_frame");

    ClassDB::bind_method(D_METHOD("set_enable_rolling", "on"), &ModalBody::set_enable_rolling);
    ClassDB::bind_method(D_METHOD("get_enable_rolling"), &ModalBody::get_enable_rolling);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "enable_rolling"), "set_enable_rolling",
                 "get_enable_rolling");

    ClassDB::bind_method(D_METHOD("set_enable_scraping", "on"), &ModalBody::set_enable_scraping);
    ClassDB::bind_method(D_METHOD("get_enable_scraping"), &ModalBody::get_enable_scraping);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "enable_scraping"), "set_enable_scraping",
                 "get_enable_scraping");
}
