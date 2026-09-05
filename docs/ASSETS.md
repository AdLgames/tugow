# Checkpoint — assets

Everything in the game is currently **drawn in code**, so it runs and is
testable with no art at all. Art drops over the top without the layout moving.

## What exists as code today

| Thing | Where | Notes |
|---|---|---|
| Booth, desk, lamp, vignette | `scripts/ui/booth_view.gd` | The lamp is the whole lighting model |
| Safe-zone window, 8 lights | `scripts/ui/booth_view.gd` | Flickers per-light, on independent cycles |
| Family photo, 3 faces | `scripts/ui/booth_view.gd` | One face stops being a face per shift |
| 20 traveller portraits | `scripts/ui/portrait_view.gd` | Generated from the portrait seed, so the same traveller always has the same face |
| The idle blink | `scripts/ui/portrait_view.gd` | A mechanic, not decoration — see below |
| Faceless traveller | `scripts/ui/portrait_view.gd` | Shift five |

## What a painter would replace

| Asset | Size | Count | Note |
|---|---|---|---|
| Booth background | 1920x1080 | 1 | Desk, back wall, the door behind you |
| Safe-zone window overlay | ~280x125 | 3 states | Fully lit, half, dark |
| Traveller portraits | 520x560 | 20 | **Each needs a 2-frame idle blink** |
| Faceless traveller | 520x560 | 1 | |
| Scare stills | 1920x1080 | 6 | One per entry in `Scares.Id` |
| Family photo | 116x86 | 8 | One variant per shift |

### The blink is load-bearing

People blink and shift their weight. A thing that has not learned to yet does
not. This is one of the seven tells and it is the one players find first, so
every human portrait needs a genuine two-frame idle and things need a
perfectly still one. From shift five it stops meaning anything — things learn
it, and the people out there are too tired — and the art has to support both.

## Audio — spend the money here

| Sound | Count | Note |
|---|---|---|
| Room hum | 2 pitches | The pitch shift *is* a tell (`Tells.Id.HUM_SHIFT`) |
| Footsteps approaching | 3 | |
| Stamp | 2 | Approve and deny should not sound alike |
| Scare stings | 6 | One per scare |
| Radio static | 1 | |
| Your name, screamed | 1 | For `Scares.Id.RADIO` |
| Voice blips or 20 short clips | 20 | Optional; blips are fine |

There is no music. The room hum, the footsteps and the voices are the whole
soundtrack, which is both cheaper and more frightening.
