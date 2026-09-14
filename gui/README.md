# Modal Fit

The fitting-tool GUI: a late-90s pro-audio front panel for inspecting a
`.modal` model and the excitation that drives it.

It is one scene in two shells. Run the Godot project directly and it is a
standalone desktop application; enable `addons/modal_fit` in a Godot project
and the same panel mounts as a main-screen tab, so a developer inspects a model
without leaving the editor. Nothing in `ui/` touches an editor API, which is
what keeps both shells working from one implementation.

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
running from the repository, or `models/` beside the binary when exported.
**Open .modal** loads one from anywhere.

## What actually works

Four controls, all of them driving the same recomputation:

- **Impact velocity** recomputes the fractional Hann contact pulse, evaluates
  each mode's excitation gain from the pulse's transform, and updates every
  plot and readout. You can watch the object get brighter.
- **Stage stepper** — onset, peak picking, tracking, decay fit, verify. Five
  views of one model, all of them downstream of the velocity slider.
- **Mode table** — click a row to solo it; every plot follows. With eleven
  overlapping decay curves this is the only way to see which is which.
- **Host rate** reloads the model at 44.1, 48 or 96 kHz, because which modes
  survive is decided at load and the panel should show that rather than let a
  developer discover it in the game.

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
ui/
  modal_fit_panel.gd     the screen: three columns, built in code
  widgets/               the four plot views, the mode table, the casting
tests/test_parity.gd     parity with the C++
tools/capture*.gd        render to PNG, for design review and CI
```

## Capturing

```bash
xvfb-run -a godot --path gui --script res://tools/capture.gd -- panel.png
xvfb-run -a godot --path gui --script res://tools/capture_stages.gd -- stage
```

The second walks all five stages at two velocities. Headless runs never call
`_draw`, and nearly all of this panel is `_draw`, so a capture is the only
thing that proves the drawing code runs.
