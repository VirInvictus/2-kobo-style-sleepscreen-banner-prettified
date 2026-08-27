# Patch Notes

## v2.1.0
*   **Selectable banner styles**: new `style` default in `B_SETT` plus a "Banner style" radio picker injected into Settings → Screen → Sleep screen. Five looks: floating card (as before), pill, full-width, outlined, and bracketed. The menu choice is saved in KOReader's settings and applies from the next sleep — no restart.
*   **No highlight, no section**: when a book has no eligible highlights (or the parser comes up empty), the highlight block — accent line, quote and footer — is skipped entirely instead of rendering an empty accent line with a blank space next to it.

## v2.0.3
*   **Dynamic Banner Expansion**: Added a dynamic width calculator that checks the length of the longest word in the title, stats, highlight, and footer. If a single word (like "Conversations") exceeds the configured default card width, the card will stretch up to the screen's edge to accommodate it rather than wrapping and breaking the word mid-way.

## v2.0.2
*   Crash guard when `uiman:show()` is called without a widget.

## v2.0.1 and older
*   Initial KOReader kobo-style lockscreen banner implementations and subsequent fixes.
