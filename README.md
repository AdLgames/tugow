# Modal

Procedural physics-driven audio. Impact sounds generated from the physics
state of a collision rather than picked from a library of samples.

The full plan is `docs/BUILD_PLAN.md`. **Week 1 is done**: the DSP core, the
offline renderer, and the tests. No Godot yet, deliberately — the point of
week 1 is to find out whether the velocity model works before anything is
built on top of it.

## Build and run

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release -DMODAL_BUILD_TESTS=ON
cmake --build build -j
./build/modal_tests
./build/modal-render --model models/ceramic_mug.modal --velocity 2.0 --out hit.wav
```

`--report` prints a model's modes instead of rendering. `--modes N` caps the
mode count, which is how the level-of-detail tiers will be checked later.

## The week 1 gate

> Render the same model at 0.5, 2.0 and 8.0 m/s. The three must sound like
> the same object hit with different force — not three volumes of one sound.

Measured as spectral centroid, with the impulse held at 1.0 N·s and every
render peak-normalised, so nothing here can pass on loudness:

| Model | 0.5 m/s | 2.0 m/s | 8.0 m/s |
|---|---|---|---|
| `glass_tumbler` | 1355 Hz | 1443 Hz | 1559 Hz |
| `steel_pipe` | 1135 Hz | 1290 Hz | 1446 Hz |
| `ceramic_mug` | 1127 Hz | 1227 Hz | 1320 Hz |

**Passed.** A harder hit is a shorter contact, a shorter contact is a wider
excitation bandwidth, and the high modes get more of it. No filter, no second
parameter — the contact time is the whole mechanism.

## Three corrections to the plan

Two of these were arithmetic, found before writing the code. The third was
found by the gate itself, which is what it is for.

### The excitation pulse delivered half its impulse

Section 1.3 gives:

```
x[n] = (J / N) · 0.5 · (1 - cos(2πn / N))
```

A Hann window averages one half, so this sums to `J/2`, not `J`. Confirmed at
N = 8, 64 and 512 before implementing. The pulse here normalises against the
window's own sum instead, so it stays correct at any width and if the window
is ever changed.

### `sizeof(ContactEvent)` is 40, not 48

Section 2.2's `static_assert` would fail as written: two `uint32_t`, seven
`float`, one `uint8_t` and three bytes of padding is 40, with no trailing
padding at four-byte alignment. Not yet reached — it lands in week 3 — but the
assert needs to say 40, or the struct needs deliberate padding to a
cache-friendly 48, and the plan should say which was meant.

### Contact width has to stay fractional

**This one the gate caught, and it is the interesting one.**

A hard material at speed has a contact of two or three samples at 48 kHz.
Rounding that to a whole number of samples throws the velocity resolution
away exactly where a game spends most of its time: steel at 2 m/s (3.4
samples) and at 8 m/s (2.5 samples) both rounded to 3, and the two renders
came out **bit for bit identical** — 1364 Hz at both velocities.

That is the precise failure the contact-time model exists to prevent, hiding
inside the model's own implementation. The fix is to keep the width
fractional and sample the Hann window at each sample's centre; the spectrum
then moves continuously with velocity. Steel now reads 1135 → 1290 → 1446 Hz.

`tests/test_excitation.cpp` holds both halves as regressions: two nearby
velocities on a hard material must render differently, and a velocity ramp
must never widen the pulse.

Worth knowing, since it is a real ceiling rather than a bug: the plan clamps
contact time at 0.05 ms, which on steel is reached at about 10 m/s. Above
that an impact stops getting brighter. It still gets louder.

## Layout

```
core/      engine-agnostic, no dependencies
  model    .modal loading and validation, coefficient computation
  bank     the resonator bank — the audio path
  excitation  contact time, the strike pulse
harness/   modal-render: model in, WAV out
models/    three hand-authored models
tests/     doctest, one case per invariant
```

Loading and validation may use the STL; they run off the audio thread. The
bank may not allocate, lock, log or throw, because it will be called from an
audio callback in week 3.

## What is not here yet

Weeks 2 to 4 of the plan: the fitter (WAV → `.modal`), the Godot GDExtension,
the voice pool, SIMD, and continuous contact for rolling and scraping. The
`.modal` format already carries `strike_positions` and the material constants
those need, and the loader validates them.

Modal synthesis models linear vibration of rigid resonant bodies. It is good
for things that ring and poor for anything dominated by turbulence, friction
noise without resonance, or non-linear deformation. Cloth, flesh, foliage and
liquids are non-goals.
