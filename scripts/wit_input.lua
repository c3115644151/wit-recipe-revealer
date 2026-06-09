-- wit_input: 键盘输入处理
-- 依赖: 全局 WIT_KEY_R, WIT_KEY_U, WIT_POPUP, WIT_NAME, TheInput, GetHoverItem, BuildIndexes, HasData, ClosePopup, CreatePopup

-- WIT_KEY_R/WIT_KEY_U 已在 modmain.lua 中从配置读取, 此处不覆盖

function HasData(name, mode)
	if mode == "SOURCE" then
		return (WIT.by_product[name] and #WIT.by_product[name] > 0) or (WIT.cook_foods[name] ~= nil)
	else
		local has_mat = WIT.by_material[name] and #WIT.by_material[name] > 0
		local has_cook = (WIT.cook_by_ingredient[name] and #WIT.cook_by_ingredient[name] > 0) or WIT.ingredient_tags[name] ~= nil
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
			if WIT_POPUP ~= nil then ClosePopup(); end
			return
		end
		local name = item.prefab or "unknown"
		BuildIndexes()
		if not HasData(name, "SOURCE") then return end
		if WIT_POPUP ~= nil then
			if WIT_NAME == name and WIT_MODE == "SOURCE" then ClosePopup(); return end
			ClosePopup()
		end
		CreatePopup(name, "SOURCE")
	end)
	if not ok then print("[WIT] R:", e) end
end

-- U: 用途查询
local function OnPressU()
	local ok, e = pcall(function()
		if ThePlayer == nil then return end
		if TheFrontEnd and TheFrontEnd.textProcessorWidget then return end
		local item = GetHoverItem()
		if item == nil then
			if WIT_POPUP ~= nil then ClosePopup(); end
			return
		end
		local name = item.prefab or "unknown"
		BuildIndexes()
		if not HasData(name, "USE") then return end
		if WIT_POPUP ~= nil then
			if WIT_NAME == name and WIT_MODE == "USE" then ClosePopup(); return end
			ClosePopup()
		end
		CreatePopup(name, "USE")
	end)
	if not ok then print("[WIT] U:", e) end
end

TheInput.onkeydown:AddEventHandler(WIT_KEY_R, OnPressR)
TheInput.onkeydown:AddEventHandler(WIT_KEY_U, OnPressU)
