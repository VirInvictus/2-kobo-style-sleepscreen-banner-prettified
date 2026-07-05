# Kobo-style Sleepscreen Banner (Prettified)

A [KOReader](https://koreader.rocks) user patch that redesigns the built-in "banner" sleep-screen message into a Kobo-lockscreen-style **floating card** laid over your book cover. The card shows the book title, reading progress, and (optionally) a random highlight pulled from the book you were last reading.

This is a *prettified* fork of an existing community patch. It keeps the original banner behaviour and adds:

- A **floating-card visual identity**: rounded corners plus a hard offset drop shadow, so the card reads as a tag sitting above the cover rather than a flat box.
- **Per-element font control**, wired for the [ebook-fonts](https://github.com/nicoverbruggen/ebook-fonts) collection out of the box (serif title and quote, a legible sans for the page counter).

See [Credits](#credits) for the original authors.

## What it does

When your device sleeps, instead of the plain KOReader message you get a card containing:

- **Title** in a serif display face (`%T` by default).
- **Stats line**, whatever you set your KOReader sleep message to (for example `page %c of %t`, or an author line plus a counter).
- **A random highlight** from the last book, as an italic pull-quote with an accent rule and an attribution footer ("saved on ... at ...").

Everything sits inside an opaque, rounded, shadowed card. The card is drawn once on suspend, so there is no E Ink refresh cost while you read.

## Requirements

- KOReader (reasonably recent; the patch carries a compatibility shim for versions older than `v2025.04-115`).
- A device where you can drop files into `koreader/patches/` (Kobo, Kindle with a KOReader install, PocketBook, reMarkable, Android, etc.).
- The screensaver configured to use the banner message over a cover image (see below).
- The fonts named in the default config. As shipped it expects **Libron** from the [ebook-fonts](https://github.com/nicoverbruggen/ebook-fonts) collection (see [Fonts](#fonts)). Any font already on your device works too; you just change the config.

## Installation

1. Copy `2-kobo-style-sleepscreen-banner.lua` into your `koreader/patches/` directory.
   - **Keep the `2-` filename prefix.** KOReader runs `2-` patches after its UI and widget system are loaded, which this patch needs.
2. Restart KOReader (a full exit and relaunch, not just a wake from sleep). Patches load at startup.

## KOReader setup

The patch only takes over when the stock sleep screen is configured as a message-over-cover banner. In KOReader set:

- **Screensaver → Wallpaper**: `Book cover`, `Random image`, or `Custom image` (`document_cover`, `random_image`, or `cover`).
- **Screensaver → Message**: enabled.
- **Screensaver → Message position/style**: the `banner` container.

Because the patch draws the title separately (via `title_text`, default `%T`), set your KOReader sleep message so it does not repeat the title. For example a message of:

```
%A
%c / %t
```

gives you: big serif **title**, then **author** and a **page counter** inside the card.

## Configuration

All options live in the two tables at the top of the `.lua` file. Edit, save, restart KOReader.

### Banner (`B_SETT`)

| Key | Default | Meaning |
| --- | --- | --- |
| `title_text` | `"%T"` | Big title line. Accepts the same tokens as the KOReader sleep message (`%T`, `%A`, `%c`, `%t`, ...). |
| `title_fontFace` | `"Libron-Bold.ttf"` | Font for the title. A bare filename, or a KOReader alias like `cfont`. |
| `title_fontSize` | `30` | |
| `stats_fontFace` | `"cfont"` | Font for the stats block. `cfont` follows KOReader's UI font. |
| `stats_fontSize` | `17` | |
| `border_size` | `1` | Card border thickness (px). |
| `border_color` | `0` | `0` = white, `1` = black. |
| `background` | `0` | Card fill. `0` = white, `1` = black. |
| `margin` | `10` | Gap between the card and the screen edge (px). |
| `padding` | `15` | Inner padding between the border and the text (px). |
| `max_height` | `50` | Card height ceiling, as a percent of screen height. |
| `max_width_hl_off` | `40` | Card width (percent) when no highlight is shown. |
| `max_width_hl_on` | `60` | Card width (percent) when a highlight is shown. |
| `corner_radius` | `8` | Rounded-corner radius (px). `0` = square corners. |
| `shadow_enabled` | `true` | Draw the floating drop shadow. |
| `shadow_offset` | `6` | How far the shadow peeks past the bottom-right edge (px). |
| `shadow_gray_level` | `5` | Shadow tone, `COLOR_GRAY` level `1` (dark) to `9` (light). |

### Highlights (`HL_SETT`)

| Key | Default | Meaning |
| --- | --- | --- |
| `showRandomHighlight` | `true` | Pull a random highlight from the last book. |
| `highlight_fontFace` | `"Libron-Italic.ttf"` | Font for the quote. |
| `highlight_fontSize` | `16` | |
| `justify` | `true` | Justify the quote text. |
| `add_quotations` | `true` | Wrap the quote in typographic quotes if it lacks them. |
| `show_accent_line` | `true` | Draw a vertical accent rule beside the quote. |
| `showHighlightFooter` | `true` | Show an attribution line under the quote. |
| `hl_footer_fontFace` | `"Libron-Regular.ttf"` | Font for the footer. |
| `hl_footer_fontSize` | `15` | |
| `hl_footer_text` | `"saved on %DT at %HM"` | Footer template (see tokens below). |
| `allowed_hl_styles` | lighten, underscore | Which highlight drawer styles are eligible to be shown. |

### Footer tokens

`%DT` date, `%HM` time, `%PG` page, `%C` chapter, `%A` author, `%T` title, `\n` line break.

## Fonts

**This fork's default config depends on the [ebook-fonts](https://github.com/nicoverbruggen/ebook-fonts) collection.** It uses the serif **Libron** for the title, quote, and footer, and leaves the page counter on `cfont` so it inherits your KOReader UI font. Specifically it expects these three files to be somewhere KOReader scans for fonts (for example `koreader/fonts/`):

- `Libron-Bold.ttf` (title)
- `Libron-Italic.ttf` (highlight quote)
- `Libron-Regular.ttf` (highlight footer)

Grab them from the ebook-fonts release (they live under `fonts/core/`). If you would rather not install them, change the `title_fontFace`, `highlight_fontFace`, and `hl_footer_fontFace` values to fonts you already have. Any filename in a KOReader font path works, as does an alias like `cfont` or `NotoSerif-Regular.ttf`. Nothing else in the patch depends on ebook-fonts.

## How it works

The patch wraps `UIManager:show`. When the widget being shown is the screensaver, and the current settings match the banner-over-cover case, it walks into the screensaver's message container, rebuilds the message as a framed card (title, stats, and optional highlight widgets), composites a drop shadow behind it with an `OverlapGroup`, and hands the result back to the original `show`. In every other case it calls straight through, so nothing else is affected.

## Credits

- Original patch: **zenixlabs**, from [koreader-frankenpatches-public](https://github.com/zenixlabs/koreader-frankenpatches-public) ([source file](https://github.com/zenixlabs/koreader-frankenpatches-public/blob/main/2-kobo-style-sleepscreen-banner.lua)). zenixlabs designed the Kobo-style banner and the random-highlight feature.
- Written in collaboration with Discord user **@sandcastles**.
- Design cues borrowed from a similar patch by Reddit user **u/juancoquet**.
- Distributed through the KOReader plugin app store, which pointed at the zenixlabs repo.
- Prettified fork (floating-card design, font wiring): **VirInvictus**.

## License

Licensed under the **GNU Affero General Public License v3.0** (AGPL-3.0), matching KOReader, on which this patch depends. See [`LICENSE`](LICENSE) for the full text.

This is a derivative of an earlier community patch (see [Credits](#credits)); that attribution is preserved in the source header. If you reuse or redistribute, keep the attribution intact.
