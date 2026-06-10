-- wit_slot: 物品图标 + 箭头
-- 依赖: 全局 Image, Text, TextButton, ImageButton

function MakeSlot(parent, prefab, x, y, need_amount, highlight, slot_size, icon_size, _, show_count)
	if parent == nil then return end
	slot_size = slot_size or 54
	icon_size = icon_size or 54
	if show_count == nil then show_count = true end

	-- 烹饪系统遗留名 → 真实 prefab 名（如 egg → bird_egg）
	local disp_prefab = prefab
	if prefab and WIT_INGREDIENT_PREFAB_MAP then
		disp_prefab = WIT_INGREDIENT_PREFAB_MAP[prefab] or prefab
	end

	local has_enough = true
	local on_hand = 0
	if need_amount ~= nil and ThePlayer ~= nil and ThePlayer.replica ~= nil then
		local inv = ThePlayer.replica.inventory
		if inv ~= nil then
			local ok, cnt = inv:Has(disp_prefab, need_amount, true)
			has_enough = ok
			on_hand = cnt or 0
		end
	end

	local bg_tex = (need_amount ~= nil and not has_enough) and "resource_needed.tex" or "inv_slot.tex"

	local slot = parent:AddChild(ImageButton("images/hud.xml", bg_tex))
	if slot == nil then return end
	slot:SetScale(slot_size / 64, slot_size / 64)
	slot:SetPosition(x, y)
	if highlight then slot.image:SetTint(1.2, 1.0, 0.6, 1) end

	if disp_prefab then
		local dispname = STRINGS.NAMES[string.upper(disp_prefab)] or CN(disp_prefab) or disp_prefab
		slot:SetTooltip(dispname)
	end

	if disp_prefab then
		local img_name = disp_prefab .. ".tex"
		local atlas = GetInventoryItemAtlas(img_name)
		if atlas then
			local icon = slot.image:AddChild(Image(atlas, img_name))
			if icon then icon:SetSize(icon_size, icon_size) end
		end
	end

	if need_amount ~= nil and show_count then
		local t = slot.image:AddChild(Text(NUMBERFONT, 26))
		if t then
			if on_hand > 999 then
				t:SetString(string.format("999+/%d", need_amount))
			else
				t:SetString(string.format("%d/%d", on_hand, need_amount))
			end
			t:SetPosition(5, -32)
			if not has_enough then
				t:SetColour(1, 0.6, 0.6, 1)
			else
				t:SetColour(1, 1, 1, 1)
			end
		end
	end

	if disp_prefab ~= nil and ThePlayer ~= nil then
		slot:SetOnClick(function()
			BuildIndexes()
			if not HasData(disp_prefab, "SOURCE") then return end
			ClosePopup()
			CreatePopup(disp_prefab, "SOURCE")
		end)
		local orig_oc = slot.OnControl
		slot.OnControl = function(btn, control, down)
			if down and control == CONTROL_SECONDARY then
				BuildIndexes()
				if not HasData(disp_prefab, "USE") then return true end
				ClosePopup()
				CreatePopup(disp_prefab, "USE")
				return true
			end
			return orig_oc(btn, control, down)
		end
	end
	return slot
end

function MakeArrow(parent, x, y)
	if parent == nil then return end
	local t = parent:AddChild(Text(UIFONT, 40))
	if t then t:SetString("→"); t:SetPosition(x, y); t:SetColour(0.6, 0.55, 0.4, 1) end
end
