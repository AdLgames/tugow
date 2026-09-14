#include "modal_server.h"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

ModalServer* ModalServer::singleton_ = nullptr;

ModalServer::ModalServer() {
    singleton_ = this;
    pool_.resize(voice_limit_, sample_rate_);
}

ModalServer::~ModalServer() {
    if (singleton_ == this) singleton_ = nullptr;
}

void ModalServer::prepare(double sample_rate) {
    if (prepared_ && sample_rate == sample_rate_) return;
    sample_rate_ = sample_rate;
    // The only allocation in the pool's life, and it happens before the
    // audio thread is running.
    pool_.resize(voice_limit_, sample_rate_);
    pool_.set_models(model_pointers_.data(), static_cast<int>(model_pointers_.size()));
    prepared_ = true;
}

int ModalServer::load_model(const String& path) {
    // Read through Godot so res:// and a packed build both work.
    Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
    if (file.is_null()) {
        UtilityFunctions::push_error("modal: could not open " + path);
        return -1;
    }
    const String text = file->get_as_text();
    const modal::LoadResult result =
        modal::load_from_string(std::string(text.utf8().get_data()), sample_rate_);
    for (const std::string& warning : result.warnings) {
        UtilityFunctions::push_warning("modal: " + path + ": " + String(warning.c_str()));
    }
    if (!result.ok) {
        UtilityFunctions::push_error("modal: " + path + ": " + String(result.error.c_str()));
        return -1;
    }

    // Reserved once so the vector never moves under the pool's pointers.
    if (models_.capacity() == 0) models_.reserve(256);
    if (models_.size() == models_.capacity()) {
        UtilityFunctions::push_error("modal: too many models loaded");
        return -1;
    }
    models_.push_back(result.model);
    model_pointers_.clear();
    for (const modal::Model& model : models_) model_pointers_.push_back(&model);
    pool_.set_models(model_pointers_.data(), static_cast<int>(model_pointers_.size()));
    return static_cast<int>(models_.size()) - 1;
}

void ModalServer::unload_models() {
    models_.clear();
    model_pointers_.clear();
    pool_.set_models(nullptr, 0);
}

int ModalServer::model_count() const { return static_cast<int>(models_.size()); }

void ModalServer::set_voice_limit(int voices) {
    voice_limit_ = voices;
    prepared_ = false;
    prepare(sample_rate_);
}

int ModalServer::get_voice_limit() const { return voice_limit_; }

void ModalServer::set_lod_distances(float near_metres, float mid_metres, float far_metres) {
    pool_.lod.near_metres = near_metres;
    pool_.lod.mid_metres = mid_metres;
    pool_.lod.far_metres = far_metres;
}

int ModalServer::get_active_voices() const { return pool_.active_voices(); }
int ModalServer::get_dropped_events() const {
    return pool_.dropped_events() + static_cast<int>(queue_.dropped());
}
int ModalServer::get_stolen_voices() const { return pool_.stolen_voices(); }

bool ModalServer::push_event(const modal::ContactEvent& event) { return queue_.push(event); }

void ModalServer::mix_into(float* out, int frames) {
    // Drained first so an event that arrived this block is heard in it, not
    // in the next one — a block is ten milliseconds of lateness otherwise.
    modal::ContactEvent event;
    while (queue_.pop(event)) pool_.start(event);
    pool_.mix(out, frames);
}

void ModalServer::_bind_methods() {
    ClassDB::bind_method(D_METHOD("load_model", "path"), &ModalServer::load_model);
    ClassDB::bind_method(D_METHOD("unload_models"), &ModalServer::unload_models);
    ClassDB::bind_method(D_METHOD("model_count"), &ModalServer::model_count);
    ClassDB::bind_method(D_METHOD("set_voice_limit", "voices"), &ModalServer::set_voice_limit);
    ClassDB::bind_method(D_METHOD("get_voice_limit"), &ModalServer::get_voice_limit);
    ClassDB::bind_method(D_METHOD("set_lod_distances", "near", "mid", "far"),
                         &ModalServer::set_lod_distances);
    ClassDB::bind_method(D_METHOD("get_active_voices"), &ModalServer::get_active_voices);
    ClassDB::bind_method(D_METHOD("get_dropped_events"), &ModalServer::get_dropped_events);
    ClassDB::bind_method(D_METHOD("get_stolen_voices"), &ModalServer::get_stolen_voices);
}
