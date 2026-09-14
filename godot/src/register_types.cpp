#include <gdextension_interface.h>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "modal_body.h"
#include "modal_server.h"
#include "modal_stream.h"

using namespace godot;

static ModalServer* server = nullptr;

void initialise_modal(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    GDREGISTER_CLASS(ModalServer);
    GDREGISTER_CLASS(ModalBody);
    GDREGISTER_CLASS(ModalAudioStream);
    GDREGISTER_CLASS(ModalAudioStreamPlayback);

    // Registered as an engine singleton so a scene can reach it without
    // being told where it is.
    server = memnew(ModalServer);
    Engine::get_singleton()->register_singleton("ModalServer", server);
}

void shutdown_modal(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    Engine::get_singleton()->unregister_singleton("ModalServer");
    if (server != nullptr) {
        memdelete(server);
        server = nullptr;
    }
}

extern "C" GDExtensionBool GDE_EXPORT modal_library_init(
    GDExtensionInterfaceGetProcAddress get_proc_address, GDExtensionClassLibraryPtr library,
    GDExtensionInitialization* initialization) {
    GDExtensionBinding::InitObject init(get_proc_address, library, initialization);
    init.register_initializer(initialise_modal);
    init.register_terminator(shutdown_modal);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
