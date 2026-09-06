# Checkpoint — assets

Everything in the game is currently **drawn in code**, so it runs and is
testable with no art at all. Art drops over the top without the layout moving.

## What is painted

| Asset | File | Notes |
|---|---|---|
| Booth background | `assets/scene/booth.png` | 1344x768, drawn nearest-neighbour to 1920x1080 |
| Clipboard | `assets/props/clipboard.png` | Holds the traveller's file — name and reason |
| Radio | `assets/props/radio.png` | The object `Scares.Id.RADIO` speaks out of |
| Mug, desk lamp | `assets/props/` | Dressing |
| Family photograph | `assets/props/photo_family.png` | One of its three faces is put out per shift |
| Traveller 00 | `assets/portraits/00.png` | 1 of 20 |

Prop positions live in `scripts/ui/props.gd` as fractions of the frame, and
the room asks the painting where the hatch and the side pane are rather than
repeating the numbers — so a repaint at another size does not move the
interface.

## What is still drawn in code

| Thing | Where | Replaced by |
|---|---|---|
| Travellers 01-19 | `scripts/ui/portrait_view.gd` | Painted portraits |
| The faceless one | `scripts/ui/portrait_view.gd` | A painted figure |
| Safe-zone lights | `scripts/ui/booth_view.gd` | Could stay code — it has to animate |
| The dark closing in | `scripts/ui/booth_view.gd` | Stays code — it tracks dread |

A generated face is drawn from its portrait seed, so the same traveller always
has the same face, and the game is playable and testable before any of the
twenty are painted.

## Still needed

| Asset | Size | Count |
|---|---|---|
| Traveller portraits | ~768x720 | 19 more |
| Scare stills | 1920x1080 | 6 |
| Faceless traveller | ~768x720 | 1 |

### The blink is load-bearing

People blink and shift their weight. A thing that has not learned to yet does
not. This is one of the seven tells and the one players find first.

**A painted portrait is not finished until it says where its eyes are.** The
blink is a lid drawn over a band named in `scripts/ui/portraits.gd`, so every
new face needs a row in that table giving its eye band as a fraction of the
image. Without one it falls back to a drawn face, which blinks on its own.

From shift five the blink stops meaning anything — things learn it, and the
people out there are too tired to do it — so the art has to read both ways.

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
