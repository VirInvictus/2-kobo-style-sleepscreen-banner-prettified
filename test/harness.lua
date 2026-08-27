-- Harness: runtime-test the sleepscreen banner patch outside KOReader.
-- Stubs every required module; widget classes implement real size
-- aggregation so the patch's assembly math can be asserted on.
--
-- usage: lua test/harness.lua   (from the repo root, or any cwd)

local PASS, FAIL = 0, 0
local function ok(cond, msg)
  if cond then PASS = PASS + 1 else FAIL = FAIL + 1; print("  FAIL: " .. msg) end
end

--------------------------------------------------------------------
-- fake widget classes
--------------------------------------------------------------------
local function mkclass(kind, getsize)
  local C = { _kind = kind }
  C.__index = C
  C.new = function(klass, props)
    local t = setmetatable({}, C)
    if props then for k, v in pairs(props) do rawset(t, k, v) end end
    t._kind = kind
    return t
  end
  C.getSize = getsize or function(self) return self.dimen or { w = 60, h = 20 } end
  C.free = function() end
  C.paintTo = function() end
  return C
end

local function sumChildren(self, horiz)
  local w, h = 0, 0
  for _, c in ipairs(self) do
    local cs = c.getSize and c:getSize() or { w = 0, h = 0 }
    if horiz then
      w = w + cs.w; h = math.max(h, cs.h)
    else
      h = h + cs.h; w = math.max(w, cs.w)
    end
  end
  return { w = w, h = h }
end

local TextWidget      = mkclass("textwidget", function(self) return { w = 8 * #(self.text or ""), h = 20 } end)
local TextBoxWidget   = mkclass("textboxwidget", function(self) return { w = self.width or (8 * #(self.text or "")), h = self.height or 40 } end)
local VerticalGroup   = mkclass("verticalgroup", function(self) return sumChildren(self, false) end)
local HorizontalGroup = mkclass("horizontalgroup", function(self) return sumChildren(self, true) end)
local VerticalSpan    = mkclass("verticalspan", function(self) return { w = 0, h = self.width or 0 } end)
local HorizontalSpan  = mkclass("horizontalspan", function(self) return { w = self.width or 0, h = 0 } end)
local FrameContainer  = mkclass("framecontainer", function(self)
  -- match the real widget: child is the positional self[1]
  local cs = self[1] and self[1]:getSize() or { w = 0, h = 0 }
  local pad = (self.padding or 0) + (self.bordersize or 0)
  return { w = cs.w + 2 * pad, h = cs.h + 2 * pad }
end)
local LeftContainer   = mkclass("leftcontainer", function(self) return { w = self.dimen.w, h = self.dimen.h } end)
local LineWidget      = mkclass("linewidget", function(self) return { w = self.dimen.w, h = self.dimen.h } end)
local OverlapGroup    = mkclass("overlapgroup", function(self)
  if self.dimen then return { w = self.dimen.w, h = self.dimen.h } end
  return sumChildren(self, false)
end)
local PlainWidget     = mkclass("widget", function(self) return self.dimen or { w = 0, h = 0 } end)
--------------------------------------------------------------------
-- fake sidecar / settings / ui manager
--------------------------------------------------------------------
local sidecar
sidecar = {
  flush = function() end,
  isTrue = function(_, _) return false end,
  readSetting = function(_, k)
    if k == "annotations" then return sidecar._annotations end
    if k == "doc_props" then return sidecar._props end
    return nil
  end,
  _annotations = {},
  _props = { title = "Test Book", authors = "An Author" },
}

local store = {
  screensaver_type = "cover",
  screensaver_show_message = true,
  screensaver_message_container = "banner",
  lastfile = "/books/test.epub",
}
local G_reader_settings = {
  readSetting = function(_, k) return store[k] end,
  saveSetting = function(_, k, v) store[k] = v end,
  delSetting = function(_, k) store[k] = nil end,
  isTrue = function(_, k) return store[k] == true end,
}

local UIManager = { passthrough = 0 }
UIManager.show = function(self, widget)
  UIManager.passthrough = UIManager.passthrough + 1
end

local readermenu_calls, fm_calls = 0, 0
local ReaderMenuStub = { setUpdateItemTable = function() readermenu_calls = readermenu_calls + 1 end }
local FileManagerMenuStub = { setUpdateItemTable = function() fm_calls = fm_calls + 1 end }

local ScreenStub = {
  getWidth = function() return 1000 end,
  getHeight = function() return 1400 end,
  scaleBySize = function(_, n) return n end,
}

_G._ = function(s) return s end
_G.G_reader_settings = G_reader_settings

local face_calls = {}

local bb = {
  COLOR_WHITE = "WHITE", COLOR_BLACK = "BLACK",
  COLOR_GRAY_4 = "GRAY4", COLOR_GRAY_9 = "GRAY9",
}
setmetatable(bb, { __index = function(_, k)
  if type(k) == "string" and k:match("^COLOR_GRAY_[1-9]$") then return k end
end })

local stubs = {
  ["ffi/blitbuffer"] = bb,
  ["apps/filemanager/filemanagerbookinfo"] = { expandString = function() return "Test Title" end },
  ["ui/widget/booklist"] = { getDocSettings = function() return sidecar end },
  ["datetime"] = { shortMonthTranslation = setmetatable({}, { __index = function(_, k) return k:lower() end }) },
  ["device"] = { screen = ScreenStub },
  ["ui/font"] = { getFace = function(self, font, size)
    face_calls[#face_calls + 1] = { font = font, size = size }
    return { stubface = true, name = font }
  end },
  ["fontlist"] = { fontlist = {
    "/mnt/us/koreader/fonts/relaxed-core-fonts/Libron_R-Bold.ttf",
    "/mnt/us/koreader/fonts/relaxed-core-fonts/Libron_R-Italic.ttf",
    "/mnt/us/koreader/fonts/relaxed-core-fonts/Libron_R-Regular.ttf",
    "/mnt/us/koreader/fonts/noto/NotoSans-Regular.ttf",
  } },
  ["ffi/util"] = { template = function(fmt, ...) local t = { ... } return (tostring(fmt):gsub("%%1", tostring(t[1] or ""))) end },
  ["ui/elements/reader_menu_order"] = { setting = { "screen", "status_bar" } },
  ["ui/elements/filemanager_menu_order"] = { setting = { "screensaver", "status_bar" } },
  ["ui/size"] = { padding = { large = 10 } },
  ["ui/geometry"] = { new = function(_, t) return t end },
  ["ui/uimanager"] = UIManager,
  ["util"] = {
    trim = function(s) if not s then return s end return ((s:gsub("^%s+", "")):gsub("%s+$", "")) end,
    splitToArray = function(str, sep)
      local out = {}
      if not str then return out end
      local i = 1
      while true do
        local s, e = str:find(sep, i)
        if not s then out[#out + 1] = str:sub(i) break end
        out[#out + 1] = str:sub(i, s - 1)
        i = e + 1
      end
      return out
    end,
    splitToChars = function(s)
      local t = {}
      for ch in s:gmatch("[\1-\127\192-\255][\128-\191]*") do t[#t + 1] = ch end
      return t
    end,
  },
  ["ui/widget/textwidget"] = TextWidget,
  ["ui/widget/textboxwidget"] = TextBoxWidget,
  ["ui/widget/verticalgroup"] = VerticalGroup,
  ["ui/widget/horizontalgroup"] = HorizontalGroup,
  ["ui/widget/verticalspan"] = VerticalSpan,
  ["ui/widget/horizontalspan"] = HorizontalSpan,
  ["ui/widget/container/framecontainer"] = FrameContainer,
  ["ui/widget/container/leftcontainer"] = LeftContainer,
  ["ui/widget/linewidget"] = LineWidget,
  ["ui/widget/overlapgroup"] = OverlapGroup,
  ["ui/widget/widget"] = PlainWidget,
  ["ui/widget/container/inputcontainer"] = mkclass("inputcontainer"),
  ["ui/widget/container/widgetcontainer"] = mkclass("widgetcontainer"),
  ["apps/reader/readerui"] = { instance = nil },
  ["apps/filemanager/filemanager"] = { instance = nil },
  ["apps/reader/modules/readermenu"] = ReaderMenuStub,
  ["apps/filemanager/filemanagermenu"] = FileManagerMenuStub,
}
for name, mod in pairs(stubs) do package.loaded[name] = mod end

local og_readermenu_set = ReaderMenuStub.setUpdateItemTable
local og_fm_set = FileManagerMenuStub.setUpdateItemTable
-- resolve the patch relative to this script (test/ -> repo root)
local here = arg[0]:match("^(.*)[/\\]") or "."
dofile(here .. "/../2-kobo-style-sleepscreen-banner.lua")
print("== T1: menu hooks installed ==")
ok(ReaderMenuStub.setUpdateItemTable ~= og_readermenu_set, "readermenu.setUpdateItemTable wrapped")
ok(FileManagerMenuStub.setUpdateItemTable ~= og_fm_set, "filemanagermenu.setUpdateItemTable wrapped")

print("== T2: banner menu registered via order tables ==")
local reader_order = stubs["ui/elements/reader_menu_order"]
local fm_order = stubs["ui/elements/filemanager_menu_order"]
local mi = { menu_items = {} }
ReaderMenuStub.setUpdateItemTable(mi)
ok(mi.menu_items.banner_style ~= nil, "banner_style present in menu_items")
local ord = reader_order.setting
ok(ord[#ord] == "banner_style", "order.setting ends with banner_style")
ok(ord[#ord - 1] == "----------------------------", "separator before banner_style")
ReaderMenuStub.setUpdateItemTable(mi)
local count = 0
for _, k in ipairs(ord) do if k == "banner_style" then count = count + 1 end end
ok(count == 1, "no duplicate order entries on rebuild")
local mi2 = { menu_items = {} }
FileManagerMenuStub.setUpdateItemTable(mi2)
ok(mi2.menu_items.banner_style ~= nil, "FM build also registers banner_style")
ok(fm_order.setting[#fm_order.setting] == "banner_style", "FM order patched too")

local bs = mi.menu_items.banner_style
ok(bs.text == "Banner style", "entry text")
local sub = bs.sub_item_table
ok(sub[1] and sub[1].text == "Message style" and #sub[1].sub_item_table == 5, "Message style: 5 radios")
ok(sub[2] and sub[2].text == "Fonts" and #sub[2].sub_item_table == 4, "Fonts: 4 roles")

local radios = {}
for _, it in ipairs(sub[1].sub_item_table) do radios[it.text] = it end
ok(radios["Floating card"].checked_func() == true, "default style floating_card (B_SETT.style)")
radios["Pill"].callback()
ok(store.screensaver_banner_style == "pill", "style callback persists")
ok(radios["Pill"].checked_func() == true, "checked_func follows persisted choice")
store.screensaver_banner_style = nil

local role = sub[2].sub_item_table[1] -- Title font
local list = role.sub_item_table_func()
ok(#list == 5, "font list = Default + 4 discovered fonts")
ok(list[1].checked_func() == true, "Default checked when nothing persisted")
local libron_path = "/mnt/us/koreader/fonts/relaxed-core-fonts/Libron_R-Bold.ttf"
ok(list[2].text == "Libron_R-Bold.ttf" and list[2].checked_func() == false, "unpicked font unchecked")
list[2].callback()
ok(store.screensaver_banner_title_font == libron_path, "font pick persists full path")
ok(list[2].checked_func() == true and not list[1].checked_func(), "checked state follows pick")
ok(tostring(role.text_func()):find("Libron_R%-Bold") ~= nil, "role label shows picked font")
list[1].callback()
ok(store.screensaver_banner_title_font == nil, "Default entry clears the pick")

print("== T3: show() guards pass through untouched widgets ==")
UIManager.passthrough = 0
UIManager:show(nil)
ok(UIManager.passthrough == 1, "nil widget passes through")
UIManager:show({ name = "NotAScreensaver" })
ok(UIManager.passthrough == 2, "non-screensaver widget passes through")
local w_wrong = { { { { {} }, { widget = { text = "x", free = function() end } } } }, name = "ScreenSaver" }
store.screensaver_message_container = "box"
UIManager:show(w_wrong)
ok(UIManager.passthrough == 3, "non-banner container passes through")
store.screensaver_message_container = "banner"
print("== T4: assembly per style ==")

local function makeWidget(text)
  local textbox = { text = text or "page 1 of 400", free = function() end }
  local cuspos = { widget = textbox }
  local overlap = { { cover = true }, cuspos }
  local widget = { { overlap }, name = "ScreenSaver" }
  return widget, cuspos
end

-- walk: cuspos.widget -> HorizontalGroup(margin span, VerticalGroup(margin span, card_layer))
local function getCardLayer(cuspos)
  local outer = cuspos.widget
  local vg = outer[2]
  return vg[2], vg
end

local function runStyle(style, with_hl)
  store.screensaver_banner_style = style
  sidecar._annotations = with_hl and {
    { text = "A memorable quote", drawer = "underscore", datetime = "2025-08-01 12:30", pageno = 42, chapter = "Chapter 1" },
  } or {}
  local widget, cuspos = makeWidget()
  UIManager.passthrough = 0
  UIManager:show(widget)
  assert(UIManager.passthrough == 1, "patch swallowed the show call for " .. style)
  return cuspos
end

-- floating_card
do
  print("  -- floating_card")
  local cuspos = runStyle("floating_card", true)
  ok(cuspos.horizontal_position == 0, "custom position pinned left")
  local layer = getCardLayer(cuspos)
  ok(layer._kind == "overlapgroup", "drop shadow overlap group present")
  local card = layer[2]
  ok(card._kind == "framecontainer", "framed card")
  ok(layer.dimen.w == card:getSize().w + 6 and layer.dimen.h == card:getSize().h + 6, "shadow offset 6px peek")
  ok(card.radius == 8, "floating card radius from B_SETT (8)")
  ok(card[1]._kind == "verticalgroup", "content is a vertical group")
  ok(#card[1] == 4, "title+stats+span+highlight (4 children)")
  ok(card:getSize().w <= 1000, "card fits the screen")
end

-- pill
do
  print("  -- pill")
  local cuspos = runStyle("pill", true)
  local layer = getCardLayer(cuspos)
  ok(layer._kind == "overlapgroup", "pill keeps its shadow")
  local card = layer[2]
  local expected = math.floor(card:getSize().h / 2)
  ok(card.radius == expected and expected > 0, "pill radius = height/2 (" .. tostring(card.radius) .. ")")
  ok(layer[1][2][2]._kind == "framecontainer", "shadow box is framed")
  ok(layer[1][2][2].radius == expected, "shadow follows the pill radius")
end

-- full_width
do
  print("  -- full_width")
  local cuspos = runStyle("full_width", true)
  local layer = getCardLayer(cuspos)
  ok(layer._kind == "framecontainer", "no shadow layer for full width")
  ok(layer:getSize().w == 1000, "card spans exactly screen_w (got " .. tostring(layer:getSize().w) .. ")")
  ok(layer.radius == 0, "square corners")
  local inner = layer[1]
  ok(inner._kind == "leftcontainer", "content stretched via LeftContainer")
  ok(inner.dimen.w == 1000 - 2 * (15 + 1), "inner width = screen_w minus chrome")
end

-- outlined
do
  print("  -- outlined")
  local cuspos = runStyle("outlined", true)
  local layer = getCardLayer(cuspos)
  ok(layer._kind == "framecontainer", "no shadow layer for outlined")
  ok(layer.bordersize == 3, "thick 3px border")
  ok(layer.radius == 8, "keeps rounded corners")
end

-- bracketed
do
  print("  -- bracketed")
  local cuspos = runStyle("bracketed", true)
  local layer = getCardLayer(cuspos)
  ok(layer._kind == "verticalgroup", "bracketed replaces the frame with a vertical group")
  ok(#layer == 5, "rule, gap, content, gap, rule")
  ok(layer[1]._kind == "linewidget" and layer[5]._kind == "linewidget", "top+bottom rules")
  ok(layer[3]._kind == "verticalgroup", "content between the rules")
  ok(layer[1]:getSize().w == layer[3]:getSize().w, "rules span the content width")
  ok(layer[1]:getSize().h == 2 and layer[2].width == 8, "2px rules with 8px gap")
end

print("== T5: highlight handling (phase 2) ==")
do
  store.screensaver_banner_style = "floating_card"
  sidecar._annotations = {}
  local w, cp = makeWidget()
  UIManager:show(w)
  ok(#cp.widget[2][2][2][1] == 2, "no highlight section when book has none")
  sidecar._annotations = { { text = "   ", drawer = "underscore" } }
  w, cp = makeWidget()
  UIManager:show(w)
  ok(#cp.widget[2][2][2][1] == 2, "empty-text highlight skipped")
end

print("== T6: font resolution at draw time ==")
do
  store.screensaver_banner_style = "floating_card"
  sidecar._annotations = {}
  local w = makeWidget()
  UIManager:show(w)
  local function used(font)
    for i = #face_calls, 1, -1 do
      if face_calls[i].font == font then return true end
    end
    return false
  end
  ok(used("/mnt/us/koreader/fonts/relaxed-core-fonts/Libron_R-Bold.ttf"), "title resolved to discovered Libron_R-Bold.ttf path")
  ok(used("cfont"), "stats falls back to cfont alias")
  ok(used("/mnt/us/koreader/fonts/relaxed-core-fonts/Libron_R-Regular.ttf"), "footer resolved to discovered Libron_R-Regular.ttf path")
  ok(used("/mnt/us/koreader/fonts/relaxed-core-fonts/Libron_R-Italic.ttf"), "highlight resolved to discovered Libron_R-Italic.ttf path")
  store.screensaver_banner_title_font = "/mnt/us/koreader/fonts/noto/NotoSans-Regular.ttf"
  face_calls = {}
  w = makeWidget()
  UIManager:show(w)
  ok(used("/mnt/us/koreader/fonts/noto/NotoSans-Regular.ttf"), "persisted font pick wins over B_SETT default")
  store.screensaver_banner_title_font = nil
end

print(string.format("\n%d passed, %d failed", PASS, FAIL))
os.exit(FAIL == 0 and 0 or 1)
