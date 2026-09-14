# CLAUDE.md: agent notes for this repo

Single-file KOReader user patch (`2-kobo-style-sleepscreen-banner.lua`) that
restyles the stock "banner" sleep-screen message. Targets LuaJIT (Lua 5.1
semantics), tab-indented, and deliberately one drop-in file.

## Non-negotiables (learned the hard way on a real Kindle)

- **FrameContainer's child is positional** (`self[1]`), never a named field.
  Passing `content_widget = x` silently yields a nil child and crashes
  `FrameContainer:getSize()` on device. Per-side padding (`padding_left`,
  `padding_right`, ...) IS honored by getSize/paintTo (v2026.07.1).
- **Menu items are gated by order tables.** KOReader merges `menu_items`
  with `reader_menu_order` / `filemanager_menu_order` via
  `MenuSorter:mergeAndSort` inside `setUpdateItemTable`; any key missing
  from the order is dropped silently. To add an entry: wrap
  `setUpdateItemTable`, insert the key into `order.setting` and set
  `self.menu_items[key]` BEFORE the original runs.
- **Never monkey-patch plugin modules**: KOReader `dofile`s plugin files,
  so a require'd copy isn't the live instance. Core `require`d modules
  (uimanager, readermenu, filemanagermenu, ui/font, fontlist) are safe.
- `Font:getFace(path, size)` accepts full paths; `fontlist.fontlist` is an
  array of discovered full paths. Resolve user picks by full path, config
  names by basename lookup against that list, fall back to `cfont`.
- KOReader's highlight drawer name is `strikeout`, never `strikethrough`
  (the v2.1.4 fix; `allowed_hl_styles` must key the real drawer names).
- Device-verified against the v2026.07.2 frontend sources (2026-09-14):
  `BookList.getDocSettings(nil)` is a hard error (`DocSettings:open`
  crashes in `getSidecarFilename`), so the patch skips the sidecar when
  `lastfile` is unset; the legal `screensaver_type` values for the banner
  are `cover` / `document_cover` (KOReader's "custom image or cover";
  the old `image_file` was migrated to it upstream in 2024-04) /
  `random_image`; the Strikethrough highlight menu item stores the drawer
  string `strikeout` (`readerhighlight.lua`).

## Device workflow (jailbroken Kindle PaperWhite 6, KOReader v2026.07.2)

- KOReader's built-in SSH server: port **2222**, user `root`, "no password"
  mode: an empty password is rejected but ANY non-empty string works
  (`sshpass -p mario` is the local convention). Host keys rotate per start:
  always pass `-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null`.
- The server has **no SFTP subsystem** → sshfs/rsync/scp will not work.
  Deploy over the exec channel, then compare md5 on both sides:
  `sshpass -p mario ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@IP 'cat > /mnt/us/koreader/patches/2-kobo-style-sleepscreen-banner.lua && chmod 777 /mnt/us/koreader/patches/2-kobo-style-sleepscreen-banner.lua' < 2-kobo-style-sleepscreen-banner.lua`
- KOReader must be fully restarted to (re)load patches; restarting kills the
  SSH server, so restarts happen on the device, not remotely.
- After any crash: `tail -120 /mnt/us/koreader/crash.log` and read
  `/mnt/us/koreader/VERSION` before guessing. Device frontend sources are
  readable under `/mnt/us/koreader/frontend/`; check them instead of
  trusting master.
- The user's `~/.zshrc` has mount-kindle/unmount-kindle aliases (KINDLE_IP
  may be stale); use them as a reference, never edit them.

## Testing

- `lua test/harness.lua`, then also `luajit test/harness.lua`: must be all
  green before any deploy. It stubs KOReader modules and asserts menu
  registration (order tables), style persistence, show() guards, per-style
  assembly and font resolution.
- Harness stubs MUST mirror real widget semantics (positional self[1]
  child, per-side padding, size aggregation). A stub that silently
  "fixes" wrong patch behavior will hide device crashes.
- Syntax gate: `luac -p 2-kobo-style-sleepscreen-banner.lua`.
- CI (`.github/workflows/harness.yml`) runs the suite under both
  interpreters on every push.

## Conventions

- Tabs; `snake_case` settings; user-facing strings wrapped in `_()`.
- Version bumps touch: the patch header comment (the single source for
  the version), `patchnotes.md`, the spec status line, and README where
  it mentions behavior.
- Docs travel with code: README.md (users), spec.md (behavior spec),
  patchnotes.md (history), CLAUDE.md (this file; AGENTS.md is a symlink to it).
- Commit + push after every verified on-device change.
