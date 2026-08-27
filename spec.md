# Spec — Kobo-style Sleepscreen Banner (Prettified)

Status: implemented through **v2.1.2**. Reference device: jailbroken Kindle
PaperWhite 6, KOReader v2026.07.1.

## 1. Trigger conditions

`UIManager:show` is intercepted; the banner is restyled only when ALL hold:

- widget name == `"ScreenSaver"`
- `screensaver_show_message` true, `screensaver_message_container` == `"banner"`
- `screensaver_type` ∈ {`cover`, `document_cover`, `random_image`}
- the banner container exposes the stock TextBoxWidget layout

Everything else passes through untouched.

## 2. Settings

`B_SETT` / `HL_SETT` (file) are defaults; `G_reader_settings` are runtime
overrides set from the menu and win.

| G_reader_settings key                | values                                      | fallback                     |
|--------------------------------------|---------------------------------------------|------------------------------|
| `screensaver_banner_style`           | `floating_card` `pill` `full_width` `outlined` `bracketed` | `B_SETT.style`, then `floating_card` |
| `screensaver_banner_title_font`      | full font path                              | `B_SETT.title_fontFace`      |
| `screensaver_banner_stats_font`      | full font path                              | `B_SETT.stats_fontFace`      |
| `screensaver_banner_highlight_font`  | full font path                              | `HL_SETT.highlight_fontFace` |
| `screensaver_banner_footer_font`     | full font path                              | `HL_SETT.hl_footer_fontFace` |

Font resolution per role: persisted path → config name resolved by basename
against `fontlist.fontlist` → KOReader alias (`cfont`) → `cfont`. A face
that fails to load falls back to the KOReader UI font face.

## 3. Styles

| id            | frame | border  | corners       | shadow           | side margins | notes |
|---------------|-------|---------|---------------|------------------|--------------|-------|
| `floating_card` | yes | `B_SETT` | `B_SETT.radius` | offset, same radius | yes | classic look, default |
| `pill`          | yes | `B_SETT` | height/2       | offset, same radius | yes | side padding grows to the cap radius (screen-limited) so text never sits on a curve |
| `full_width`    | yes | `B_SETT` | 0             | off               | none         | card spans `screen_w` via LeftContainer; `max_width_*` ignored |
| `outlined`      | yes | 5 px    | `B_SETT.radius` | off             | yes          | ghost card |
| `bracketed`     | yes | 0       | 0             | off               | yes          | menu label **"Flat box"**: bare solid backing; id kept from v2.1.0 for settings compatibility |

## 4. Settings menu

- Top-level **Banner style** at the bottom of the Settings tab (reader +
  file browser), registered by wrapping `setUpdateItemTable` on
  `ReaderMenu`/`FileManagerMenu` and inserting the key into the order table
  *before* the original builder runs (MenuSorter drops unlisted items).
- Submenu: **Message style** (5 radio items) + **Fonts** (4 role pickers).
- Each font picker lists "Default (from the config file)" plus every path
  in `fontlist.fontlist`, rendered in its own font.
- Picks persist to `G_reader_settings` and apply from the next sleep.

## 5. Highlight behavior

- Eligible annotations: drawer in `HL_SETT.allowed_hl_styles` AND
  non-empty trimmed text.
- If none survive, the entire highlight section (accent rule, quote,
  footer) is skipped.
- The shown highlight is randomized but never repeats back-to-back.

## 6. Compatibility

- Needs the MenuSorter/order-table settings menu (KOReader ≈2024.07+);
  older installs degrade to file-configured defaults with no menu entry.
- Widget contracts relied upon: FrameContainer positional child (`self[1]`),
  per-side padding honored by getSize/paintTo, `LineWidget` dimen-driven
  rules, `CustomPositionContainer.horizontal_position` ∈ [0,1].

## 7. Testing contract

- `test/harness.lua` green on Lua 5.4 **and** LuaJIT before any deploy.
- Stub widgets must mirror device semantics (positional child, per-side
  padding, size aggregation); when in doubt, read the device's sources
  under `/mnt/us/koreader/frontend/` rather than assuming.
