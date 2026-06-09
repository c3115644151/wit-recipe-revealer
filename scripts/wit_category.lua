-- wit_category: 分类切换 + 配方获取
-- 依赖: 全局 WIT_CUR_CAT, WIT_PAGE, WIT_TAB_BTNS, WIT_NAME, WIT_MODE, WIT, SortRecipesByBuildable, SortCookingByAvailable, RenderCards, RenderCardCrafting, RenderCardCooking

function GetCurrentRecipes()
	if WIT_CUR_CAT == "CRAFTING" then
		local recipes = (WIT_MODE == "SOURCE") and (WIT.by_product[WIT_NAME] or {}) or (WIT.by_material[WIT_NAME] or {})
		return SortRecipesByBuildable(recipes)
	elseif WIT_CUR_CAT == "COOKING" then
		local recipes = {}
		if WIT_MODE == "SOURCE" then
			if WIT.cook_foods[WIT_NAME] then table.insert(recipes, WIT.cook_foods[WIT_NAME]) end
		else
			recipes = WIT.cook_by_ingredient[WIT_NAME] or {}
		end
		table.sort(recipes, function(a, b) return (a.priority or 0) > (b.priority or 0) end)
		recipes = SortCookingByAvailable(recipes)
		return recipes
	end
	return {}
end

function SelectCategory(cat, reset_page)
	WIT_CUR_CAT = cat
	if reset_page then WIT_PAGE = 1 end

	for c, t in pairs(WIT_TAB_BTNS) do
		if t then
			if c == cat then
				t:SetTextColour(0.95, 0.85, 0.55, 1)
				t:SetTextFocusColour(0.95, 0.85, 0.55, 1)
			else
				t:SetTextColour(0.45, 0.42, 0.36, 1)
				t:SetTextFocusColour(0.7, 0.65, 0.55, 1)
			end
		end
	end

	local recipes = GetCurrentRecipes()
	if cat == "CRAFTING" then
		RenderCards(recipes, 85, 90, RenderCardCrafting)
	else
		RenderCards(recipes, 85, 90, RenderCardCooking)
	end
end
