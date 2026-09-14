# Testing Modal

## The short version

**You cannot test this on the tablet.** A GDExtension is a compiled native
library, one per platform, and the Android Godot editor has no C++ compiler
in it. There is no version of "open the project and press play" that works
from where you are.

What you can do from the tablet is listen to renders. What needs a desktop
is everything else.

| | Tablet | Desktop (Linux/Mac/Windows) |
|---|---|---|
| Listen to rendered WAVs | yes | yes |
| Run the unit tests | no | yes |
| Fit your own recordings | no | yes |
| Open the Godot demo | no | yes |
| Build the extension | no | yes |

## On the tablet: listening

Everything here renders offline, so the output is a WAV either way. Ask and
the renders come back as files; the ones worth having are:

- one model at three velocities, the week 1 gate
- `--verify-wav` from the fitter: original, resynthesis, difference in a row
- the fifty-object drop, rendered from the real physics simulation

That last one is the week 3 gate, and it is a fair test: the same scene that
runs in the editor, the same voice pool, the same audio callback — only the
output goes to a file instead of a speaker.

## On a desktop: the whole thing

### Just the engine, no Godot

Twenty seconds, no dependencies beyond a compiler and CMake.

```bash
git clone <this repo> && cd tugow
cmake -B build -DCMAKE_BUILD_TYPE=Release -DMODAL_BUILD_TESTS=ON
cmake --build build -j
./build/modal_tests
```

Expect **65 cases, 30289 assertions, SUCCESS**. That covers the file format,
the resonator bank against its closed form, the excitation, the fitter
against signals with known answers, the lock-free queue under a million
threaded events, and the voice pool's stealing and culling.

Then hear something:

```bash
./build/modal-render --model models/glass_tumbler.modal --velocity 0.5 --out slow.wav
./build/modal-render --model models/glass_tumbler.modal --velocity 8.0 --out fast.wav
```

Same object, same peak level. If those two sound like one sound at two
volumes, the engine is broken; they should sound like one object hit softly
and hard.

### Fitting your own recordings

```bash
./build/modal-fit --in mug.wav --out models/mug.modal --verify --verify-wav ab.wav
./build/modal-render --model models/mug.modal --velocity 2.0 --out mug_hit.wav
```

`ab.wav` is your recording, then the resynthesis, then the difference, with
quarter-second gaps. That third section is what the fit missed.

`--explain` lists every candidate and why the rejected ones went, which is
the first thing to look at when a fit comes out thin.

Recording matters more than anything else here — see the README. Briefly:
WAV not AAC, automatic gain off, hold the object at its rim, hit it hard with
something small and hard.

### The Godot extension

Needs SCons and a compiler. Godot **4.3 or newer**.

```bash
cd godot
git clone -b master https://github.com/godotengine/godot-cpp

# Generate the bindings against the exact Godot you will run.
godot --headless --dump-extension-api          # writes extension_api.json

# Both targets. The editor loads the debug one and an exported game loads
# the release one, so building only release means the editor reports the
# extension as missing and every class in it as undeclared.
scons platform=linux target=template_debug   custom_api_file=extension_api.json -j8
scons platform=linux target=template_release custom_api_file=extension_api.json -j8
```

That writes `demo/addons/modal/bin/libmodal.*.so`. Then:

```bash
godot --path demo                    # opens the demo, fifty objects drop
godot --path demo --headless -- --seconds=6   # the same run, no window
```

Swap `platform=linux` for `windows` or `macos` as needed. `target=template_debug`
if you want to attach a debugger.

**If the editor says the extension failed to load**, it is one of two things.
Either the file it names is `template_debug` and you only built
`template_release` — build both. Or the bindings were generated against a
different Godot than the one running: re-dump `extension_api.json` from the
binary you are actually using and rebuild.

## Using it in a scene

Three things, and the third is the one everyone forgets.

```gdscript
# 1. An AudioStreamPlayer with a ModalAudioStream on it. One per project;
#    the whole engine mixes through it.

# 2. A ModalBody under each RigidBody3D, with model_path set. It reads the
#    contacts itself, every physics tick. Nothing to wire up.

# 3. The body must actually report contacts:
func _ready() -> void:
    contact_monitor = true
    max_contacts_reported = 8        # zero means no contacts, ever
```

`ModalBody.read_contacts(state)` is still public if you would rather drive it
from your own `_integrate_forces`, but you do not have to.

`max_contacts_reported` defaults to zero, and with it at zero Godot reports
no contacts at all — the object is simply silent, with no error anywhere.
`ModalBody` puts a warning in the editor's scene tree when either setting is
missing, because the failure is otherwise indistinguishable from the sound
not working.

## Diagnostics

```gdscript
ModalServer.get_active_voices()    # how many are sounding now
ModalServer.get_dropped_events()   # contacts that never got a voice
ModalServer.get_stolen_voices()    # voices cut short to make room
ModalServer.set_voice_limit(96)    # 16 to 256, default 64
ModalServer.set_gain(4.0)          # newton seconds to full scale
```

Rising `dropped_events` with `active_voices` pinned at the limit means the
pool is too small for the scene. Rising `stolen_voices` means the same thing
one step earlier.
