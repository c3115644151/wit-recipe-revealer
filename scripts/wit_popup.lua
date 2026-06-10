-- wit_popup: 弹窗创建
-- 依赖: 全局 Widget, Image, Text, TextButton, ImageButton

function CreatePopup(name, mode)
	-- 刷新烹饪上下文（ClosePopup 会置 nil，每次弹窗重新构建）
	BuildCookContext()
	WIT_NAME = name; WIT_MODE = mode; WIT_PAGE = 1

	local avail_cats = {}
	if mode == "SOURCE" then
		if WIT.by_product[name] and #WIT.by_product[name] > 0 then table.insert(avail_cats, "CRAFTING") end
		if WIT.cook_foods[name] then table.insert(avail_cats, "COOKING") end
	else
		if WIT.by_material[name] and #WIT.by_material[name] > 0 then table.insert(avail_cats, "CRAFTING") end
		if WIT.cook_by_ingredient[name] and #WIT.cook_by_ingredient[name] > 0 then table.insert(avail_cats, "COOKING") end
	end
	if #avail_cats == 0 then return end
	WIT_AVAIL_CATS = avail_cats

	local left_root = ThePlayer.HUD.controls.left_root
	if left_root == nil then left_root = ThePlayer.HUD.controls end
	WIT_POPUP = left_root:AddChild(Widget("WITPopup"))
	if WIT_POPUP == nil then return end

	local crafting_hud = ThePlayer.HUD.controls.craftingmenu
	local is_open = crafting_hud and crafting_hud:IsCraftingOpen()
	local popup_x = is_open and 881 or 405
	WIT_POPUP:SetPosition(popup_x, 35)

	local CRAFTING_ATLAS = resolvefilepath("images/crafting_menu.xml")
	local frame_w = 360
	local frame_h = 480

	local fill = WIT_POPUP:AddChild(Image(CRAFTING_ATLAS, "backing.tex"))
	if fill then fill:ScaleToSize(frame_w + 50, frame_h + 18); fill:SetTint(1, 1, 1, 0.5); fill:MoveToBack() end

	local left_side = WIT_POPUP:AddChild(Image(CRAFTING_ATLAS, "side.tex"))
	if left_side then left_side:SetPosition(-frame_w/2 - 29, 1); left_side:ScaleToSize(-26, -(frame_h - 20)) end

	local right_side = WIT_POPUP:AddChild(Image(CRAFTING_ATLAS, "side.tex"))
	if right_side then right_side:SetPosition(frame_w/2 + 29, 1); right_side:ScaleToSize(26, frame_h - 20) end

	local top_edge = WIT_POPUP:AddChild(Image(CRAFTING_ATLAS, "top.tex"))
	if top_edge then top_edge:SetPosition(0, 250); top_edge:ScaleToSize(frame_w + 70, 38) end

	local bottom_edge = WIT_POPUP:AddChild(Image(CRAFTING_ATLAS, "bottom.tex"))
	if bottom_edge then bottom_edge:SetPosition(0, -248); bottom_edge:ScaleToSize(frame_w + 70, 38) end

	local icon_atlas = GetInventoryItemAtlas(name .. ".tex")
	local title_y = 196
	local title_bg = WIT_POPUP:AddChild(Image(CRAFTING_ATLAS, "slot_bg.tex"))
	if title_bg then title_bg:SetPosition(-150, title_y); title_bg:SetScale(0.5) end
	local title_frame = WIT_POPUP:AddChild(ImageButton(CRAFTING_ATLAS, "slot_frame.tex", "slot_frame_highlight.tex"))
	if title_frame then title_frame:SetPosition(-150, title_y); title_frame:Disable(); title_frame:SetScale(0.5) end
	if icon_atlas then
		local title_icon = WIT_POPUP:AddChild(Image(icon_atlas, name .. ".tex"))
		if title_icon then title_icon:ScaleToSize(48, 48); title_icon:SetPosition(-150, title_y) end
	end

	local dispname = STRINGS.NAMES[string.upper(name)] or name
	local title = WIT_POPUP:AddChild(Text(UIFONT, 34))
	if title then title:SetString(dispname); title:SetPosition(-60, title_y); title:SetColour(0.95, 0.88, 0.7, 1) end

	local sep_top = WIT_POPUP:AddChild(Image("images/global.xml", "square.tex"))
	if sep_top then sep_top:SetSize(364, 1); sep_top:SetPosition(0, 150); sep_top:SetTint(0.3, 0.25, 0.18, 1) end

	local close = WIT_POPUP:AddChild(TextButton())
	if close then
		close:SetText(WIT_TXT.CLOSE); close:SetTextSize(20)
		close:SetPosition(160, 160)
		close:SetTextColour(0.5, 0.45, 0.38, 1); close:SetTextFocusColour(0.95, 0.85, 0.55, 1)
		close:SetOnClick(ClosePopup)
	end

	WIT_TAB_BTNS = {}
	local tab_y = 125
	for i, cat in ipairs(WIT_AVAIL_CATS) do
		local tb = WIT_POPUP:AddChild(TextButton())
		if tb then
			tb:SetText(cat == "CRAFTING" and WIT_TXT.TAB_CRAFTING or WIT_TXT.TAB_COOKING)
			tb:SetTextSize(26)
			tb:SetPosition((i - (#WIT_AVAIL_CATS + 1) / 2) * 130, tab_y)
			tb:SetOnClick(function() SelectCategory(cat, true) end)
			WIT_TAB_BTNS[cat] = tb
		end
	end

	WIT_CONTENT = WIT_POPUP:AddChild(Widget("c"))
	if WIT_CONTENT then WIT_CONTENT:SetPosition(0, 16) end

	local pg_y = -210
	WIT_PG_PREV = WIT_POPUP:AddChild(ImageButton(CRAFTING_ATLAS, "scrollbar_arrow_down.tex", "scrollbar_arrow_down_hl.tex"))
	if WIT_PG_PREV then
		WIT_PG_PREV:SetScale(0.4); WIT_PG_PREV:SetPosition(-40, pg_y); WIT_PG_PREV:SetRotation(90)
		WIT_PG_PREV:SetOnClick(function()
			WIT_PAGE = WIT_PAGE - 1
			SelectCategory(WIT_CUR_CAT, false)
		end)
	end

	WIT_PG_TEXT = WIT_POPUP:AddChild(Text(NEWFONT, 20))
	if WIT_PG_TEXT then WIT_PG_TEXT:SetString("1 / 1"); WIT_PG_TEXT:SetPosition(0, pg_y); WIT_PG_TEXT:SetColour(0.85, 0.78, 0.65, 1) end

	WIT_PG_NEXT = WIT_POPUP:AddChild(ImageButton(CRAFTING_ATLAS, "scrollbar_arrow_down.tex", "scrollbar_arrow_down_hl.tex"))
	if WIT_PG_NEXT then
		WIT_PG_NEXT:SetScale(0.4); WIT_PG_NEXT:SetPosition(40, pg_y); WIT_PG_NEXT:SetRotation(-90)
		WIT_PG_NEXT:SetOnClick(function()
			WIT_PAGE = WIT_PAGE + 1
			SelectCategory(WIT_CUR_CAT, false)
		end)
	end
	SelectCategory(WIT_AVAIL_CATS[1], true)
end
