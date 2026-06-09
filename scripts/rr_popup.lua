-- rr_popup: 弹窗创建
-- 依赖: 全局 Widget, Image, Text, TextButton, ImageButton

function CreatePopup(name, mode)
	RR_NAME = name; RR_MODE = mode; RR_PAGE = 1

	local avail_cats = {}
	if mode == "SOURCE" then
		if RR.by_product[name] and #RR.by_product[name] > 0 then table.insert(avail_cats, "CRAFTING") end
		if RR.cook_foods[name] then table.insert(avail_cats, "COOKING") end
	else
		if RR.by_material[name] and #RR.by_material[name] > 0 then table.insert(avail_cats, "CRAFTING") end
		if (RR.cook_by_ingredient[name] and #RR.cook_by_ingredient[name] > 0) or RR.ingredient_tags[name] then table.insert(avail_cats, "COOKING") end
	end
	if #avail_cats == 0 then return end
	RR_AVAIL_CATS = avail_cats

	local left_root = ThePlayer.HUD.controls.left_root
	if left_root == nil then left_root = ThePlayer.HUD.controls end
	RR_POPUP = left_root:AddChild(Widget("RRPopup"))
	if RR_POPUP == nil then return end

	local crafting_hud = ThePlayer.HUD.controls.craftingmenu
	local is_open = crafting_hud and crafting_hud:IsCraftingOpen()
	local popup_x = is_open and 881 or 405
	RR_POPUP:SetPosition(popup_x, 35)

	local CRAFTING_ATLAS = resolvefilepath("images/crafting_menu.xml")
	local frame_w = 360
	local frame_h = 480

	local fill = RR_POPUP:AddChild(Image(CRAFTING_ATLAS, "backing.tex"))
	if fill then fill:ScaleToSize(frame_w + 50, frame_h + 18); fill:SetTint(1, 1, 1, 0.5); fill:MoveToBack() end

	local left_side = RR_POPUP:AddChild(Image(CRAFTING_ATLAS, "side.tex"))
	if left_side then left_side:SetPosition(-frame_w/2 - 29, 1); left_side:ScaleToSize(-26, -(frame_h - 20)) end

	local right_side = RR_POPUP:AddChild(Image(CRAFTING_ATLAS, "side.tex"))
	if right_side then right_side:SetPosition(frame_w/2 + 29, 1); right_side:ScaleToSize(26, frame_h - 20) end

	local top_edge = RR_POPUP:AddChild(Image(CRAFTING_ATLAS, "top.tex"))
	if top_edge then top_edge:SetPosition(0, 250); top_edge:ScaleToSize(frame_w + 70, 38) end

	local bottom_edge = RR_POPUP:AddChild(Image(CRAFTING_ATLAS, "bottom.tex"))
	if bottom_edge then bottom_edge:SetPosition(0, -248); bottom_edge:ScaleToSize(frame_w + 70, 38) end

	local icon_atlas = GetInventoryItemAtlas(name .. ".tex")
	local title_y = 196
	local title_bg = RR_POPUP:AddChild(Image(CRAFTING_ATLAS, "slot_bg.tex"))
	if title_bg then title_bg:SetPosition(-150, title_y); title_bg:SetScale(0.5) end
	local title_frame = RR_POPUP:AddChild(ImageButton(CRAFTING_ATLAS, "slot_frame.tex", "slot_frame_highlight.tex"))
	if title_frame then title_frame:SetPosition(-150, title_y); title_frame:Disable(); title_frame:SetScale(0.5) end
	if icon_atlas then
		local title_icon = RR_POPUP:AddChild(Image(icon_atlas, name .. ".tex"))
		if title_icon then title_icon:ScaleToSize(48, 48); title_icon:SetPosition(-150, title_y) end
	end

	local dispname = STRINGS.NAMES[string.upper(name)] or name
	local title = RR_POPUP:AddChild(Text(UIFONT, 34))
	if title then title:SetString(dispname); title:SetPosition(-60, title_y); title:SetColour(0.95, 0.88, 0.7, 1) end

	local sep_top = RR_POPUP:AddChild(Image("images/global.xml", "square.tex"))
	if sep_top then sep_top:SetSize(364, 1); sep_top:SetPosition(0, 150); sep_top:SetTint(0.3, 0.25, 0.18, 1) end

	local close = RR_POPUP:AddChild(TextButton())
	if close then
		close:SetText("✕"); close:SetTextSize(20)
		close:SetPosition(160, 160)
		close:SetTextColour(0.5, 0.45, 0.38, 1); close:SetTextFocusColour(0.95, 0.85, 0.55, 1)
		close:SetOnClick(ClosePopup)
	end

	RR_TAB_BTNS = {}
	local tab_y = 125
	for i, cat in ipairs(RR_AVAIL_CATS) do
		local tb = RR_POPUP:AddChild(TextButton())
		if tb then
			tb:SetText(cat == "CRAFTING" and "制作" or "烹饪")
			tb:SetTextSize(26)
			tb:SetPosition((i - (#RR_AVAIL_CATS + 1) / 2) * 130, tab_y)
			tb:SetOnClick(function() SelectCategory(cat, true) end)
			RR_TAB_BTNS[cat] = tb
		end
	end

	RR_CONTENT = RR_POPUP:AddChild(Widget("c"))
	if RR_CONTENT then RR_CONTENT:SetPosition(0, 16) end

	local pg_y = -210
	RR_PG_PREV = RR_POPUP:AddChild(ImageButton(CRAFTING_ATLAS, "scrollbar_arrow_down.tex", "scrollbar_arrow_down_hl.tex"))
	if RR_PG_PREV then
		RR_PG_PREV:SetScale(0.4); RR_PG_PREV:SetPosition(-40, pg_y); RR_PG_PREV:SetRotation(90)
		RR_PG_PREV:SetOnClick(function()
			if RR_PAGE > 1 then RR_PAGE = RR_PAGE - 1; SelectCategory(RR_CUR_CAT, false) end
		end)
	end

	RR_PG_TEXT = RR_POPUP:AddChild(Text(NEWFONT, 20))
	if RR_PG_TEXT then RR_PG_TEXT:SetString("1 / 1"); RR_PG_TEXT:SetPosition(0, pg_y); RR_PG_TEXT:SetColour(0.85, 0.78, 0.65, 1) end

	RR_PG_NEXT = RR_POPUP:AddChild(ImageButton(CRAFTING_ATLAS, "scrollbar_arrow_down.tex", "scrollbar_arrow_down_hl.tex"))
	if RR_PG_NEXT then
		RR_PG_NEXT:SetScale(0.4); RR_PG_NEXT:SetPosition(40, pg_y); RR_PG_NEXT:SetRotation(-90)
		RR_PG_NEXT:SetOnClick(function()
			RR_PAGE = RR_PAGE + 1; SelectCategory(RR_CUR_CAT, false)
		end)
	end
	SelectCategory(RR_AVAIL_CATS[1], true)
end
