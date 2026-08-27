--[[ 2-kobo-style-sleepscreen-banner.lua ]]
--redesigns the inbuilt 'banner' type sleep screen message to
--make it look like the kobo lockscreen tag.

--[ v2.1.0 ]
--selectable banner styles: floating card (classic), pill, full width,
--outlined and bracketed. pick one under Settings > Screen > Sleep Screen
--> Banner style (applies from the next sleep, no restart needed), or set
--a default with the new 'style' key in B_SETT below.
--a book with no highlights now skips the highlight section entirely

--CREDITS
--this version was written in collab with discord user @sandcastles.
--i've also borrowed some design cues from a similar patch written by reddit user u/juancoquet.

local B_SETT = {	--BANNER SETTINGS
					style = "floating_card",	--default banner style until
												--changed in the sleep screen
												--menu. one of: "floating_card",
												--"pill", "full_width",
												--"outlined", "bracketed"
					title_text = "%T", 	--configure title_text like you'd configure the inbuilt 
										--sleep screen message. for eg, "%T" shows book title,
										--"page %c of %t" shows 'page 1 of 400' etc.
					title_fontFace = "Libron-Bold.ttf",
					title_fontSize = 30,
					stats_fontFace = "cfont",
					stats_fontSize = 17,
					border_size = 1,
					border_color = 0,	-- 0 = white, 1 = black						
					background = 0,		-- 0 = white, 1 = black
					margin = 10,
					padding = 15,	
					max_height = 50,		-- percentage of screen height
					max_width_hl_off = 40,	-- width when highlight off, min: 20
					max_width_hl_on = 60,  	-- width when highlight on, min: 20
					corner_radius = 8,		-- px, rounded card corners. 0 = square.
					shadow_enabled = true,	-- floating drop shadow behind the card
					shadow_offset = 6,		-- px, how far the shadow peeks down-right
					shadow_gray_level = 5,	-- COLOR_GRAY level, 1 = dark ... 9 = light
}
local HL_SETT = {	--HIGHLIGHT SETTINGS
					showRandomHighlight = true, 
					highlight_fontFace = "Libron-Italic.ttf",
					highlight_fontSize = 16,
					justify = true,
					add_quotations = true,
					show_accent_line = true,					
					showHighlightFooter = true,
					hl_footer_fontFace = "Libron-Regular.ttf",
					hl_footer_fontSize = 15,
					hl_footer_text = "saved on %DT at %HM", 	
										-- %DT = date, 
										-- %HM = time,
										-- %PG = page, 
										-- %C = chapter,
										-- %A = author, 
										-- %T = title, 
										-- \n = line break
												
					allowed_hl_styles = { 	-- only 'true' styles will be shown
									lighten = true,
									underscore = true,
									strikethrough = false,
									invert = false,
					}
}

local Bb = require("ffi/blitbuffer")
local BookInfo = require("apps/filemanager/filemanagerbookinfo")
local BookList = require("ui/widget/booklist")
local datetime = require("datetime")  
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local Widget = require("ui/widget/widget")
local Screen = Device.screen
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local util = require("util")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local screen_w, screen_h = Screen:getWidth(), Screen:getHeight()
local cached_random_highlight_index  = 1
local Sidecar

--==================================================================
-- BANNER STYLES (v2.1.0)
-- Each style is a set of chrome parameters used when the card is
-- assembled at the bottom of UIManager:show. The user's pick (made
-- in Settings > Screen > Sleep Screen > Banner style) is stored in
-- G_reader_settings and wins over B_SETT.style.
--==================================================================
local _ = _ or function(str) return str end

local STYLE_DEFS = {
	floating_card = {		-- the classic prettified look
			frame = true,
			shadow = B_SETT.shadow_enabled,
			padding = B_SETT.padding or 15,
			margin = B_SETT.margin or 10,
			border_size = B_SETT.border_size or 1,
			radius = B_SETT.corner_radius or 0,
	},
	pill = {				-- fully rounded lozenge
			frame = true,
			shadow = B_SETT.shadow_enabled,
			padding = B_SETT.padding or 15,
			margin = B_SETT.margin or 10,
			border_size = B_SETT.border_size or 1,
			radius_from_height = true,	-- radius = card height / 2
	},
	full_width = {			-- classic edge-to-edge banner
			frame = true,
			span_screen = true,			-- stretch the card across screen_w
			shadow = false,
			padding = B_SETT.padding or 15,
			margin = 0,					-- flush against the screen edges
			border_size = B_SETT.border_size or 1,
			radius = 0,
	},
	outlined = {			-- ghost card, no shadow
			frame = true,
			shadow = false,
			padding = B_SETT.padding or 15,
			margin = B_SETT.margin or 10,
			border_size = 3,			-- thick border
			radius = B_SETT.corner_radius or 0,
	},
	bracketed = {			-- typographic rules, no card at all
			frame = false,
			shadow = false,
			padding = 0,
			margin = B_SETT.margin or 10,
			border_size = 0,
			radius = 0,
	},
}

local BANNER_STYLE_ITEMS = {
	{ id = "floating_card",	text = _("Floating card"),	help_text = _("Rounded card with a hard offset drop shadow (default).") },
	{ id = "pill",			text = _("Pill"),			help_text = _("Fully rounded lozenge floating over the cover.") },
	{ id = "full_width",	text = _("Full width"),		help_text = _("Classic banner spanning the whole screen, flush against the edges, no shadow.") },
	{ id = "outlined",		text = _("Outlined"),		help_text = _("Minimal ghost card: thick border, no drop shadow.") },
	{ id = "bracketed",		text = _("Bracketed"),		help_text = _("Typographic rules above and below the text instead of a card.") },
}

local function getBannerStyle()
	-- menu choice first, then the B_SETT default, then floating card
	local style = G_reader_settings:readSetting("screensaver_banner_style")
	if not STYLE_DEFS[style] then
		style = B_SETT.style
	end
	if not STYLE_DEFS[style] then
		style = "floating_card"
	end
	return style
end

--------------------------------------------------------------------
-- Settings menu integration. The stock "Sleep screen" submenu is
-- rebuilt by KOReader every time the menu opens (the menu modules
-- dofile an elements table), so we wrap setUpdateItemTable on both
-- menu modules and slip a "Banner style" picker into the fresh
-- table on each build. Unlike plugins, these modules are loaded
-- via require, so a monkey-patch reliably sticks.
--------------------------------------------------------------------
local function injectBannerStyleEntry(menu_items)
	local sleep_entry = menu_items and (menu_items.screensaver or menu_items.screen_saver)
	local sub_item_table = sleep_entry and sleep_entry.sub_item_table
	if not sub_item_table or sub_item_table.banner_style_entry then
		return
	end
	local style_items = {}
	for _, item in ipairs(BANNER_STYLE_ITEMS) do
		table.insert(style_items, {
				text = item.text,
				help_text = item.help_text,
				checked_func = function()
					return getBannerStyle() == item.id
				end,
				callback = function()
					G_reader_settings:saveSetting("screensaver_banner_style", item.id)
				end,
				radio = true,
		})
	end
	local banner_style_entry = {
			text = _("Banner style"),
			help_text = _("Look of the message banner drawn over the sleep screen wallpaper."),
			sub_item_table = style_items,
	}
	-- place right after the "Sleep screen message" section when found
	local at
	for idx, entry in ipairs(sub_item_table) do
		if entry.text == _("Sleep screen message") then
			at = idx + 1
			break
		end
	end
	if at then
		table.insert(sub_item_table, at, banner_style_entry)
	else
		table.insert(sub_item_table, banner_style_entry)
	end
	sub_item_table.banner_style_entry = true
end

local function hookSleepScreenMenu(module_path)
	pcall(function()
		local menu_module = require(module_path)
		if not menu_module or not menu_module.setUpdateItemTable then
			return
		end
		local og_setUpdateItemTable = menu_module.setUpdateItemTable
		menu_module.setUpdateItemTable = function(self, ...)
			og_setUpdateItemTable(self, ...)
			pcall(injectBannerStyleEntry, self.menu_items)
		end
	end)
end

hookSleepScreenMenu("apps/reader/modules/readermenu")
hookSleepScreenMenu("apps/filemanager/filemanagermenu")

local function buildTextField(
								text, 
								font_face, 
								max_height, 
								max_wid, 
								ignoreLineBreaks, 
								isHighlight, 
								text_color
							)
	local wgt_grp = VerticalGroup:new{align = "left"}
	text = text:gsub("\\n", "\n")
	local segments = ignoreLineBreaks and {text} or util.splitToArray(text, "\n")
	for idx, item in ipairs(segments) do 
		local wgt = TextWidget:new{
						padding = 0,
						text = item,
						face = font_face,
						alignment = "left",
						fgcolor = text_color and text_color or 
									B_SETT.background == 1 and Bb.COLOR_WHITE or 
									Bb.COLOR_BLACK,
						bgcolor = B_SETT.background == 0 and Bb.COLOR_WHITE or 
									Bb.COLOR_BLACK,
		}
		if wgt:getSize().w > max_wid then 
			wgt:free()
			wgt = TextBoxWidget:new{
						text = item,
						face = font_face,
						width = max_wid,
						alignment = "left",
						height = max_height,
						height_adjust = true,
						height_overflow_show_ellipsis = true,
						justified = isHighlight and HL_SETT.justify,
						fgcolor = text_color and text_color or 
									B_SETT.background == 1 and Bb.COLOR_WHITE or 
									Bb.COLOR_BLACK,
						bgcolor = B_SETT.background == 0 and Bb.COLOR_WHITE or 
									Bb.COLOR_BLACK,
			}			
		end		
		table.insert(wgt_grp, wgt)
	end
	return wgt_grp
end

local function addQuotesIfReq(text)
	if not text or text == "" then
		return text
	end
	local chars = util.splitToChars(text)  
	local first_char = chars[1]   
	local last_char = chars[#chars]
	local control = { {"'", "'"}, {"\"", "\""}, {"“", "”"}, 
						{"‘", "’"}, {"«", "»"}, {"„", "“"} }
	local quotesFound = false
	for _, quotes in ipairs(control) do 
		if first_char == quotes[1] and last_char == quotes[2] then 
			quotesFound = true
			break
		end
	end
	if not quotesFound then 
		return "“" .. text .. "”"
	end
	return text
end

local function parseFooterText(text, index)
	if not text or not index or text == "" then 
		return text, index 
	end
	
	local hl_time, hl_date, hl_chapter = "", "", ""
	local hl_pageno, bk_author, bk_title = 0, "", ""
	
	local hl_array = Sidecar and Sidecar:readSetting("annotations")
	hl_array = hl_array and hl_array[index] or {}
	hl_chapter = hl_array.chapter or "N/A"
	hl_pageno = Sidecar:isTrue("pagemap_use_page_labels") and hl_array.pageref or 
				hl_array.pageno or "N/A"
				
	local doc_props = Sidecar and Sidecar:readSetting("doc_props") or {}
	bk_author = doc_props.authors or "N/A"
	bk_title = doc_props.title or "N/A"
	
	--date and time
	local yr, mth, dy
	local date_and_time = hl_array.datetime and 
							util.splitToArray(hl_array.datetime, "%s+", false) or {}
	
	hl_date = date_and_time and date_and_time[1] or ""
	yr, mth, dy = hl_date:match("(%d+)-(%d+)-(%d+)")  
	local month_abbr = yr and mth and dy and 
						os.date("%b", os.time{year=yr, month=mth, day=dy}) or ""
	local short_month = datetime.shortMonthTranslation[month_abbr]  or ""
	hl_date = yr and mth and dy and short_month and 
				string.format("%s %s '%02d", dy, short_month, tonumber(yr) % 100) or "N/A"
	
	local timesplit = date_and_time and date_and_time[2] and 
					  util.splitToArray(date_and_time[2], ":") or {}
	hl_time = timesplit and timesplit[1] and timesplit[2] and 
			  timesplit[1]..":"..timesplit[2] or "N/A"
	
	local sub_table = {
		["%%HM"] = hl_time,
		["%%DT"] = hl_date,
		["%%PG"] = hl_pageno,
		["%%C"] = hl_chapter,
		["%%A"] = bk_author,
		["%%T"] = bk_title
	}	
	for pattern, replacement in pairs(sub_table) do
		if replacement then 
			text = string.gsub(text, pattern, replacement)
		end
	end
	return text	
end

local function getMaxWordWidth(text, font_face)
	local max_w = 0
	if not text or text == "" then return max_w end
	text = text:gsub("\\n", "\n")
	for word in text:gmatch("%S+") do
		local wgt = TextWidget:new{
			padding = 0,
			text = word,
			face = font_face,
		}
		local w = wgt:getSize().w
		if w > max_w then max_w = w end
		wgt:free()
	end
	return max_w
end

local og_uiMan_show = UIManager.show

function UIManager:show(widget, ...)
	-- if widget isn't 'screensaver' or if wallpaper type
	-- isn't 'book cover' or 'custom image' or if sleep screen message type
	-- isn't 'banner', we do not intercept. 
	
	if not widget or widget.name ~= "ScreenSaver" then 
		return og_uiMan_show(self, widget, ...)
	end
	
	local screensaver_type = G_reader_settings:readSetting("screensaver_type")
	local message_container_enabled = G_reader_settings:isTrue("screensaver_show_message")
	local message_container_type = G_reader_settings:readSetting("screensaver_message_container")
	
	if not message_container_enabled or 
			message_container_type ~= "banner" then 
		return og_uiMan_show(self, widget, ...)
	end
	if screensaver_type ~= "cover" and 
			screensaver_type ~= "random_image" and 
			screensaver_type ~= "document_cover" then			
		return og_uiMan_show(self, widget, ...)
	end		
	
	local txtBoxWgtFound = widget and 
								widget[1] and  --screensaver wgt
								widget[1][1] and  -- overlap group
								widget[1][1][2] and --custom pos. container
								widget[1][1][2].widget and --textbox widget
								widget[1][1][2].widget.text
	if not txtBoxWgtFound then 
		return og_uiMan_show(self, widget, ...)
	end
	--=================================
	
	local last_file = G_reader_settings:readSetting("lastfile")
	Sidecar = BookList.getDocSettings(last_file)
	self.ui = require("apps/reader/readerui").instance or 
				require("apps/filemanager/filemanager").instance
	Sidecar:flush()
	
	--dimen roundup. the active banner style resolves the card chrome
	--(padding, margin, border, radius) before anything is laid out.
	local style = STYLE_DEFS[getBannerStyle()]
	
	local dimen_ = {
			padding = style.frame and Screen:scaleBySize(style.padding) or 0,
			margin = Screen:scaleBySize(style.margin),
			border_size = style.frame and Screen:scaleBySize(style.border_size) or 0,
			line_width = Screen:scaleBySize(1),
			line_clearance = Size.padding.large,
			hl_wgt_clearance = Screen:scaleBySize(15),
			footer_clearance = Screen:scaleBySize(5),
			corner_radius = style.radius and
							Screen:scaleBySize(style.radius) or 0,
			shadow_offset = B_SETT.shadow_offset and
							Screen:scaleBySize(B_SETT.shadow_offset) or
							Screen:scaleBySize(6),
			rule_width = Screen:scaleBySize(2),	--bracketed style rules
			rule_gap = Screen:scaleBySize(8),	--bracketed style text gap
	}
	
	--vertical/horizontal chrome the style wraps around the text, used
	--to keep the card within the configured max width and height
	local chrome_v, chrome_h
	if style.frame then
		chrome_v = dimen_.padding + dimen_.margin + dimen_.border_size
		chrome_h = chrome_v
	else
		chrome_v = dimen_.margin + dimen_.rule_gap + dimen_.rule_width
		chrome_h = dimen_.margin
	end
	
	local overflow_h = chrome_v * 2 +
							dimen_.hl_wgt_clearance
	local overflow_w = chrome_h * 2
	local overflow_w_hl = HL_SETT.show_accent_line and
							(overflow_w + dimen_.line_clearance + dimen_.line_width) or
							overflow_w
	
	--font roundup
	local font_ = {
		title_font = Font:getFace(
						B_SETT.title_fontFace, 
						B_SETT.title_fontSize) or 
						Font:getFace("cfont", 30),
		stats_font = Font:getFace(
						B_SETT.stats_fontFace, 
						B_SETT.stats_fontSize) or 
						Font:getFace("cfont", 17),
		footer_font = Font:getFace(
						HL_SETT.hl_footer_fontFace, 
						HL_SETT.hl_footer_fontSize) or 
						Font:getFace("NotoSerif-Regular.ttf", 15),
		highlight_font = Font:getFace(
						HL_SETT.highlight_fontFace, 
						HL_SETT.highlight_fontSize) or 
						Font:getFace("NotoSerif-Italic.ttf", 16)					
	}	
	
	--intercept the custom position container and child.
	
	local cus_pos_container, orig_sleep_widget, content_widget
	
	cus_pos_container = widget[1][1][2]
	orig_sleep_widget = widget[1][1][2].widget
	local orig_sleep_text = orig_sleep_widget.text
	orig_sleep_widget:free()
	
	local highlightCount, highlightEnabled, highlights_list
	
	if HL_SETT.showRandomHighlight then
		local all_annotations = Sidecar:readSetting("annotations") or {}
		highlights_list = {}

		local allowed = HL_SETT.allowed_hl_styles

		for _, item in ipairs(all_annotations) do
			if item.text
			   and item.drawer
			   and allowed[item.drawer] then
				local trimmed = util.trim(item.text)
				if trimmed ~= "" then
					table.insert(highlights_list, item)
				end
			end
		end

		highlightCount = #highlights_list
		highlightEnabled = highlightCount > 0
	end
	
	local hl_footer_enabled = highlightEnabled and 
								HL_SETT.showHighlightFooter and 
								HL_SETT.hl_footer_text and 
								util.trim(HL_SETT.hl_footer_text) ~= ""
	
	-- Pre-calculate texts to expand max_wid if a word is too long
	local title_text
	
	if self.ui and self.ui.document and self.ui.toc and self.ui.bookinfo then
		title_text = self.ui and self.ui.bookinfo:expandString(B_SETT.title_text, last_file) or "N/A"
	else
		title_text = BookInfo:expandString(B_SETT.title_text, last_file) or "N/A"
	end
	
	local random_highlight, random_highlight_index, footer_text_parsed
	if highlightEnabled then 
		if highlightCount == 1 then
			random_highlight = highlights_list and highlights_list[1] and highlights_list[1].text or ""
			random_highlight_index = 1
		else
			random_highlight_index = math.random(highlightCount)
			while random_highlight_index == cached_random_highlight_index do 
				random_highlight_index = math.random(highlightCount)
			end
			cached_random_highlight_index = random_highlight_index
			random_highlight = highlights_list[random_highlight_index] and highlights_list[random_highlight_index].text or ""
		end
		
		random_highlight = util.trim(random_highlight)
		random_highlight = HL_SETT.add_quotations and addQuotesIfReq(random_highlight) or random_highlight
		
		if hl_footer_enabled then
			footer_text_parsed = parseFooterText(HL_SETT.hl_footer_text, random_highlight_index)
		end
	end

	local max_wid
	if style.span_screen then
		--full-width style: the card stretches across the screen anyway,
		--so let the text use all the room the chrome leaves over
		max_wid = highlightEnabled and
					(screen_w - overflow_w_hl) or
					(screen_w - overflow_w)
	elseif not highlightEnabled then
		max_wid = B_SETT.max_width_hl_off and
					B_SETT.max_width_hl_off >= 20 and 
					B_SETT.max_width_hl_off <= 100 and
					(B_SETT.max_width_hl_off/100 * screen_w) or 
					screen_w * 0.4
		max_wid = max_wid - overflow_w
	else
		max_wid = B_SETT.max_width_hl_on and
					B_SETT.max_width_hl_on >= 20 and 
					B_SETT.max_width_hl_on <= 100 and 
					(B_SETT.max_width_hl_on/100 * screen_w) or 
					screen_w * 0.6
		max_wid = max_wid - overflow_w_hl
	end
	
	-- Expand max_wid if any word is longer than the configured width
	max_wid = math.max(max_wid, getMaxWordWidth(title_text, font_.title_font))
	max_wid = math.max(max_wid, getMaxWordWidth(orig_sleep_text, font_.stats_font))
	if highlightEnabled then
		max_wid = math.max(max_wid, getMaxWordWidth(random_highlight, font_.highlight_font))
		if hl_footer_enabled and footer_text_parsed then
			max_wid = math.max(max_wid, getMaxWordWidth(footer_text_parsed, font_.footer_font) + getMaxWordWidth("— ", font_.footer_font))
		end
	end
	
	-- Ensure max_wid doesn't exceed screen width (minus overflow padding)
	local absolute_max = highlightEnabled and (screen_w - overflow_w_hl) or (screen_w - overflow_w)
	max_wid = math.min(max_wid, absolute_max)
	
	local max_height = B_SETT.max_height >= 20 and
						B_SETT.max_height <= 100 and
						(B_SETT.max_height/100 * screen_h) or 
						screen_h * 0.5
	max_height = max_height - overflow_h							
	
	--TITLE WIDGET
	local title_widget = buildTextField(
							title_text, 
							font_.title_font, 
							max_height, 
							max_wid, 
							true
	)
	local title_dimen = title_widget:getSize()					
	
	--STATS WIDGET
	local stats_widget = buildTextField(
							orig_sleep_text, 
							font_.stats_font, 
							max_height - title_dimen.h, 
							max_wid
	)
	local stats_dimen = stats_widget:getSize()
	
	--HIGHLIGHTS WIDGET
	local highlight_widget
	
	--phase 2: if the parser came up empty (book has no highlights, or
	--an empty string slipped through), skip the highlight section
	--entirely instead of rendering an empty accent line with a blank
	--space next to it.
	if highlightEnabled and random_highlight and random_highlight ~= "" then 
		local hl_footer_widget
		local footer_color = B_SETT.background == 0 and 
								Bb.COLOR_GRAY_4 or 
								Bb.COLOR_GRAY_9
		
		if hl_footer_enabled then
			local hyphen_wid = buildTextField(
									"— ", 
									font_.footer_font,
									max_height, 
									max_wid, 
									true, 
									false, 
									footer_color
			)						
			hl_footer_widget = buildTextField(
									footer_text_parsed, 
									font_.footer_font, 
									max_height - title_dimen.h - stats_dimen.h, 
									max_wid - hyphen_wid:getSize().w, 
									false, 
									false, 
									footer_color
			)						
			hl_footer_widget = HorizontalGroup:new{
									align = "top",
									hyphen_wid,
									hl_footer_widget
			}
			hl_footer_widget = VerticalGroup:new{
								VerticalSpan:new{width = dimen_.footer_clearance},
								hl_footer_widget,
			}
		end
		
		local hl_wgt_max_h = hl_footer_enabled and hl_footer_widget and 
						(max_height - title_dimen.h - stats_dimen.h - hl_footer_widget:getSize().h) or 
						(max_height - title_dimen.h - stats_dimen.h)
		highlight_widget = buildTextField(
								random_highlight, 
								font_.highlight_font, 
								hl_wgt_max_h, 
								max_wid,
								true, 
								true
		)								
		local accent_height = highlight_widget:getSize().h
		
		if HL_SETT.show_accent_line then 			
			local highlight_accent = LineWidget:new{  
									background = footer_color,   
									dimen =  Geom:new{  
										w = dimen_.line_width,   
										h = accent_height, 
									},  
			}
			highlight_widget = HorizontalGroup:new{
				align = "top",
				highlight_accent,
				HorizontalSpan:new{width = dimen_.line_clearance},
				highlight_widget,
			}
		end
			
		if hl_footer_enabled and hl_footer_widget then
			highlight_widget = VerticalGroup:new{
					align = "left",
					highlight_widget,
					hl_footer_widget,
			}
		end
	end

	content_widget = VerticalGroup:new{
		align = "left",
		title_widget,
		stats_widget,			
	}
	
	if highlightEnabled and highlight_widget then
		table.insert(content_widget, VerticalSpan:new{width = dimen_.hl_wgt_clearance})
		table.insert(content_widget, highlight_widget)
	end
	
	-- the card itself. the style decides whether we draw a framed card
	-- (floating card, pill, full width, outlined) or a bare typographic
	-- bracket. margin stays out in the leading spans below so the drop
	-- shadow has room to peek past the card's bottom-right edge.
	local card
	if style.frame then
		local card_inner = content_widget
		if style.span_screen then
			-- stretch the content group to the full screen width so the
			-- FrameContainer ends up spanning screen_w, edge to edge.
			local content_size = content_widget:getSize()
			card_inner = LeftContainer:new{
					dimen = Geom:new{
						w = screen_w - 2 * (dimen_.padding + dimen_.border_size),
						h = content_size.h,
					},
					content_widget,
			}
		end
		card = FrameContainer:new{
			background = B_SETT.background == 0 and Bb.COLOR_WHITE or
						 Bb.COLOR_BLACK,
			color = B_SETT.border_color == 0 and Bb.COLOR_WHITE or
					Bb.COLOR_BLACK,
			radius = dimen_.corner_radius,
			margin = 0,
			bordersize = dimen_.border_size,
			padding = dimen_.padding,
			content_widget = card_inner,
		}
		if style.radius_from_height then
			-- pill: round the card into a lozenge once its height is known
			card.radius = math.floor(card:getSize().h / 2)
		end
	else
		-- bracketed: sandwich the content between two horizontal rules
		local ink = B_SETT.background == 1 and Bb.COLOR_WHITE or Bb.COLOR_BLACK
		local content_w = content_widget:getSize().w
		if content_w < 1 then content_w = 1 end
		card = VerticalGroup:new{
			align = "left",
			LineWidget:new{
							background = ink,
							dimen = Geom:new{
								w = content_w,
								h = dimen_.rule_width,
							},
			},
			VerticalSpan:new{width = dimen_.rule_gap},
			content_widget,
			VerticalSpan:new{width = dimen_.rule_gap},
			LineWidget:new{
							background = ink,
							dimen = Geom:new{
								w = content_w,
								h = dimen_.rule_width,
							},
			},
		}
	end

	-- composite a hard offset drop shadow behind the card so it reads
	-- as a card floating above the cover.
	local card_layer = card
	if style.frame and style.shadow and B_SETT.shadow_enabled then
		local csize = card:getSize()
		local off = dimen_.shadow_offset
		local shadow_gray = Bb["COLOR_GRAY_" .. B_SETT.shadow_gray_level] or
							Bb.COLOR_GRAY_4
		local shadow_box = FrameContainer:new{
			background = shadow_gray,
			radius = card.radius,
			bordersize = 0,
			margin = 0,
			padding = 0,
			Widget:new{ dimen = Geom:new{ w = csize.w, h = csize.h } },
		}
		-- push the shadow down-right, then stack the card on top of it.
		local shadow_layer = VerticalGroup:new{
			align = "left",
			VerticalSpan:new{ width = off },
			HorizontalGroup:new{
				HorizontalSpan:new{ width = off },
				shadow_box,
			},
		}
		card_layer = OverlapGroup:new{
			dimen = Geom:new{ w = csize.w + off, h = csize.h + off },
			shadow_layer,	-- painted first (behind)
			card,			-- painted on top, at the top-left
		}
	end

	-- restore the outer gap the card's margin used to provide, as leading
	-- spans, so the card + shadow isn't flush against the screen edge.
	content_widget = HorizontalGroup:new{
		HorizontalSpan:new{ width = dimen_.margin },
		VerticalGroup:new{
			align = "left",
			VerticalSpan:new{ width = dimen_.margin },
			card_layer,
		},
	}

	-- move custom position cont. to the left edge and replace child.
	cus_pos_container.horizontal_position = 0
	cus_pos_container.widget = content_widget

	return og_uiMan_show(self, widget, ...)
end
