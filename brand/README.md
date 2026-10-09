# Purrtion brand mark

A cat peeking out of a food bowl, and the bowl carries the graduations of a measuring
beaker. It says three things at once: cats (and a cute one), feeding, and the measured
portion. A separate scale or extra icon is not needed.

| File | Use |
| --- | --- |
| `purrtion-mark.svg` | Primary mark: sidebar brand, README, about screens. Die-cut white sticker edge, so it works on light and dark backgrounds. |
| `purrtion-favicon.svg` | Browser tab icon. Same mark with blush, mouth and the middle graduation removed, so it stays legible at 16 px. |
| `purrtion-app-icon.svg` | macOS / home-screen tile: the mark on lavender graph paper. |
| `purrtion-app-icon-1024.png`, `apple-touch-icon.png` (180 px) | Raster exports of the tile. |
| `Purrtion.icns` | macOS app icon (16–1024 px, PNG payloads), used by `script/build_and_run.sh`. |
| `cat-icons.svg` | Sprite with the 12 cat profile icons (see below). |

The raster files are generated from the SVGs. To regenerate them:

```sh
rsvg-convert -w 1024 brand/purrtion-app-icon.svg -o brand/purrtion-app-icon-1024.png
rsvg-convert -w 180  brand/purrtion-app-icon.svg -o brand/apple-touch-icon.png
```

## Cat profile icons

`cat-icons.svg` is a sprite of twelve 24 × 24 `<symbol>`s (`icon-<name>`). Owners pick one per
cat, and it is shown as a small badge on the cat's avatar. The names match the `Cat.icon` values in
the plan schema. They are drawn like the mark: 1.6 px ink outline, rounded joins, brand pastels, and
they are legible at 16 px.

| Icon | Motif | Example cat |
| --- | --- | --- |
| `moon` | crescent moon | Luna |
| `scale` | kitchen scale with a food bowl | Oskar (weight plan) |
| `dango` | three-ball dango skewer | Mochi (kitten) |
| `stripes` | little tiger face | Tiger |
| `bolt` | lightning bolt | Pixel (active) |
| `paw`, `fish`, `yarn`, `star`, `heart`, `leaf`, `bow` | general choices | — |

The web UI renders the symbols inline. The Mac app redraws the same paths with SwiftUI `Path`s.
The sprite is the source of truth for both.

## Colours

| Token | Hex | Role in the mark |
| --- | --- | --- |
| ink | `#2B2541` | outlines, eyes, graduations |
| sakura | `#E8779E` | bowl, blush |
| sakura light | `#F4A9C2` | rim, inner ears |
| paper | `#F6F4FC` | app-icon tile |
| white | `#FFFFFF` | face, sticker edge |

## Rules

- Keep clear space of at least one ear-height around the mark.
- Do not recolour the cat. On photos, use the mark as is (the sticker edge separates it).
- The mark is not used on warning, error or veterinary-referral screens. Those stay plain.
- The wordmark is set live in M PLUS Rounded 1c ExtraBold (800), sentence case "Purrtion".
  It is not baked into the SVGs, so the files stay font-free.

The mark and icons are original work for this project and are covered by the repository's
MIT licence.
