# Modal

Procedural physics-driven audio. Impact sounds generated from the physics
state of a collision rather than picked from a library of samples.

The full plan is `docs/BUILD_PLAN.md`. **Weeks 1 and 2 are done**: the DSP
core, the offline renderer, and the fitter. No Godot yet, deliberately — the
two gates before it exist to kill the project cheaply if either fails, and
neither needs an engine to answer.

## Build and run

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release -DMODAL_BUILD_TESTS=ON
cmake --build build -j
./build/modal_tests
./build/modal-render --model models/ceramic_mug.modal --velocity 2.0 --out hit.wav
./build/modal-fit --in recording.wav --out models/thing.modal --verify
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

## The fitter

`modal-fit` takes a recording of one strike and writes a `.modal` model.
`--verify` resynthesises it and reports how close it landed; `--verify-wav`
writes original, resynthesis and difference end to end, because nobody
believes a fit they have not heard. `--explain` lists every candidate
including the rejected ones, each with the reason.

It is tested against **synthesised signals with a known answer**, not against
recordings. A recording tells you the output sounds plausible; only a signal
you built yourself tells you the numbers are right. Round-tripping the
ceramic model through render and fit recovers every frequency to 0.1 Hz and
every decay to three decimal places.

### You are fitting the strike, not the object

A mode is only as loud in a recording as the strike made it, and a soft
strike is a long contact, which is a low-passed excitation. Measured on the
same synthetic object at three contact times:

| Strike | 7 kHz mode comes back as |
|---|---|
| 0.05 ms (hard, small, sharp) | 0.372 |
| 1.0 ms (a soft tap) | **not found at all** |

The soft tap does not make the high mode quieter, it puts it under the
picking floor — the fit returns one mode where the object has three, and the
model is missing the part that makes it sound like itself.

So: **hit it hard, with something small and hard.** A fingernail, a pen cap,
the handle end of a teaspoon. This is the single thing that most changes how
good a fitted model is, and it costs nothing.

## Recording for the fitter

Three things will ruin a take, all of them defaults on a phone:

1. **Record WAV, not the stock voice app.** Voice memos are AAC, and lossy
   compression mangles the quiet decay tail the whole fit is measuring.
2. **Turn off noise suppression and automatic gain.** AGC rides the decay
   envelope, which is the one thing being fitted — every `tau` comes back
   wrong.
3. **Hold the object so it can ring.** Pinch it at the rim, or rest it on a
   folded towel. A hand round the body damps it and there is nothing to fit.

Then: 48 kHz, one strike per file, decayed to silence, peak around −6 dBFS,
close mic in a soft room, and no EQ or normalising afterwards. Room reverb
inflates every `tau` — the fit reads the room instead of the object.

## Corrections to the plan

Two were arithmetic, found before writing the code. The rest the gates and
the fitter's own tests found, which is what they are for.

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

### The analysis window had to change

The plan specifies a Hann window for the STFT and a picking floor 65 dB down.
Those two cannot both hold: Hann's first sidelobe is only 31 dB down, so every
real mode arrives surrounded by leakage well above the floor — and that
leakage decays at the mode's own rate, so it fits a perfect exponential and
passes every test after the picking stage.

Measured, on four synthetic modes: **nineteen candidates**, and a cluster of
sidelobes merged into a phantom louder than the fundamental.

Four-term Blackman-Harris puts the sidelobes 92 dB down, below the floor, at
the cost of a main lobe twice as wide. The same four modes now produce
**exactly four candidates**, all at R² = 1.0000. That trade is the right way
round for a fitter: knowing a peak is real matters more than separating two
peaks a few hertz apart, and §5.4 already hands closely spaced modes to the
matrix pencil method in v2.

### The tracker was allowed to wander

Step 5 searches ±2 bins around the expected position each frame. Re-centring
on the best bin each time lets a candidate walk two bins per frame — over a
few hundred frames a leakage peak strolls onto the mode beside it and comes
back carrying that mode's amplitude, which is how a sidelobe outranked a
fundamental. A mode does not change frequency, so the search is anchored to
where the peak was found.

### What the resolution limit actually is

With a 4096-sample window at 48 kHz, two modes closer than about 50 Hz are
one peak whose magnitude beats at their difference frequency. That is not an
exponential decay, so it is rejected — and an earlier version of this fitter
answered a 8 Hz pair with five confident modes, none of which were in the
signal. It now refuses, which is the honest answer. Locked down as a test.

Worth noting for §8: the 1% merge tolerance is **narrower than the window can
resolve** below about 5 kHz, so merging only ever fires above that.

### The spectral distance metric needed a floor

Averaged over every bin, the log-magnitude distance is dominated by
near-silent bins where both signals are floor noise, and a good fit scores
much the same as a bad one — the ceramic round trip read 33.88 dB. Counting
only bins where the original is within 60 dB of that frame's peak, the same
fit reads **0.42 dB**.

## Layout

```
core/      engine-agnostic, no dependencies          MIT
  model    .modal loading and validation, coefficient computation
  bank     the resonator bank — the audio path
  excitation  contact time, the strike pulse
fitter/    modal-fit: WAV in, .modal out              not MIT, see fitter/LICENSE
  fft      a radix-2 transform, in place of pffft
  fitter   STFT, peak picking, tracking, decay fitting, verification
harness/   modal-render: model in, WAV out            MIT
models/    three hand-authored models                 MIT
gui/       Modal Fit — the fitting-tool panel, Godot  MIT
tests/     doctest — 47 cases, 4520 assertions        MIT
```

`gui/` is a Godot 4 project that runs both as a standalone desktop application
and, through `addons/modal_fit`, as a main-screen tab inside the editor. It is
audible: it synthesises each strike with a GDScript port of `bank.cpp`, checked
against a `modal-render` golden to within one part in 32767. Its arithmetic is
held to the C++ by `gui/tests/test_parity.gd`, whose expected values came from
running `core/` rather than from running the port. `gui/README.md` has the rest
— including the four things the panel had to correct about its own mockup once
it was pointed at real models.

The fitter carries its own licence. The runtime is free so it can be embedded
anywhere; the fitter is what turns it into a pipeline, and is the part that
carries a price.

**One more deviation:** the plan lists pffft for the FFT. The fitter analyses
a few hundred frames of a four-second file, so a run is milliseconds either
way — a hundred lines of radix-2 is less to vendor and less to review than
twenty-five hundred. The interface is small enough to swap behind if
profiling ever disagrees. `dr_wav` is vendored as the plan has it, because
handling whatever WAV a phone produced is exactly what it is for.

Loading and validation may use the STL; they run off the audio thread. The
bank may not allocate, lock, log or throw, because it will be called from an
audio callback in week 3.

## What is not here yet

Weeks 3 and 4: the Godot GDExtension, the voice pool, SIMD, and continuous
contact for rolling and scraping. The `.modal` format already carries
`strike_positions` and the material constants those need, and the loader
validates them.

**The week 2 gate is not passed yet** — it asks whether a fitted ceramic mug
is recognisable as that mug in a blind A/B, and that needs real recordings
and a pair of ears. Everything the fitter can be held to without them is
done, so when the recordings arrive a poor fit will mean the method meeting
real signal, not a bug in the implementation. That is the distinction the
risk register needs to make a kill decision on.

Modal synthesis models linear vibration of rigid resonant bodies. It is good
for things that ring and poor for anything dominated by turbulence, friction
noise without resonance, or non-linear deformation. Cloth, flesh, foliage and
liquids are non-goals.
