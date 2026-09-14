# Modal Fit

A late-90s pro-audio front panel for the Modal engine, with two faces.

**Sounds** is the front of the machine, and what opens: pick an object, shape
it, save it. Most of the time the question is "what does a crate sound like",
not "what is the R² of mode 7".

**Analysis** is the service panel underneath — the five fit stages, the mode
table, every threshold. It is what proves the engine does what it claims; it
just is not where anyone starts.

One `FitState` between them, so a size change made on the front panel is what
the spectrogram redraws.

It is also one scene in two shells. Run the Godot project directly and it is a
standalone desktop application; enable `addons/modal_fit` and the same screens
mount as a main-screen tab, so a developer works without leaving the editor.
Nothing in `ui/` touches an editor API, which is what keeps both working from
one implementation.

**Silent.** Every plot is computed from the same maths the engine uses, but no
audio is rendered. Week 3 is where the GDExtension and the voice pool land; the
panel is deliberately ahead of them.

## Run it

Godot 4.2 or newer.

```bash
godot --path gui                       # standalone
godot --path gui --headless --script res://tests/test_parity.gd   # tests
```

Models are found automatically: `../models` relative to the project when
running from the repository, `models/` beside the binary when exported, and
`user://sounds` for variants you save. **Open a .modal file** loads one from
anywhere.

## Sounds

Three controls shape the object, one says how hard you hit it, and that split
is the point rather than a tidying. Size, ring and striker are properties of
the thing and are saved into the `.modal`; hit strength is a performance
parameter the physics engine supplies per collision and is never saved.

| Control | What it really is |
|---|---|
| **Size** | Scales every frequency. Geometric scaling — a mug twice as big rings an octave lower. The *ratios* between modes are untouched, which is why it still sounds ceramic. |
| **Ring** | Scales every decay time. The material's internal damping. |
| **Striker** | `material.contact_time_ref_ms` — what you hit it *with*. A pen cap is a short contact and a wide excitation; a rubber mallet is a long one. |
| **How hard you hit it** | Impact velocity. Not saved. |

There is deliberately **no brightness knob**. Brightness is what the engine is
supposed to produce rather than be told — it falls out of contact time, which
is striker and velocity. A control that reached in and lifted the high modes
directly would be the sample-based approximation this project exists to avoid,
and would make the model lie at every velocity but the one it was set at.

**Save as a new sound** writes a real `.modal`. `tools/write_variant.gd` does
the same thing from the command line, and its output is checked by loading it
with `modal-render --report` — the loader that actually matters, rather than
the GDScript port checking its own work.

### The flat-object warning

A striker hard enough to pin contact time at its 0.05 ms floor produces an
object that only ever gets *louder*. That is the exact failure the engine
exists to prevent — six clips of glass at different volumes — and it is two
fader-widths away on the simple screen. So the panel measures the spectral
centroid at both ends of the hit fader and, when the object has stopped
responding, says so in red with the velocity it gave up at.

## Analysis

- **Impact velocity** recomputes the fractional Hann contact pulse, evaluates
  each mode's excitation gain from the pulse's transform, and updates every
  plot and readout.
- **Stage stepper** — onset, peak picking, tracking, decay fit, verify. Five
  views of one model, all downstream of the velocity slider.
- **Mode table** — click a row to solo it; every plot follows. With eleven
  overlapping decay curves this is the only way to see which is which.
- **Host rate** reloads at 44.1, 48 or 96 kHz, because which modes survive is
  decided at load and the panel should show that rather than let a developer
  discover it in the game.

The **strike map** is inert for now, and says so: the format reserves
`strike_positions` and `model.cpp` validates them, but no model in `models/`
carries any, so the panel falls back to unit gains rather than inventing four
positions and letting them look measured.

## Fonts

The design is set in Space Mono. It is not vendored here — that is a licence
decision, not a technical one — so `ModalTheme` resolves it through
`SystemFont`: installed, it is used; absent, the chain falls back to a
typewriter monospace that keeps the character.

To pin it exactly, drop `SpaceMono-Regular.ttf` and `SpaceMono-Bold.ttf` into
`gui/fonts/` and they are picked up ahead of the system chain.

## The parity test

`tests/test_parity.gd` checks this GUI's arithmetic against the C++ it mirrors
— contact time, pulse width and shape, the loader's drop/sort/normalise
behaviour, and the clamp. Expected values were produced by compiling
`core/src/excitation.cpp` and `core/src/model.cpp` and printing them, not by
running this port and recording what it said.

That matters more here than in most GUIs. The panel makes claims about an
object — this is how bright it gets, this is where it stops, these are the
modes your runtime will voice. A GUI that is approximately right is a GUI that
lies quietly.

It exits non-zero on failure.

## Where this departs from the mockup

The design was drawn against eight hand-authored stand-in modes. Against the
real models, four things had to change, and each is a case of the mockup
being right about the layout and wrong about the data:

| The mockup | Why it could not stand | What it does now |
|---|---|---|
| "above ~10 m/s an impact stops getting brighter" | The clamp velocity is `(t_ref / 0.05 ms)^5`. That is steel's figure. Ceramic does not clamp until **243 m/s** — the sentence was wrong by 24× under the object it was printed beneath. | Derived from the loaded material. |
| Frequency axis fixed at 12 kHz | Ceramic's modes run to 20 kHz, so its top five stacked against the right edge as one blur. | Axis follows the model, 12 kHz floor. |
| Time plots fixed at 1.2 s | Ceramic rings for 1.4 s. Every trace was a solid block and the spectrogram showed no decay at all. | 2.5 time constants, capped at 4 s. |
| "Rejected candidates", with reasons | A `.modal` file records the modes that survived and keeps no memory of the ones that did not. Those rejections live in a `modal-fit --explain` run. | Reports what a loaded model genuinely can: the modes this sample rate will not voice, in the loader's own words. |

The panel also reports `fit_quality` as "not fitted" rather than `0.000` for
the three hand-authored models, because a zero rendered in the same green as a
good fit reads as a catastrophic one.

## Layout

```
project.godot            standalone entry point
addons/modal_fit/        editor entry point — a main-screen tab
scripts/
  modal_model.gd         .modal loading and validation, ported from model.cpp
  excitation.gd          contact time and the strike pulse, from excitation.h
  fit_state.gd           what the panel is showing, and the only place it is computed
  theme.gd               the palette and the panel chrome
  draw_util.gd           rounded gradients, inset shadows, letterspacing
  model_tweak.gd         size, ring and striker as physical transforms; the writer
  sound_words.gd         what a model sounds like, in words, from its numbers
  model_library.gd       where the .modal files are
ui/
  app_shell.gd           the two faces and the tab between them
  sound_panel.gd         Sounds: pick, shape, save
  modal_fit_panel.gd     Analysis: three columns, built in code
  widgets/               the four plot views, the mode table, the casting
tests/test_parity.gd     parity with the C++
tools/
  capture.gd             render a screen to PNG; takes size/ring/striker
  capture_stages.gd      walk all five analysis stages
  write_variant.gd       write a tweaked model, to hand to the C++ loader
```

## Capturing

```bash
xvfb-run -a godot --path gui --script res://tools/capture.gd -- panel.png
xvfb-run -a godot --path gui --script res://tools/capture.gd -- t.png 0.55 0.4 0.05
xvfb-run -a godot --path gui --script res://tools/capture_stages.gd -- stage
```

The second captures a tweaked object, which is how the flat-object warning gets
looked at. The third walks all five analysis stages at two velocities.

The second walks all five stages at two velocities. Headless runs never call
`_draw`, and nearly all of this panel is `_draw`, so a capture is the only
thing that proves the drawing code runs.
