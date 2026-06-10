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
			table.sort(recipes, function(a, b) return (a.priority or 0) > (b.priority or 0) end)
			recipes = SortCookingByAvailable(recipes)
		else
			-- USE 模式：排序由 SelectCategory 基于解析后的视图数据完成，此处只做优先级基线
			local src = WIT.cook_by_ingredient[WIT_NAME]
			if src then
				for _, r in ipairs(src) do table.insert(recipes, r) end
			end
			table.sort(recipes, function(a, b) return (a.priority or 0) > (b.priority or 0) end)
		end
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
	-- U 模式烹饪：过滤 + 排序
	if cat == "COOKING" and WIT_MODE == "USE" then
		local ctx = WIT_COOK_CONTEXT
		local inv_counts = ctx and ctx.snapshot and ctx.snapshot.counts or {}

		local filtered = {}
		for _, r in ipairs(recipes) do
			local view = GetResolvedCookingCard(r, WIT_NAME)
			if view then
				r._cook_view = view
				table.insert(filtered, r)
			end
		end

		-- 能做的靠前（按优先级）→ 缺料的按缺口从大到小，同级按优先级
		table.sort(filtered, function(a, b)
			local va, vb = a._cook_view, b._cook_view
			local can_a = va and va.can_auto_cook or false
			local can_b = vb and vb.can_auto_cook or false
			if can_a ~= can_b then
				return can_a
			end
			if not can_a then
				-- 缺料组：缺口小的靠前（最接近完成），同级按优先级
				local gap_a, gap_b = 0, 0
				if va and va.need_map then
					for prefab, cnt in pairs(va.need_map) do
						gap_a = gap_a + math.max(0, cnt - (inv_counts[prefab] or 0))
					end
				end
				if vb and vb.need_map then
					for prefab, cnt in pairs(vb.need_map) do
						gap_b = gap_b + math.max(0, cnt - (inv_counts[prefab] or 0))
					end
				end
				if gap_a ~= gap_b then
					return gap_a < gap_b
				end
			end
			return (a.priority or 0) > (b.priority or 0)
		end)
		recipes = filtered
	end
	if cat == "CRAFTING" then
		RenderCards(recipes, 85, 90, RenderCardCrafting)
	else
		RenderCards(recipes, 85, 90, RenderCardCooking)
	end
end
