-- rr_input: 键盘输入处理
-- 依赖: 全局 RR_KEY_R, RR_KEY_U, RR_POPUP, RR_NAME, TheInput, GetHoverItem, BuildIndexes, HasData, ClosePopup, CreatePopup

-- RR_KEY_R/RR_KEY_U 已在 modmain.lua 中从配置读取, 此处不覆盖

function HasData(name, mode)
	if mode == "SOURCE" then
		return (RR.by_product[name] and #RR.by_product[name] > 0) or (RR.cook_foods[name] ~= nil)
	else
		local has_mat = RR.by_material[name] and #RR.by_material[name] > 0
		local has_cook = (RR.cook_by_ingredient[name] and #RR.cook_by_ingredient[name] > 0) or RR.ingredient_tags[name] ~= nil
		return has_mat or has_cook
	end
end

-- R: 来源查询
local function OnPressR()
	local ok, e = pcall(function()
		if ThePlayer == nil then return end
		if TheFrontEnd and TheFrontEnd.textProcessorWidget then return end
		if ThePlayer.components.playercontroller ~= nil and ThePlayer.components.playercontroller.placer ~= nil then return end
		local item = GetHoverItem()
		if item == nil then
			if RR_POPUP ~= nil then ClosePopup(); end
			return
		end
		local name = item.prefab or "unknown"
		BuildIndexes()
		if not HasData(name, "SOURCE") then return end
		if RR_POPUP ~= nil then
			if RR_NAME == name and RR_MODE == "SOURCE" then ClosePopup(); return end
			ClosePopup()
		end
		CreatePopup(name, "SOURCE")
	end)
	if not ok then print("[RR] R:", e) end
end

-- U: 用途查询
local function OnPressU()
	local ok, e = pcall(function()
		if ThePlayer == nil then return end
		if TheFrontEnd and TheFrontEnd.textProcessorWidget then return end
		local item = GetHoverItem()
		if item == nil then
			if RR_POPUP ~= nil then ClosePopup(); end
			return
		end
		local name = item.prefab or "unknown"
		BuildIndexes()
		if not HasData(name, "USE") then return end
		if RR_POPUP ~= nil then
			if RR_NAME == name and RR_MODE == "USE" then ClosePopup(); return end
			ClosePopup()
		end
		CreatePopup(name, "USE")
	end)
	if not ok then print("[RR] U:", e) end
end

TheInput.onkeydown:AddEventHandler(RR_KEY_R, OnPressR)
TheInput.onkeydown:AddEventHandler(RR_KEY_U, OnPressU)
