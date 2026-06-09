-- rr_sort: 排序 + 跳转
-- 依赖: 全局 RR_NAME, RR_CONTENT, RR_POPUP

function GetRecipeBuildState(recipe_name)
	if ThePlayer == nil or ThePlayer.HUD == nil then return "unknown" end
	local cm = ThePlayer.HUD.controls and ThePlayer.HUD.controls.craftingmenu and ThePlayer.HUD.controls.craftingmenu.craftingmenu
	if cm == nil or cm.crafting_hud == nil then return "unknown" end
	local rd = cm.crafting_hud.valid_recipes[recipe_name]
	if rd and rd.meta then return rd.meta.build_state end
	return "unknown"
end

function SortRecipesByBuildable(recipes)
	local buildable, partial, unbuildable = {}, {}, {}
	for _, r in ipairs(recipes) do
		local s = GetRecipeBuildState(r.name)
		if s == "buffered" or s == "has_ingredients" or s == "freecrafting" then
			table.insert(buildable, r)
		elseif s == "prototype" then
			table.insert(partial, r)
		else
			table.insert(unbuildable, r)
		end
	end
	-- 组内按背包材料匹配数排序
	local cooking = GLOBAL.require("cooking")
	local bp_items = GetPlayerIngredientList() or {}
	local function match_count(r)
		if r and r.ingredients then
			local avail = {}
			for _, v in ipairs(bp_items) do
				local name = RR_COOKING_ALIASES[v] or v
				avail[name] = (avail[name] or 0) + 1
			end
			local cnt = 0
			for _, ing in ipairs(r.ingredients) do
				if avail[ing.type] and avail[ing.type] > 0 then
					cnt = cnt + 1
					avail[ing.type] = avail[ing.type] - 1
				end
			end
			return cnt
		end
		return 0
	end
	table.sort(buildable, function(a, b) return match_count(a) > match_count(b) end)
	table.sort(partial, function(a, b) return match_count(a) > match_count(b) end)
	table.sort(unbuildable, function(a, b) return match_count(a) > match_count(b) end)
	local out = {}
	for _, r in ipairs(buildable) do table.insert(out, r) end
	for _, r in ipairs(partial) do table.insert(out, r) end
	for _, r in ipairs(unbuildable) do table.insert(out, r) end
	return out
end

function SortCookingByAvailable(recipes)
	if #recipes == 0 then return recipes end
	local prefablist = GetPlayerIngredientList()
	if prefablist == nil or #prefablist == 0 then
		table.sort(recipes, function(a, b) return (a.priority or 0) > (b.priority or 0) end)
		return recipes
	end
	local cooking = GLOBAL.require("cooking")
	local prefabs, tags = {}, {}
	for _, v in ipairs(prefablist) do
		local name = RR_COOKING_ALIASES[v] or v
		prefabs[name] = (prefabs[name] or 0) + 1
		local data = (cooking.ingredients or {})[name]
		if data ~= nil then
			for kk, vv in pairs(data.tags) do
				tags[kk] = (tags[kk] or 0) + vv
			end
		end
	end
	local ingdata = { tags = tags, names = prefabs }
	local matched, unmatched = {}, {}
	for _, r in ipairs(recipes) do
		local match_count = 0
		if r.card_def and r.card_def.ingredients then
			for _, ci in ipairs(r.card_def.ingredients) do
				local name = RR_COOKING_ALIASES[ci[1]] or ci[1]
				local has_item = prefabs[name] or 0
				for _ = 1, ci[2] do
					if has_item > 0 then
						match_count = match_count + 1
						has_item = has_item - 1
					end
				end
			end
		end
		if r.test and r.test("cookpot", ingdata.names, ingdata.tags) then
			r._cook_match = match_count
			r._cook_pass = true
			table.insert(matched, r)
		else
			r._cook_match = match_count
			r._cook_pass = false
			table.insert(unmatched, r)
		end
	end
	table.sort(matched, function(a, b)
		if (a.priority or 0) ~= (b.priority or 0) then return (a.priority or 0) > (b.priority or 0) end
		return (a._cook_match or 0) > (b._cook_match or 0)
	end)
	table.sort(unmatched, function(a, b)
		if (a._cook_match or 0) ~= (b._cook_match or 0) then
			return (a._cook_match or 0) > (b._cook_match or 0)
		end
		return (a.priority or 0) > (b.priority or 0)
	end)
	local out = {}
	for _, r in ipairs(matched) do table.insert(out, r) end
	for _, r in ipairs(unmatched) do table.insert(out, r) end
	return out
end

function JumpToCraft(recipe)
	ClosePopup()
	if ThePlayer == nil or ThePlayer.HUD == nil then return end
	local hud = ThePlayer.HUD
	hud:OpenCrafting()
	local cm = hud.controls and hud.controls.craftingmenu and hud.controls.craftingmenu.craftingmenu
	if cm == nil then return end
	cm:SelectFilter(CRAFTING_FILTERS.EVERYTHING.name)
	local rd = cm.crafting_hud.valid_recipes[recipe.name]
	if rd == nil then rd = { recipe = recipe, meta = { build_state = "prototype", can_build = false } } end
	cm:PopulateRecipeDetailPanel(rd, nil)
end
