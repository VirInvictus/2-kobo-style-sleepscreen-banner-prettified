# Research: KOReader Settings Menus and Box Styles

## 1. Adding Menu Items in KOReader

To expose settings in KOReader (like letting the user toggle between "styles" of boxes), the standard plugin architecture uses the `addToMainMenu` function.

If we convert this user patch into a full plugin (or hook the existing `screensaver` plugin), we would define:

```lua
function KoboBannerPlugin:addToMainMenu(menu_items)
    menu_items.kobo_banner_settings = {
        text = _("Banner Style"),
        sorting_hint = "tools", 
        callback = function()
            -- Launch a TouchMenu or MultiConfirmBox widget here
            -- to let the user pick "Floating Card", "Pill", "Full Width", etc.
        end
    }
end
```
Alternatively, instead of cluttering the top-level tools, we can hook into the existing **Settings → Screen → Sleep Screen** menu by monkey-patching `Screensaver:addToMainMenu` inside the `screensaver.koplugin` before it returns.

## 2. Different Styles of Boxes We Could Draw

Currently, the patch draws a **"Floating Card"** using a `FrameContainer` (for the box) and a nested `OverlapGroup` with an offset `FrameContainer` acting as a hard drop shadow. 

Here are other styles we could programmatically generate using KOReader's UI widgets:

1. **Full-Width Banner (The Original)**
   - **Composition:** `FrameContainer` spanning `screen_w`.
   - **Look:** Docks flush against the left and right edges (and usually top or bottom). No corner radius, no drop shadow. High contrast, maximum horizontal space for text.

2. **The Pill / Badge**
   - **Composition:** `FrameContainer` with `radius` set to a very high value (e.g., `radius = box_height / 2`).
   - **Look:** A heavily rounded horizontal lozenge. Looks great when placed in the exact center of the screen, floating.

3. **Outlined / Ghost Card**
   - **Composition:** `FrameContainer` with a thick `bordersize` (e.g. 3-5px) and a `background = COLOR_WHITE`, removing the drop shadow entirely.
   - **Look:** Clean, minimalistic, feels lighter on the page than a solid black box.

4. **Bracketed / Underlined**
   - **Composition:** Instead of a `FrameContainer`, use a `VerticalGroup` containing a `LineWidget` (top), a `HorizontalGroup` (for the text/content), and another `LineWidget` (bottom). 
   - **Look:** Classic bookish typography. No side borders, just elegant top/bottom rules. 

5. **Double Border / Inset**
   - **Composition:** A `FrameContainer` nested directly inside another `FrameContainer`, with 1-2px of `padding` between them.
   - **Look:** Creates a picture-frame / matboard effect around the text block.
