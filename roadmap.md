# Roadmap

This roadmap tracks the development phases for turning the static user patch into a fully customizable KOReader plugin (or an advanced patch with interactive settings).

## Phase 1: Dynamic Settings & Styles ✅ — shipped in v2.1.0
*Context: Based on architectural research, the patch currently hardcodes a single "Floating Card" layout. We can expand this into multiple selectable styles by hooking into KOReader's menu system.*

- [x] **Menu Integration:** Hook into the settings menu (v2.1.1: the entry lives at the bottom of the Settings tab as **Banner style**).
  - *Implemented:* the patch wraps `setUpdateItemTable` on `ReaderMenu` and `FileManagerMenu` and registers a top-level `banner_style` key in the menu order table *before* the original builder runs — MenuSorter silently drops any item missing from the order, so this is the only reliable injection point. Same approach as the community ui-font patch. (KOReader loads plugin files with `dofile`, so monkey-patching the plugin module itself is unreliable; the menu modules are `require`-loaded core modules, so patching them sticks.)
- [x] **Style Switcher UI:** **Settings → Banner style → Message style**, radio-style picker for the five looks, persisted in `G_reader_settings` (`screensaver_banner_style`). Applies from the next sleep — no restart. Falls back to `B_SETT.style` when no menu choice has been made. (Bonus, v2.1.1: per-role **font pickers** under Banner style → Fonts.)
- [x] **Implement 'Floating Card' Style:** Default. Behaviour unchanged from v2.0.3.
- [x] **Implement 'Pill / Badge' Style:** Radius computed from the assembled card's height (`radius = height / 2`); the drop shadow follows the same radius.
- [x] **Implement 'Full-Width' Style:** Card stretched to `screen_w` via a `LeftContainer`, zero margins, square corners, no shadow; text uses all the width the chrome leaves over (`max_width_hl_*` percentages don't apply in this style).
- [x] **Implement 'Outlined' Style:** User background and corner radius kept, thick 3 px border, drop shadow removed.
- [x] **Implement 'Bracketed' Style:** shipped in v2.1.0 as typographic rules above/below the text; redesigned in v2.1.2 as **"Flat box"** (menu label) — a plain solid backing behind the text, no border, corners or shadow, which reads far better over real covers. Settings id unchanged.

## Phase 2: Robust Highlight Handling ✅ — shipped in v2.1.0
*Context: Refining the aesthetic behavior when edge cases in book metadata or reading history occur.*

- [x] **Hide if N/A:** The highlight build is now guarded with `if highlightEnabled and random_highlight and random_highlight ~= ""`. Books with no eligible highlights — or any highlight that trims to an empty string — skip the whole section (accent line, quote, footer) instead of rendering an empty accent line with a blank space next to it.

## Testing

`test/harness.lua` stubs KOReader's widget modules and exercises the patch headlessly: order-table menu registration, style persistence and fallback, `UIManager:show` pass-through guards, per-style card assembly with layout assertions, and draw-time font resolution (56 checks). Run it under **both** Lua 5.4 and LuaJIT: `lua test/harness.lua`. On-device visual verification per style is still worthwhile.
