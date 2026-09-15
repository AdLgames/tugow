# modal-gen

A model from a shape and a material. No recording, no microphone.

```bash
modal-gen --shape bar --material steel --length 0.30 --thickness 0.012 \
          --strikes 5 --out models/generated/steel_bar.modal
modal-gen --list
```

## Why this exists

§11 of the build plan wants a CC0 starter library and calls hand-authoring
models impractical. It is — but the three models that already exist were hand
authored, and they follow power laws exact to four decimal places across
fourteen to eighteen modes. That is a generator, run by hand, once. This is
the same generator with the arithmetic written down.

It also answers a practical problem: usable recordings need raw, unprocessed
audio, and sourced sound effects are processed by definition. A generated
model needs neither.

## What is physics and what is not

**The frequencies are physics.** A free-free bar's modes stand in the ratio of
the squares of the roots of `cos(x)cosh(x) = 1` — 1 : 2.757 : 5.404 : 8.933 —
and that is in every acoustics text. Give the dimensions and a wave speed and
the frequencies follow with nothing left to taste. `tests/test_generator.cpp`
checks them against the textbook values, not against this implementation.

**The damping is empirical and says so.** A single loss factor would give
`tau ∝ 1/f`, and real objects do not do that. Measured on the three models
already in `models/`, decay falls as:

| Model | | |
|---|---|---|
| `steel_pipe` | τ₁ₖ 4.42 s | τ ∝ f⁻⁰·⁴²⁰ |
| `glass_tumbler` | τ₁ₖ 2.85 s | τ ∝ f⁻⁰·⁵⁵⁰ |
| `ceramic_mug` | τ₁ₖ 1.63 s | τ ∝ f⁻⁰·⁷⁰⁰ |

Those are the constants the generator carries, so it extends the existing
library rather than offering a second opinion about what ceramic sounds like.
A generated ceramic object retuned to 1245 Hz comes out at τ = 1.40 s, which
is the hand-authored mug exactly — and that is a test.

Aluminium, brass and stone were not in that library. They are placed by ear
against the three that were, and `materials.cpp` marks which is which.

## Shapes

| Family | Good for | Series |
|---|---|---|
| `bar` | rod, bar, pipe struck across, railing, cutlery | 1 : 2.76 : 5.40 : 8.93 — sparse and strongly stretched |
| `plate` | tile, pane, sheet, tray | dense 2D series |
| `shell` | mug, glass, bowl, bell, bottle | depends entirely on `--height` |

**`--height` is the most important flag on a shell.** Axial stiffness goes as
1/height², so:

- **shallow and wide** (a bell, a bowl, the rim of a wine glass) puts the
  axial modes far above the ring modes, leaving the clean stretched series
  1 : 2.83 : 5.42 that lets a wine glass sing one note
- **tall and narrow** (a tumbler, a vase) brings them down among the ring
  modes, filling the gaps and giving the dense, less stretched series that
  crockery actually has

It is the difference between a bell and a mug.

## Strike maps

`--strikes N` writes real `strike_positions` for a **bar**, where the mode
shapes have a closed form: the gain of mode k at position u is that mode's
displacement there, so striking a node genuinely fails to excite it. The test
checks the fundamental's node at 0.2242 of the length — the classic
suspension point for a xylophone bar, chosen for exactly that reason.

No model in this repository carried strike gains before, because the fitter
sees one strike per recording and cannot measure a map from it.

For plates and shells the gains are a standing-wave approximation, and the
tool says so on stderr rather than letting them look measured.

## `--fundamental`

Takes the series from the physics and the pitch from the object in front of
you. The ratios are exact; the absolute pitch is only as good as the
idealisation, and a real mug has a base and a handle that the closed form for
a shell does not.

## What this does not do

It does not replace the fitter and cannot. A generated model is an idealised
object of that shape and material. A fitted one is *your* mug, with its chip.
The week 2 gate asks whether a fitted mug is recognisable as that mug in a
blind A/B, and nothing here answers that question.

Two known limitations, both real:

- **A pipe is modelled as a bar,** which captures its bending modes and not
  its shell modes. A real pipe rings with both. Generating it as a `shell` as
  well and picking whichever sounds closer is the current workaround.
- **A bar's velocity response is modest** — about 5% centroid rise from
  0.5 to 8 m/s, against 41% for the hand-authored `steel_pipe`. The bar series
  is genuinely sparse, so the centroid is pinned by the fundamental. Shapes
  with denser series (plate, tall shell) reach 13–22%, and the hand-authored
  pipe's 41% comes from a series considerably denser than a real bar's.

Every generated model does get brighter with velocity, which is the week 1
gate's criterion.
