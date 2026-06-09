-- rr_category: 分类切换 + 配方获取
-- 依赖: 全局 RR_CUR_CAT, RR_PAGE, RR_TAB_BTNS, RR_NAME, RR_MODE, RR, SortRecipesByBuildable, SortCookingByAvailable, RenderCards, RenderCardCrafting, RenderCardCooking

function GetCurrentRecipes()
	if RR_CUR_CAT == "CRAFTING" then
		local recipes = (RR_MODE == "SOURCE") and (RR.by_product[RR_NAME] or {}) or (RR.by_material[RR_NAME] or {})
		return SortRecipesByBuildable(recipes)
	elseif RR_CUR_CAT == "COOKING" then
		local recipes = {}
		if RR_MODE == "SOURCE" then
			if RR.cook_foods[RR_NAME] then table.insert(recipes, RR.cook_foods[RR_NAME]) end
		else
			recipes = RR.cook_by_ingredient[RR_NAME] or {}
		end
		table.sort(recipes, function(a, b) return (a.priority or 0) > (b.priority or 0) end)
		recipes = SortCookingByAvailable(recipes)
		return recipes
	end
	return {}
end

function SelectCategory(cat, reset_page)
	RR_CUR_CAT = cat
	if reset_page then RR_PAGE = 1 end

	for c, t in pairs(RR_TAB_BTNS) do
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
