# Patch Notes

## v2.1.2
*   **Pill**: the ends now get extra side padding — up to the cap radius, as far as the screen allows — so the text sits on the straight section of the lozenge and is always fully backed, never spilling onto the curves.
*   **Bracketed redesigned into "Flat box"**: the rules-on-the-cover look is gone. It's now a plain solid backing behind the text — no border, no rounded corners, no shadow — so author names and quotes stay readable (settings id unchanged).
*   **Outlined**: border thickened 3 px → 5 px.

## v2.1.1
*   **Fixed: missing "Banner style" menu entry.** KOReader's MenuSorter drops any top-level item that isn't listed in its order tables; the entry is now registered there before the menu is assembled, the same way the ui-font patch does it.
*   **Banner fonts are now menu-selectable** under Banner style → Fonts (title / stats / highlight / footer), picked from every font file KOReader can see, rendered in their own font in the picker, with a per-role "back to config default" entry. No more hard-coded font filenames.
*   **Font finder fixed**: resolution now matches by file name against everything KOReader discovered (any subdirectory of `koreader/fonts/`), so collection layouts like `relaxed-core-fonts/Libron_R-Bold.ttf` resolve properly; unresolvable fonts fall back to the KOReader UI font instead of erroring.
*   Default font filenames updated to the ebook-fonts collection's real names (`Libron_R-Bold.ttf`, `Libron_R-Italic.ttf`, `Libron_R-Regular.ttf`).


## v2.1.0
*   **Selectable banner styles**: new `style` default in `B_SETT` plus a "Banner style" radio picker injected into Settings → Screen → Sleep screen. Five looks: floating card (as before), pill, full-width, outlined, and bracketed. The menu choice is saved in KOReader's settings and applies from the next sleep — no restart.
*   **No highlight, no section**: when a book has no eligible highlights (or the parser comes up empty), the highlight block — accent line, quote and footer — is skipped entirely instead of rendering an empty accent line with a blank space next to it.

## v2.0.3
*   **Dynamic Banner Expansion**: Added a dynamic width calculator that checks the length of the longest word in the title, stats, highlight, and footer. If a single word (like "Conversations") exceeds the configured default card width, the card will stretch up to the screen's edge to accommodate it rather than wrapping and breaking the word mid-way.

## v2.0.2
*   Crash guard when `uiman:show()` is called without a widget.

## v2.0.1 and older
*   Initial KOReader kobo-style lockscreen banner implementations and subsequent fixes.
