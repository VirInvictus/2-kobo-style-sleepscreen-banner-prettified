# Roadmap

This roadmap tracks the development phases for turning the static user patch into a fully customizable KOReader plugin (or an advanced patch with interactive settings).

## Phase 1: Dynamic Settings & Styles
*Context: Based on architectural research, the patch currently hardcodes a single "Floating Card" layout. We can expand this into multiple selectable styles by hooking into KOReader's menu system.*

- [ ] **Menu Integration:** Hook into the **Settings → Screen → Sleep Screen** menu.
  - *Technical path:* Either monkey-patch `Screensaver:addToMainMenu` in `screensaver.koplugin`, or transition this codebase to a standalone `.koplugin` that registers `addToMainMenu(menu_items)`.
- [ ] **Style Switcher UI:** Add a `TouchMenu` or `MultiConfirmBox` widget allowing the user to select their preferred banner style.
- [ ] **Implement 'Floating Card' Style:** (Current behavior). Retain the rounded corners and the offset drop shadow (`OverlapGroup` + `FrameContainer`).
- [ ] **Implement 'Pill / Badge' Style:** A center-floating lozenge (set `radius` to `box_height / 2`).
- [ ] **Implement 'Full-Width' Style:** A classic banner spanning `screen_w`, flush against the left and right edges with no shadows and zero margins.
- [ ] **Implement 'Outlined' Style:** A minimalist ghost card using `COLOR_WHITE` background and a thick `bordersize`, bypassing the drop shadow entirely.
- [ ] **Implement 'Bracketed' Style:** A typographic design using a `VerticalGroup` sandwiched between two horizontal `LineWidget`s, replacing the `FrameContainer` completely.

## Phase 2: Robust Highlight Handling
*Context: Refining the aesthetic behavior when edge cases in book metadata or reading history occur.*

- [ ] **Hide if N/A:** If a book has no highlights (or the parser returns an empty string or `"N/A"`), gracefully skip rendering the highlight section entirely.
  - *Implementation note:* Currently, if `highlightEnabled` is true, the script always builds the `highlight_widget` (lines 482-515) and prepends the accent line. We need to wrap that block in an `if random_highlight and random_highlight ~= "" then` check so it doesn't render an empty floating accent line with a blank space next to it.
