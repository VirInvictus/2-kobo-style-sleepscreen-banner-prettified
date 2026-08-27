# Kobo-style Sleepscreen Banner (Prettified)

A [KOReader](https://koreader.rocks) user patch that redesigns the built-in "banner" sleep-screen message into a Kobo-lockscreen-style **floating card** laid over your book cover. The card shows the book title, reading progress, and (optionally) a random highlight pulled from the book you were last reading.

This is a *prettified* fork of an existing community patch. It keeps the original banner behaviour and adds:

- A **floating-card visual identity**: rounded corners plus a hard offset drop shadow, so the card reads as a tag sitting above the cover rather than a flat box.
- **Menu-selectable fonts**: pick the title, stats, highlight and footer fonts from anything KOReader can see, right in the settings (defaults wired for the [ebook-fonts](https://github.com/nicoverbruggen/ebook-fonts) serif collection).
- **Selectable banner styles**: the floating card, a pill, a full-width banner, an outlined ghost card, and a flat no-border box — pick one under Settings → Banner style, no restart needed.

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
- Fonts for the defaults. As shipped it expects **Libron** from the [ebook-fonts](https://github.com/nicoverbruggen/ebook-fonts) collection (see [Fonts](#fonts)); anything missing just falls back to your KOReader UI font, and every font is switchable in the menu anyway.

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
| `style` | `"floating_card"` | Default banner style (see [Banner styles](#banner-styles)). Used until you pick a style in the Sleep Screen settings menu, which then takes precedence. |
| `title_text` | `"%T"` | Big title line. Accepts the same tokens as the KOReader sleep message (`%T`, `%A`, `%c`, `%t`, ...). |
| `title_fontFace` | `"Libron_R-Bold.ttf"` | Font for the title. A bare filename (resolved against every font KOReader can see), or a KOReader alias like `cfont`. Menu pick wins over this. |
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

### Banner styles

Open **Settings → Banner style** — a top-level entry at the bottom of the Settings tab (it shows up in the file browser's settings too, next to the stock "Sleep screen" entry). Inside you get **Message style** (the five looks below) and **Fonts** (see [Banner fonts](#banner-fonts)). The choice is saved with KOReader's settings and applies from the next sleep — no restart needed. If you have never picked one there, the `style` value in `B_SETT` is used instead.

### Banner fonts

Under **Banner style → Fonts** you can pick the font for each of the four text roles — title, stats, highlight and footer — from every font file KOReader can see (each entry renders in its own font). The pick is saved with KOReader's settings; choose "Default (from the config file)" to go back to the `B_SETT` values. Resolution is by font *file* name, in any subdirectory of `koreader/fonts/`, so collection-specific layouts (e.g. `relaxed-core-fonts/Libron_R-Bold.ttf`) work as-is.

| Style | Look |
| --- | --- |
| `floating_card` | The classic prettified look: rounded corners plus the hard offset drop shadow. |
| `pill` | A fully rounded lozenge — the radius follows the card height and the sides get extra padding (up to the cap radius, as far as the screen allows) so the text always sits on the straight section, fully backed. Keeps the shadow. |
| `full_width` | The classic banner: spans the whole screen width flush against the edges, square corners, no shadow. `max_width_hl_off` / `max_width_hl_on` don't apply in this style; the text simply uses all the width the card has. |
| `outlined` | A ghost card: your usual background and corner radius, but an extra-thick 5 px border and no drop shadow. |
| `bracketed` | Shown in the menu as **Flat box**: a plain solid backing behind the text — no border, no rounded corners, no shadow. Just enough background to keep everything readable. (v2.1.0's rules-on-the-cover look was retired in v2.1.2.) |

### Highlights (`HL_SETT`)

| Key | Default | Meaning |
| --- | --- | --- |
| `showRandomHighlight` | `true` | Pull a random highlight from the last book. |
| `highlight_fontFace` | `"Libron_R-Italic.ttf"` | Font for the quote. |
| `highlight_fontSize` | `16` | |
| `justify` | `true` | Justify the quote text. |
| `add_quotations` | `true` | Wrap the quote in typographic quotes if it lacks them. |
| `show_accent_line` | `true` | Draw a vertical accent rule beside the quote. |
| `showHighlightFooter` | `true` | Show an attribution line under the quote. |
| `hl_footer_fontFace` | `"Libron_R-Regular.ttf"` | Font for the footer. |
| `hl_footer_fontSize` | `15` | |
| `hl_footer_text` | `"saved on %DT at %HM"` | Footer template (see tokens below). |
| `allowed_hl_styles` | lighten, underscore | Which highlight drawer styles are eligible to be shown. |

### Footer tokens

`%DT` date, `%HM` time, `%PG` page, `%C` chapter, `%A` author, `%T` title, `\n` line break.

## Fonts

The defaults expect the serif **Libron** from the [ebook-fonts](https://github.com/nicoverbruggen/ebook-fonts) collection (the page counter stays on `cfont` so it inherits your KOReader UI font). Specifically the defaults are:

- `Libron_R-Bold.ttf` (title)
- `Libron_R-Italic.ttf` (highlight quote)
- `Libron_R-Regular.ttf` (highlight footer)

Note the `_R` infix — that's how the current ebook-fonts collection names these files (on the device they land under `koreader/fonts/relaxed-core-fonts/`). Older releases used `Libron-Bold.ttf`-style names; if yours are named that way, rename them or just pick them in the menu.

You don't have to install anything, though: every font KOReader can see is selectable under **Banner style → Fonts**, and anything unresolvable falls back to your KOReader UI font. Aliases like `cfont` still work in `B_SETT` too.

## How it works

The patch wraps `UIManager:show`. When the widget being shown is the screensaver, and the current settings match the banner-over-cover case, it walks into the screensaver's message container, rebuilds the message as a framed card (title, stats, and optional highlight widgets), composites a drop shadow behind it with an `OverlapGroup`, and hands the result back to the original `show`. In every other case it calls straight through, so nothing else is affected.

It also hooks the settings menu. KOReader assembles its menus by merging `menu_items` with an order table (MenuSorter), and any item missing from the order is silently dropped — so the patch registers a top-level **Banner style** key and inserts it into the order table *before* the original builder runs, following the same approach as the community ui-font user patch. This needs a reasonably recent KOReader; on older installs the patch keeps working, just with the file-configured `style`.

## Credits

- Original patch: **zenixlabs**, from [koreader-frankenpatches-public](https://github.com/zenixlabs/koreader-frankenpatches-public) ([source file](https://github.com/zenixlabs/koreader-frankenpatches-public/blob/main/2-kobo-style-sleepscreen-banner.lua)). zenixlabs designed the Kobo-style banner and the random-highlight feature.
- Written in collaboration with Discord user **@sandcastles**. (the original, not this one)
- Design cues borrowed from a similar patch by Reddit user **u/juancoquet**.
- Distributed through the KOReader plugin app store, which pointed at the zenixlabs repo.
- Prettified fork (floating-card design, font wiring): **VirInvictus**.

## License

Licensed under the **GNU Affero General Public License v3.0** (AGPL-3.0), matching KOReader, on which this patch depends. See [`LICENSE`](LICENSE) for the full text.

This is a derivative of an earlier community patch (see [Credits](#credits)); that attribution is preserved in the source header. If you reuse or redistribute, keep the attribution intact.

## Support

This is a prettified fork of zenixlabs' original patch (see [Credits](#credits)); please support the original author first. If this fork's useful to you and you'd like to chip in:

- liberapay · [liberapay.com/bdkl](https://liberapay.com/bdkl/)
- bitcoin
  ```
  bc1qkge6zr45tzqfwfmvma2ylumt6mg7wlwmhr05yv
  ```
