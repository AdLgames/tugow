# Modal — Procedural Physics-Driven Audio for Godot

**Build plan, v1.0**

A modal synthesis engine that generates impact, rolling and scraping sounds from
physics state instead of playing samples. Core is engine-agnostic C++17; Godot
binding ships as a GDExtension.

---

## 0. Scope and non-goals

### In scope for v1

| Capability | Status in v1 |
|---|---|
| Impact sounds (collision → transient) | Yes |
| Rolling / continuous contact | Yes |
| Scraping (tangential sliding) | Yes |
| Sample→model fitting tool | Yes |
| Hard materials: glass, ceramic, metal, stone | Yes |
| Wood | Partial — acceptable, not great |
| Cloth, flesh, foliage, liquids | **No** |
| Stick-slip (brakes, squeaks) | **No** — v2 |
| Bubble/water synthesis | **No** — v2 |
| Reverb / spatialisation | **No** — use Godot's |

### Explicit non-goals

- Not a replacement for a full sound design pipeline. Modal synthesis covers
  resonant rigid-body contact. Everything else stays sample-based.
- Not a DAW. No editing timeline, no mixing.
- No machine learning anywhere in the runtime or the fitter.

### The honest limitation, stated up front

Modal synthesis models **linear vibration of rigid resonant bodies**. It is
excellent for objects that ring. It is poor for anything whose sound is
dominated by turbulence, friction noise without resonance, or non-linear
deformation. Ship with hard materials, document the boundary, don't overclaim.

---

## 1. Physics and DSP background

### 1.1 The modal model

A struck rigid body vibrates as a superposition of damped sinusoids:

```
y(t) = Σ  a_k · e^(-t/τ_k) · sin(2π f_k t)
      k=1..K
```

Each mode `k` has three parameters:

| Symbol | Meaning | Units | Typical range |
|---|---|---|---|
| `f_k` | modal frequency | Hz | 50 – 18000 |
| `τ_k` | 1/e decay time | s | 0.005 – 8.0 |
| `a_k` | modal amplitude | linear | 0.0 – 1.0 (normalised) |

A *modal model* is just an ordered list of `(f, τ, a)` triples plus metadata.
K is typically 16–48.

**Conversion note.** Audio literature often uses RT60 (time to −60 dB):

```
RT60 = τ · ln(1000) ≈ 6.9078 · τ
τ    = RT60 / 6.9078
```

The file format stores `τ`. Convert at the UI boundary only.

### 1.2 Realising a mode as a two-pole resonator

Each mode is one biquad with no zeros — a direct-form recursion:

```
y[n] = b0·x[n] + a1·y[n-1] + a2·y[n-2]
```

Coefficients, given sample rate `fs`:

```
ω  = 2π · f / fs
r  = exp(-1 / (τ · fs))        // pole radius, 0 < r < 1
a1 = 2 · r · cos(ω)
a2 = -r²
b0 = a · sin(ω)
```

The impulse response of this recursion is:

```
h[n] = b0 · r^n · sin((n+1)·ω) / sin(ω)
```

which is the damped sinusoid we want, with peak amplitude `a`.

**Stability requirements:**

- `r < 1` strictly. Clamp `τ` to a maximum (recommend 10 s) so `r` never reaches
  1.0 in float32.
- `f < fs/2`. Discard or clamp modes above `0.45·fs` at load time — aliasing a
  mode above Nyquist produces a wrong frequency, not silence.
- As `ω → 0`, `sin(ω) → 0` and `b0` collapses. Reject modes below 20 Hz.

### 1.3 Excitation — this is where realism lives

**The single most important design point in this document.**

A naive implementation excites the resonator bank with a one-sample impulse
scaled by collision energy. This gives you the same timbre at every velocity,
only louder. Real objects sound *brighter* when hit harder, not just louder.

The physical reason is contact duration. Hertzian contact theory gives, for
elastic bodies:

```
t_c ∝ v^(-1/5)
```

Harder impact → shorter contact → wider excitation bandwidth → more high modes
excited. Model it directly:

```
t_c = t_ref · (v_ref / v)^0.2
```

with `t_ref` a per-material constant (the contact time at a reference velocity
`v_ref` = 1.0 m/s). Clamp `t_c` to `[0.05 ms, 20 ms]`.

Generate the excitation as a **Hann-windowed pulse** of width `N = t_c · fs`
samples, scaled so the total impulse equals the collision impulse `J`:

```
x[n] = (J / N) · 0.5 · (1 - cos(2πn / N))    for n ∈ [0, N)
```

A wider pulse is inherently low-passed — its spectrum rolls off earlier. This
gives the correct velocity→brightness relationship for free, with no filter and
no extra parameter.

**Material `t_ref` starting values:**

| Material | `t_ref` (ms) at 1 m/s |
|---|---|
| Steel | 0.08 |
| Glass | 0.12 |
| Ceramic | 0.15 |
| Stone | 0.25 |
| Hardwood | 0.6 |
| Softwood | 1.2 |
| Rubber | 6.0 |

These are tuning starting points, not measured constants. Expose them.

### 1.4 Strike position

Mode amplitudes depend on where the object is struck — a bell hit on the rim
sounds different from the crown. Full modal shape functions require FEM data
we don't have.

**v1 approach — gain vector interpolation.** The model file optionally carries
`P` gain vectors (each length K), one per sampled strike position. At runtime,
map the contact point to a normalised coordinate and blend between the two
nearest vectors.

**v1 fallback when `P = 0`** — apply bounded per-strike random gain variation:
each mode gets a gain multiplier drawn from `U(1-σ, 1+σ)` with `σ = 0.25`,
using a seeded PRNG. This is not physically correct but it eliminates the
machine-gun identical-repeat artefact, which is what actually breaks the
illusion.

### 1.5 Continuous contact — rolling and scraping

Rolling and sliding excite the same resonator bank, but with a continuous
signal rather than a pulse.

**Surface profile noise.** A rough surface is a 1D height profile. As a body
rolls or slides across it at tangential velocity `v_t`, it reads out that
profile. Model the profile as fractal noise with spectral slope `1/f^β`,
`β ≈ 1.5` for typical surfaces, and read it at a rate proportional to `v_t`.

Implementation:
1. Pre-generate a 2^16-sample 1/f^β noise table per surface roughness class.
   Do this once, offline or at load.
2. Maintain a read phase per contact. Advance by `v_t · scale` samples per
   audio sample. Linear-interpolate between table entries.
3. Scale output amplitude by normal force `F_n`, with a power law:
   `amp ∝ F_n^0.7`.
4. Feed into the resonator bank as `x[n]`.

**Rolling vs scraping** differ mainly in bandwidth and amplitude law. Rolling
has a lower effective readout rate (contact patch averages the profile) —
apply a one-pole low-pass on the noise with cutoff proportional to `v_t`.
Scraping does not.

**Crossfade at velocity thresholds.** Below `v_t = 0.05 m/s`, fade continuous
excitation to zero over 30 ms. Without this, resting objects hum.

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Godot physics thread (60 Hz)                            │
│                                                          │
│  _integrate_forces(state)                                │
│    ├── read contacts: impulse, normal, position, vel     │
│    ├── classify: impact | rolling | scraping             │
│    └── push ContactEvent → SPSC ring buffer  ────────┐   │
└──────────────────────────────────────────────────────│───┘
                                                       │
                                        lock-free, no allocation
                                                       │
┌──────────────────────────────────────────────────────▼───┐
│ Audio thread (callback, 512-sample blocks)                │
│                                                            │
│  _mix(buffer, rate_scale, frames)                          │
│    ├── drain event queue → allocate/steal voices           │
│    ├── for each active voice:                              │
│    │     ├── generate excitation block                     │
│    │     ├── run resonator bank (SIMD, SoA)                │
│    │     └── accumulate into output                        │
│    ├── cull silent voices                                  │
│    └── write buffer                                        │
└────────────────────────────────────────────────────────────┘
```

### 2.1 Threading rules — non-negotiable

The audio callback must be real-time safe. In `_mix` and anything it calls:

- **No allocation.** No `new`, no `malloc`, no `std::vector` growth, no
  `String`, no Godot `Object` creation.
- **No locks.** No mutex, no `std::atomic` with anything stronger than needed.
- **No I/O.** No logging, no file access.
- **No exceptions.**
- Denormals flushed — set FTZ/DAZ at callback entry (`_MM_SET_FLUSH_ZERO_MODE`
  on x86, `FPCR.FZ` on ARM). Decaying resonators generate denormals constantly
  and unflushed denormals can cost 100× on some CPUs.

Everything allocated once, at load, in the voice pool.

### 2.2 The event queue

Single-producer single-consumer lock-free ring buffer. Fixed capacity 1024
events. On overflow, **drop the quietest pending event**, not the newest —
dropping the newest loses the loud impact you most want to hear.

```cpp
struct ContactEvent {
    uint32_t model_id;        // index into loaded model table
    uint32_t voice_hint;      // 0 = new voice, else continue existing
    float    impulse;         // N·s, for impacts
    float    normal_force;    // N, for continuous
    float    tangential_vel;  // m/s
    float    contact_u, contact_v;  // normalised strike position
    float    pan, distance;   // spatialisation params
    uint8_t  type;            // 0=impact 1=roll 2=scrape 3=release
    uint8_t  _pad[3];
};
static_assert(sizeof(ContactEvent) == 48);
```

### 2.3 Voice pool

```cpp
struct Voice {
    // SoA resonator state — all arrays length MAX_MODES, 16-byte aligned
    alignas(16) float a1[MAX_MODES];
    alignas(16) float a2[MAX_MODES];
    alignas(16) float b0[MAX_MODES];
    alignas(16) float y1[MAX_MODES];
    alignas(16) float y2[MAX_MODES];

    uint32_t active_modes;    // may be < MAX_MODES due to LOD
    uint32_t model_id;
    uint64_t start_frame;
    float    energy;          // running estimate, for stealing/culling
    float    gain, pan;
    ExcitationState exc;
    bool     continuous;      // true = rolling/scraping, held open
};
```

`MAX_MODES = 48`. Pool size 64 voices default, configurable 16–256.

**Allocation policy:** take a free voice; if none, steal the voice with lowest
`energy`. Never steal a voice younger than 20 ms — stealing a just-started
loud impact is the worst possible artefact.

**Culling:** a voice retires when its energy estimate falls below −80 dBFS.
Track energy cheaply as `max(r) ^ frames_elapsed × initial_energy` rather than
measuring the output — it's an upper bound, monotonic, and costs nothing.

### 2.4 Level of detail

Mode count scales with distance and voice pressure:

| Condition | Modes |
|---|---|
| Nearest 8 voices, < 5 m | 48 (full) |
| < 20 m | 24 |
| < 50 m | 12 |
| ≥ 50 m or pool > 75% full | 6 |

Modes are sorted by amplitude descending at load, so truncation always keeps
the perceptually dominant ones. This is why sort order matters in the file
format.

---

## 3. The DSP core

### 3.1 Inner loop, scalar reference

```cpp
// Reference implementation — correctness baseline for tests.
void bank_process_scalar(Voice& v, const float* x, float* out, int n) {
    for (int i = 0; i < n; ++i) {
        float acc = 0.0f;
        const float xi = x[i];
        for (uint32_t k = 0; k < v.active_modes; ++k) {
            const float y = v.b0[k] * xi + v.a1[k] * v.y1[k] + v.a2[k] * v.y2[k];
            v.y2[k] = v.y1[k];
            v.y1[k] = y;
            acc += y;
        }
        out[i] = acc;
    }
}
```

Cost: ~5 flops per mode per sample. 48 modes × 48 kHz = 11.5 MFLOP/s per voice.

### 3.2 SIMD

Process 4 modes per iteration. SoA layout makes this a straight load/FMA/store
with no shuffles. Target SSE2 (x86-64 baseline) and NEON (ARM64). Use a thin
abstraction header rather than intrinsics scattered through the code.

```cpp
// float4 is a 4-wide vector typedef over __m128 / float32x4_t
void bank_process_simd(Voice& v, const float* x, float* out, int n) {
    const uint32_t kn = (v.active_modes + 3) & ~3u;   // round up to 4
    for (int i = 0; i < n; ++i) {
        float4 acc = f4_zero();
        const float4 xi = f4_set1(x[i]);
        for (uint32_t k = 0; k < kn; k += 4) {
            float4 y = f4_mul(f4_load(&v.b0[k]), xi);
            y = f4_fma(f4_load(&v.a1[k]), f4_load(&v.y1[k]), y);
            y = f4_fma(f4_load(&v.a2[k]), f4_load(&v.y2[k]), y);
            f4_store(&v.y2[k], f4_load(&v.y1[k]));
            f4_store(&v.y1[k], y);
            acc = f4_add(acc, y);
        }
        out[i] = f4_hsum(acc);
    }
}
```

Pad unused mode slots with `b0 = a1 = a2 = 0` so they contribute nothing —
avoids a tail loop.

Expected speedup 3.2–3.6× over scalar. Measure, don't assume.

**Optimisation note:** the horizontal sum per sample is the bottleneck. If
profiling demands it, restructure to accumulate 4 partial output buffers and
sum once per block. Do this only if measurements justify it.

### 3.3 Numerical safety

- **NaN guard:** once per block, check the voice output for NaN. If found, reset
  `y1`/`y2` to zero and retire the voice. One bad coefficient otherwise poisons
  the mix permanently and the bug report will be unreproducible.
- **Float32 vs float64:** float32 is sufficient for `y1`/`y2` state. Compute
  *coefficients* in float64 at load time, then narrow — `r = exp(-1/(τ·fs))`
  for long decays sits very close to 1.0 and the precision matters when it's
  squared for `a2`.
- **Soft clip** the summed output with `tanh`-approximation before writing.
  200 simultaneous impacts will exceed 0 dBFS and hard clipping sounds like a
  bug report.

---

## 4. File format

### 4.1 `.modal` — JSON, v1

Human-readable and diffable. Binary variant deferred to v2; parse cost is
irrelevant because loading happens off the audio thread.

```json
{
  "format": "modal",
  "version": 1,
  "name": "ceramic_mug_medium",
  "source": "fitted from mug_strike_01.wav",
  "fit_quality": 0.91,
  "modes": [
    { "f": 1245.3, "tau": 1.820, "a": 1.000 },
    { "f": 2891.7, "tau": 0.940, "a": 0.612 },
    { "f": 4102.1, "tau": 0.510, "a": 0.388 }
  ],
  "strike_positions": [
    { "u": 0.0, "v": 0.0, "gains": [1.00, 0.61, 0.39] },
    { "u": 1.0, "v": 0.0, "gains": [0.42, 0.98, 0.71] }
  ],
  "material": {
    "contact_time_ref_ms": 0.15,
    "roughness": 0.3,
    "rolling_gain": 0.6,
    "scrape_gain": 1.0
  }
}
```

### 4.2 Invariants enforced at load

Validate and reject with a clear error, never silently:

1. `modes` non-empty, length ≤ 256.
2. Sorted by `a` descending. (Loader sorts if not; warns.)
3. `20 ≤ f ≤ 0.45 · fs` — modes outside are dropped with a warning, not an
   error, so a 48 kHz-fitted model still loads at 44.1 kHz.
4. `0.001 ≤ tau ≤ 10.0`.
5. `0 < a ≤ 1.0`; normalise so `max(a) == 1.0`.
6. Every `strike_positions[i].gains` has length equal to `modes` length.
7. `u`, `v` ∈ [0, 1].

**Coefficients are computed at load for the current `fs`.** Never store
coefficients in the file — a model fitted at 48 kHz must work at 44.1 kHz.

---

## 5. The fitter

A standalone CLI: WAV in, `.modal` out. **This is the paid tier.** Without it
users hand-dial oscillators and everything sounds like a 1983 synthesiser.
With it they record their own front door and it plays correctly at every
velocity forever.

### 5.1 Algorithm

**Input requirement:** a single isolated strike, mono, minimal room reverb,
decayed to silence. Document this clearly — garbage in, garbage out, and users
will feed it a 3-second clip with a chair squeak in it.

```
1. LOAD
   Read WAV → mono float32. Resample to analysis rate (48 kHz).

2. ONSET DETECT
   Find first sample exceeding -40 dBFS. Back off 128 samples.
   Truncate everything before.

3. STFT
   Window   : Hann, 4096 samples
   Hop      : 512 samples
   Zero-pad : 2× (8192-point FFT) for frequency resolution
   Frames   : until signal falls below -75 dBFS

4. PEAK PICK (on frame index 2 — past the broadband click, before decay)
   For each bin k where mag[k] > mag[k-1] and mag[k] > mag[k+1]:
     if 20·log10(mag[k] / max_mag) > -65 dB:
       parabolic interpolation on LOG magnitude:
         α = ln(mag[k-1]), β = ln(mag[k]), γ = ln(mag[k+1])
         δ = 0.5 · (α - γ) / (α - 2β + γ)          // δ ∈ [-0.5, 0.5]
         f = (k + δ) · fs / N_fft
         a = exp(β - 0.25 · (α - γ) · δ)
       emit candidate (f, a)

5. TRACK
   For each candidate, follow across frames:
     - search ±2 bins around expected position
     - stop when magnitude < -75 dBFS or peak lost for 3 consecutive frames
   Produce magnitude-vs-time series per candidate.

6. FIT DECAY
   Linear least squares on ln(mag) vs t:
     ln(mag(t)) = ln(a₀) - t/τ
   slope = -1/τ  →  τ = -1/slope
   Record R² of the fit.

7. REJECT
   Drop candidates where:
     - R² < 0.80              (not an exponential decay — likely noise)
     - tracked frames < 8     (insufficient evidence)
     - τ < 0.005 or τ > 10.0  (out of physical range)
     - f < 20 or f > 18000

8. MERGE
   Combine candidates within 1% in frequency (beating partials from a
   near-degenerate mode pair). Sum amplitudes, average τ weighted by amplitude.

9. SELECT
   Sort by a descending. Keep top K (default 32, --modes to override).

10. NORMALISE + EMIT
   Scale so max(a) = 1.0. Write .modal JSON.
   Report overall fit_quality = amplitude-weighted mean R².
```

### 5.2 Validation — resynthesis comparison

The fitter must ship with `--verify`, which resynthesises the fitted model and
reports:

- **Spectral convergence** between original and resynthesis (log-magnitude
  distance, per frame, averaged)
- **Decay envelope RMS error** in dB
- A side-by-side WAV: `original | resynth | difference`

Users will not trust the fitter without hearing it. Neither should you.

### 5.3 Known failure modes — document them

| Input problem | Symptom | Mitigation |
|---|---|---|
| Room reverb | τ inflated, everything rings too long | Warn if τ values cluster tightly — that's the room, not the object |
| Multiple strikes | Tracking picks up second onset | Detect and error out |
| Pitched/harmonic source | Fits fine, but it's an instrument not an object | No action; it works |
| Noisy / turbulent source | R² rejects nearly everything | Report "fewer than 4 usable modes — this source may not be modal" |

### 5.4 Accuracy upgrade path (v2)

STFT peak-picking degrades for closely spaced modes and short decays. The
matrix pencil method (or ESPRIT) estimates damped exponentials directly and is
substantially more accurate on short signals. Defer — it's a significant
implementation and STFT is adequate for the demo materials.

---

## 6. Godot integration

### 6.1 Delivery

GDExtension, built with `godot-cpp` against Godot **4.3+**. Ship prebuilt
binaries for `linux.x86_64`, `windows.x86_64`, `macos.universal`,
`android.arm64`, `ios.arm64`. Web export deferred (SharedArrayBuffer and audio
worklet constraints make it a project of its own).

### 6.2 Classes exposed

```
ModalLibrary       (Resource)
  - load_model(path: String) -> int     # returns model_id
  - unload_model(id: int)
  - model_count() -> int

ModalAudioStream        (AudioStream)
  - _instantiate_playback() -> ModalAudioStreamPlayback

ModalAudioStreamPlayback (AudioStreamPlayback)
  - _mix(buffer: AudioFrame*, rate_scale: double, frames: int32) -> int32

ModalBody          (Node3D)   # attach as child of a RigidBody3D
  @export model: ModalModel
  @export gain: float = 1.0
  @export max_events_per_frame: int = 8
  @export enable_rolling: bool = true
  @export enable_scraping: bool = true

ModalServer        (Singleton / autoload)
  - set_voice_limit(n: int)
  - set_lod_distances(near: float, mid: float, far: float)
  - get_active_voices() -> int
  - get_dropped_events() -> int      # diagnostics
```

### 6.3 Reading physics contacts

The parent `RigidBody3D` requires:

```gdscript
contact_monitor = true
max_contacts_reported = 8        # must be > 0 or contacts are never reported
```

This is the single most common integration mistake. `ModalBody._ready()` should
check both and push a clear editor warning if unset — not fail silently.

In `_integrate_forces(state: PhysicsDirectBodyState3D)`:

```gdscript
var n := state.get_contact_count()
for i in range(min(n, max_events_per_frame)):
    var impulse   : Vector3 = state.get_contact_impulse(i)
    var normal    : Vector3 = state.get_contact_local_normal(i)
    var pos       : Vector3 = state.get_contact_local_position(i)
    var other_vel : Vector3 = state.get_contact_collider_velocity_at_position(i)

    var rel_vel   := state.linear_velocity - other_vel
    var v_normal  := abs(rel_vel.dot(normal))
    var v_tangent := (rel_vel - normal * rel_vel.dot(normal)).length()
    # ... classify and push event
```

### 6.4 Contact classification

Per contact, per physics tick:

```
if contact is new this tick AND v_normal > V_IMPACT_MIN:
    → IMPACT, magnitude = impulse.length()

elif contact persisted from last tick:
    if v_tangent > V_SCRAPE_MIN:
        if body is rolling (angular velocity consistent with v_tangent):
            → ROLL
        else:
            → SCRAPE
    else:
        → RELEASE (fade continuous voice)
```

Defaults: `V_IMPACT_MIN = 0.15 m/s`, `V_SCRAPE_MIN = 0.05 m/s`.

**Contact persistence tracking** is the fiddly part. Godot does not give stable
contact IDs across ticks. Match by proximity: a contact within 5 cm of a
previous-tick contact on the same collider pair is the same contact. Keep a
small fixed-size per-body table (8 entries) of last-tick contacts.

### 6.5 Impulse → excitation energy

`state.get_contact_impulse(i)` returns impulse in N·s. Feed `J = impulse.length()`
directly to the excitation generator. Apply a per-material scalar and a global
`gain`. Do **not** apply a velocity curve on top — the contact-time model in
§1.3 already provides the correct velocity dependence, and stacking a second
curve on it will sound wrong in a way that's hard to diagnose later.

### 6.6 Event rate limiting

A collapsing debris pile can generate thousands of contacts per tick.
`max_events_per_frame` caps per-body output; `ModalServer` caps globally at
`voice_limit / 2` new events per tick. Sort by impulse descending before
truncating, so the loudest survive.

---

## 7. Repository layout

```
modal/
├── CMakeLists.txt
├── README.md
├── LICENSE                       # MIT for core
├── core/                         # engine-agnostic, zero dependencies
│   ├── include/modal/
│   │   ├── model.h               # ModalModel, load/validate
│   │   ├── voice.h               # Voice, VoicePool
│   │   ├── bank.h                # resonator processing
│   │   ├── excitation.h          # impact pulse, surface noise
│   │   ├── queue.h               # SPSC ring buffer
│   │   └── simd.h                # float4 abstraction
│   └── src/
│       ├── model.cpp
│       ├── voice.cpp
│       ├── bank_scalar.cpp
│       ├── bank_sse.cpp
│       ├── bank_neon.cpp
│       └── excitation.cpp
├── fitter/                       # CLI: WAV → .modal
│   ├── src/
│   │   ├── main.cpp
│   │   ├── stft.cpp
│   │   ├── peaks.cpp
│   │   ├── track.cpp
│   │   └── verify.cpp
│   └── third_party/              # pffft (BSD), dr_wav (public domain)
├── harness/                      # offline test renderer
│   └── src/main.cpp              # scripted scenarios → WAV
├── godot/
│   ├── SConstruct
│   ├── godot-cpp/                # submodule
│   ├── src/
│   │   ├── register_types.cpp
│   │   ├── modal_stream.cpp
│   │   ├── modal_body.cpp
│   │   └── modal_server.cpp
│   └── demo/                     # the marble staircase project
├── models/                       # fitted .modal library
└── tests/
    ├── test_model.cpp
    ├── test_bank.cpp
    ├── test_queue.cpp
    ├── test_excitation.cpp
    └── golden/                   # reference WAV renders
```

### Dependencies

| Component | Library | Licence | Why |
|---|---|---|---|
| FFT (fitter only) | pffft | BSD-like | Small, fast, no build burden |
| WAV I/O | dr_wav | Public domain | Single header |
| Test framework | doctest | MIT | Single header, fast compile |
| Godot binding | godot-cpp | MIT | Required |

**Core has zero dependencies.** Not even the STL in the audio path. This is
what makes the Unity port straightforward later.

---

## 8. Build and test

### 8.1 Build

```bash
# Core + fitter + tests
cmake -B build -DCMAKE_BUILD_TYPE=Release -DMODAL_BUILD_TESTS=ON
cmake --build build -j

# Godot extension
cd godot && scons platform=linux target=template_release -j8
```

Compiler flags for the core: `-O2 -ffast-math` is **not** acceptable —
`-ffast-math` enables assumptions that break the NaN guard. Use
`-O2 -fno-math-errno -ffp-contract=fast`.

### 8.2 Test strategy

**Unit tests (fast, run on every commit):**

| Test | Asserts |
|---|---|
| `test_model` | Invalid models rejected; each invariant in §4.2 has a case |
| `test_bank` | Scalar and SIMD paths produce identical output within 1e-5 |
| `test_bank` | Single mode impulse response matches analytic `h[n]` within 1e-4 |
| `test_bank` | Decay time measured from output matches specified `τ` within 2% |
| `test_queue` | SPSC correctness under threaded stress, 10⁶ events |
| `test_excitation` | Pulse total energy equals specified impulse within 0.1% |
| `test_excitation` | Higher velocity produces higher spectral centroid |

**Golden-file audio regression:**

The harness renders fixed scenarios to WAV with a fixed seed. Tests compare
against committed reference renders using spectral distance, not sample-exact
equality — floating point differs across compilers.

```
golden/impact_glass_1ms.wav
golden/impact_glass_5ms.wav
golden/roll_ceramic_slow.wav
golden/scrape_metal.wav
golden/stress_200_voices.wav
```

Tolerance: mean log-spectral distance < 0.5 dB. Any change beyond that is
either a bug or an intentional improvement requiring a regenerated golden file
and a note in the commit.

**Real-time safety test:**

Run the audio callback under a checker that fails on allocation. On Linux, LD_PRELOAD
an interposing `malloc` that aborts when a thread-local "in audio callback" flag
is set. This catches the mistakes that otherwise surface as random crackling on
one user's machine only.

**Performance gates (CI, fail the build on regression):**

| Metric | Budget |
|---|---|
| 64 voices × 48 modes @ 48 kHz | < 25% of one core |
| Worst-case block time | < 2 ms for 512 samples |
| Model load | < 5 ms |
| Allocations in `_mix` | Exactly 0 |

---

## 9. Milestones

### Week 1 — DSP core, offline

**Deliverable:** a command-line harness that renders impact sounds to WAV.
No Godot involvement at all.

- [ ] `ModalModel` struct, JSON load, all §4.2 invariants + tests
- [ ] Coefficient computation (float64 → float32)
- [ ] Scalar resonator bank + analytic impulse-response test
- [ ] Hann excitation pulse with Hertzian contact-time model
- [ ] Harness: `modal-render --model x.modal --velocity 2.0 --out hit.wav`
- [ ] Three hand-authored models: glass, steel, ceramic

**Gate:** render the same model at 0.5, 2.0 and 8.0 m/s. The three must sound
like the same object hit with different force — not three volumes of one sound.
If that fails, the contact-time model is wrong and nothing downstream matters.
Do not proceed until this passes.

### Week 2 — The fitter

**Deliverable:** WAV in, `.modal` out, with verification.

- [ ] STFT with pffft
- [ ] Peak picking with parabolic interpolation
- [ ] Cross-frame tracking
- [ ] Exponential decay fitting + R² gating
- [ ] Mode merging, selection, normalisation
- [ ] `--verify` resynthesis comparison + side-by-side WAV
- [ ] Fit 10 real recordings (record them: mug, glass, pipe, tile, bowl…)

**Gate:** a fitted ceramic mug, resynthesised, is recognisable as that mug in
a blind A/B. If fit quality is poor across all ten, stop and evaluate matrix
pencil before building anything else on top.

### Week 3 — Godot binding, impacts only

**Deliverable:** a Godot scene where dropping objects makes correct sounds.

- [ ] GDExtension skeleton, `register_types`
- [ ] `ModalAudioStream` / `ModalAudioStreamPlayback`, `_mix` implemented
- [ ] SPSC queue wired between physics and audio threads
- [ ] Voice pool with stealing and culling
- [ ] `ModalBody` node, `_integrate_forces` contact reading
- [ ] Impact classification and event push
- [ ] `ModalServer` singleton, voice limit, diagnostics
- [ ] Editor warnings for unset `contact_monitor` / `max_contacts_reported`
- [ ] SIMD paths (SSE2, NEON) + equivalence test

**Gate:** 50 objects dropped simultaneously, no crackle, no allocation in the
callback, CPU under budget.

### Week 4 — Continuous contact and the demo

**Deliverable:** the marble staircase video.

- [ ] 1/f^β surface noise generation
- [ ] Rolling excitation with velocity-dependent low-pass
- [ ] Scraping excitation
- [ ] Contact persistence tracking across ticks
- [ ] Release fade
- [ ] LOD by distance and pool pressure
- [ ] Demo scene: 200 glass marbles, stone staircase
- [ ] Golden-file regression suite committed
- [ ] README, model authoring guide, known-limitations page

**Gate:** the demo video is convincing to someone who doesn't know how it works.

---

## 10. Demo specification

**The marble staircase.** Two hundred glass marbles poured down stone steps.

Why this specific scene:
- ~200 collisions per second at peak — a sample library would machine-gun
  audibly and obviously
- Every impact has a different velocity and strike position, so the
  contact-time model is showcased directly
- Rolling and impact interleave continuously
- It is immediately legible in a 15-second clip with no explanation

**Production requirements:**
- Fixed seed, deterministic — the same render every time
- Side-by-side comparison: modal synthesis vs the same scene with a 6-sample
  random-pick impact library
- Render at 48 kHz stereo, no reverb, no post-processing. Any polish invites
  the accusation that the polish is doing the work.
- Include the CPU meter on screen

---

## 11. Licensing and business shape

| Component | Licence | Rationale |
|---|---|---|
| `core/` runtime | MIT | Adoption. Must be trivially embeddable. |
| `godot/` binding | MIT | Same. |
| `models/` starter library | CC0 | Removes all friction for evaluation. |
| `fitter/` | Commercial | The paid tier. |

The runtime is worthless without models, and hand-authoring models is
impractical. The fitter is what converts a curiosity into a pipeline, so that
is what carries a price. Free runtime drives adoption; the fitter monetises the
teams who ship.

Price the fitter at $79 perpetual for individuals, $299 per seat for studios.
Both well below the cost of the sound designer hours it replaces on a single
project.

---

## 12. Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Fitted models sound synthetic | Medium | Fatal | Week 2 gate. If ten real recordings all fit poorly, the product doesn't work — find out in week 2, not week 4. |
| Contact-time model insufficient for velocity realism | Medium | High | Week 1 gate, before anything is built on it |
| Godot contact data too coarse at 60 Hz | Medium | Medium | Sub-stepping, or interpolate impulse across the tick. Test in week 3. |
| CPU cost unacceptable on mobile | Low | Medium | LOD already specified; reduce default pool to 24 on mobile |
| Nobody wants it | Medium | Fatal | Post the week-1 harness renders publicly before writing the Godot binding. Real reaction beats speculation. |
| Wood and organic materials demanded immediately | High | Low | Documented non-goal from day one |

**The week 1 and week 2 gates exist to kill the project cheaply.** Both are
before any Godot work. If either fails, you have spent two weeks, not a month,
and you have learned something real.
