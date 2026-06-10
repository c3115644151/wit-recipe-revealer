-- wit_build: 索引构建
-- 依赖: WIT, WIT.ingredient_tags (全局)

WIT_PROBED_CONDITIONS = {}  -- 运行时探测的烹饪条件缓存

-- 为无 card_def 的配方提供硬编码示例组合 (来源: wiki Cookbook 卡 + test()验证)
local FALLBACK_CARD_DEF = {
	["asparagussoup"] = {ingredients = {{"asparagus",1}, {"carrot",2}, {"corn",1}} },
	["baconeggs"] = {ingredients = {{"monstermeat",1}, {"smallmeat",1}, {"egg",2}} },
	["bananajuice"] = {ingredients = {{"cave_banana",2}, {"berries",2}} },
	["barnaclepita"] = {ingredients = {{"barnacle",1}, {"carrot",1}, {"berries",2}} },
	["barnaclinguine"] = {ingredients = {{"barnacle",2}, {"carrot",1}, {"corn",1}} },
	["beefalotreat"] = {ingredients = {{"twigs",1}, {"forgetmelots",1}, {"acorn",1}, {"twigs",1}} },
	["bonestew"] = {ingredients = {{"meat",3}, {"berries",1}} },
	["bunnystew"] = {ingredients = {{"smallmeat",1}, {"ice",2}, {"berries",1}} },
	["ceviche"] = {ingredients = {{"fishmeat",2}, {"ice",2}} },
	["batnosehat"] = {ingredients = {{"batnose",1}, {"kelp",1}, {"butter",1}, {"berries",1}} },
	["dustmeringue"] = {ingredients = {{"refined_dust",1}, {"berries",3}} },
	["figatoni"] = {ingredients = {{"fig",1}, {"carrot",1}, {"corn",1}, {"berries",1}} },
	["flowersalad"] = {ingredients = {{"cactus_flower",1}, {"carrot",2}, {"corn",1}} },
	["frognewton"] = {ingredients = {{"fig",1}, {"froglegs",1}, {"berries",2}} },
	["frozenbananadaiquiri"] = {ingredients = {{"cave_banana",1}, {"ice",1}, {"berries",2}} },
	["fruitmedley"] = {ingredients = {{"dragonfruit",3}, {"berries",1}} },
	["icecream"] = {ingredients = {{"ice",1}, {"butter",1}, {"honey",1}, {"berries",1}} },
	["jammypreserves"] = {ingredients = {{"berries",4}} },
	["jellybean"] = {ingredients = {{"royal_jelly",1}, {"berries",3}} },
	["justeggs"] = {ingredients = {{"egg",3}, {"berries",1}} },
	["koalefig_trunk"] = {ingredients = {{"trunk_summer",1}, {"fig",1}, {"berries",2}} },
	["leafloaf"] = {ingredients = {{"plantmeat",2}, {"berries",2}} },
	["leafymeatburger"] = {ingredients = {{"plantmeat",1}, {"onion",1}, {"carrot",1}, {"corn",1}} },
	["leafymeatsouffle"] = {ingredients = {{"plantmeat",2}, {"honey",2}} },
	["lobsterbisque"] = {ingredients = {{"wobster_sheller_land",1}, {"ice",1}, {"berries",2}} },
	["lobsterdinner"] = {ingredients = {{"wobster_sheller_land",1}, {"butter",1}, {"smallmeat",1}, {"berries",1}} },
	["mandrakesoup"] = {ingredients = {{"mandrake",1}, {"berries",3}} },
	["mashedpotatoes"] = {ingredients = {{"potato",2}, {"garlic",1}, {"berries",1}} },
	["meatballs"] = {ingredients = {{"monstermeat",1}, {"red_cap",3}} },
	["meatysalad"] = {ingredients = {{"plantmeat",1}, {"carrot",1}, {"corn",1}, {"asparagus",1}} },
	["monsterlasagna"] = {ingredients = {{"monstermeat",2}, {"berries",2}} },
	["perogies"] = {ingredients = {{"smallmeat",1}, {"egg",1}, {"carrot",1}, {"berries",1}} },
	["potatotornado"] = {ingredients = {{"potato",1}, {"twigs",1}, {"berries",2}} },
	["ratatouille"] = {ingredients = {{"carrot",1}, {"berries",3}} },
	["salsa"] = {ingredients = {{"tomato",1}, {"onion",1}, {"berries",2}} },
	["seafoodgumbo"] = {ingredients = {{"fishmeat",2}, {"fishmeat_small",1}, {"ice",1}} },
	["shroombait"] = {ingredients = {{"moon_cap",2}, {"monstermeat",1}, {"berries",1}} },
	["shroomcake"] = {ingredients = {{"moon_cap",1}, {"red_cap",1}, {"blue_cap",1}, {"green_cap",1}} },
	["surfnturf"] = {ingredients = {{"meat",2}, {"fishmeat",2}} },
	["talleggs"] = {ingredients = {{"tallbirdegg",1}, {"carrot",1}, {"berries",2}} },
	["unagi"] = {ingredients = {{"eel",1}, {"cutlichen",1}, {"berries",2}} },
	["veggieomlet"] = {ingredients = {{"egg",2}, {"carrot",1}, {"corn",1}} },
	["vegstinger"] = {ingredients = {{"tomato",1}, {"asparagus",1}, {"carrot",1}, {"ice",1}} },
	["waffles"] = {ingredients = {{"butter",1}, {"egg",1}, {"berries",2}} },
	["watermelonicle"] = {ingredients = {{"watermelon",1}, {"ice",1}, {"twigs",1}, {"berries",1}} },
	["wetgoop"] = {ingredients = {{"twigs",4}} },
}

-- 为没有 card_def 的料理自动生成示例配方
-- 通过填充物法找到第一个合法的食材组合，写入 recipe.card_def
function GenerateCardDef(recipe, cooking)
	if not recipe.test or not cooking or not cooking.ingredients then return nil end

	local fillers = {"berries", "ice", "twigs", "carrot", "corn", "red_cap", "honey"}
	-- 构建食材池（排除 _cooked / _dried 自动变体）
	local pool = {}
	for name, _ in pairs(cooking.ingredients) do
		if not name:match("_cooked$") and not name:match("_dried$") then
			table.insert(pool, name)
		end
	end
	-- 第 1 阶：单种食材 x4
	for _, name in ipairs(pool) do
		local names, tags = {[name]=4}, {}
		local d = cooking.ingredients[name]
		if d then for t,v in pairs(d.tags) do tags[t] = v * 4 end end
		if recipe.test("cookpot", names, tags) then
			return {ingredients = {{name, 4}}}
		end
	end
	-- 第 2 阶：1 主料 + 3 填充（只试填物料）
	for _, name in ipairs(pool) do
		for _, filler in ipairs(fillers) do
			if filler ~= name then
				local slots = {name, filler, filler, filler}
				local names, tags = {}, {}
				for _, n in ipairs(slots) do
					names[n] = (names[n] or 0) + 1
					local d = cooking.ingredients[n]
					if d then for t,v in pairs(d.tags) do tags[t] = (tags[t] or 0) + v end end
				end
				if recipe.test("cookpot", names, tags) then
					return {ingredients = {{name, 1}, {filler, 3}}}
				end
			end
		end
	end
	-- 第 3 阶：两两组合（覆盖需要 2 种特定食材的料理，如 rice+egg）
	for idx1 = 1, #pool do
		for idx2 = idx1, #pool do
			local a, b = pool[idx1], pool[idx2]
			-- 试 {a, a, b, b}
			local slots = {a, a, b, b}
			local names, tags = {}, {}
			for _, n in ipairs(slots) do
				names[n] = (names[n] or 0) + 1
				local d = cooking.ingredients[n]
				if d then for t,v in pairs(d.tags) do tags[t] = (tags[t] or 0) + v end end
			end
			if recipe.test("cookpot", names, tags) then
				local map = {}
				for _, n in ipairs(slots) do map[n] = (map[n] or 0) + 1 end
				local card = {ingredients = {}}
				for n, c in pairs(map) do table.insert(card.ingredients, {n, c}) end
				return card
			end
		end
	end
	return nil
end

-- 运行时探测料理的 tag 条件：利用 card_def 作为基础食材组合，
-- 逐个 tag 增减来探查 test() 的门槛值和禁止项
function ProbeCookCondition(recipe)
	if not recipe.test or not recipe.card_def or not recipe.card_def.ingredients then return nil end
	local cooking = GLOBAL.require("cooking")
	if not cooking or not cooking.ingredients then return nil end

	-- 从食材池动态收集所有出现过的 tag（兼容 mod 新增的 tag）
	local all_tags = {}
	for _, data in pairs(cooking.ingredients) do
		if data and data.tags then
			for t, _ in pairs(data.tags) do
				all_tags[t] = true
			end
		end
	end
	-- 转成有序列表：标准 tag 优先，自定义 tag 在后面
	local tag_order = {"meat","monster","veggie","fruit","egg","fish","sweetener",
	                   "frozen","dairy","inedible","seed","magic","decoration","precook","dried"}
	local sorted = {}
	local seen = {}
	for _, t in ipairs(tag_order) do
		if all_tags[t] then
			table.insert(sorted, t); seen[t] = true
		end
	end
	for t, _ in pairs(all_tags) do
		if not seen[t] then table.insert(sorted, t) end
	end

	-- 从 card_def 构建基础 names + tags
	local base_names, base_tags = {}, {}
	for _, ci in ipairs(recipe.card_def.ingredients) do
		local name = ci[1]
		base_names[name] = (base_names[name] or 0) + ci[2]
		local data = cooking.ingredients[name]
		if data then
			for t, v in pairs(data.tags) do
				base_tags[t] = (base_tags[t] or 0) + v * ci[2]
			end
		end
	end
	if not next(base_names) then return nil end

	-- 确认基础组合能通过 test()
	if not recipe.test("cookpot", base_names, base_tags) then return nil end

	local results = {}
	for _, tag in ipairs(sorted) do
		local has_val = base_tags[tag] or 0

		-- A) 检查是否为下限 tag：移除后 test() 是否失败
		local reduced = {}
		for t, v in pairs(base_tags) do if t ~= tag then reduced[t] = v end end
		if has_val > 0 and not recipe.test("cookpot", base_names, reduced) then
			-- 二分法找最小通过值
			local lo, hi = 0, has_val
			while hi - lo > 0.05 do
				local mid = (lo + hi) / 2
				reduced[tag] = mid
				if recipe.test("cookpot", base_names, reduced) then
					hi = mid
				else
					lo = mid
				end
			end
			if hi >= 0.05 then
				if hi == math.floor(hi) then hi = math.floor(hi) end
				table.insert(results, {tag, "≥" .. tostring(hi)})
			end
		end

		-- B) 检查是否为禁止 tag（not 条件）：基础组合里没有，但加上后失败
		if has_val == 0 then
			local added = {}
			for t, v in pairs(base_tags) do added[t] = v end
			added[tag] = 5
			if not recipe.test("cookpot", base_names, added) then
				table.insert(results, {tag, "=="})
			end
		end
	end

	if #results == 0 then return nil end
	return results
end

function BuildIndexes()
	if WIT_data_built then return end
	WIT_data_built = true
	for rname, recipe in pairs(AllRecipes) do
		local prod = recipe.product or rname
		WIT.by_product[prod] = WIT.by_product[prod] or {}
		table.insert(WIT.by_product[prod], recipe)
		for _, ing in ipairs(recipe.ingredients or {}) do
			if type(ing.type) == "string" then
				WIT.by_material[ing.type] = WIT.by_material[ing.type] or {}
				table.insert(WIT.by_material[ing.type], recipe)
			end
		end
	end
	local cooking = GLOBAL.require("cooking")
	if cooking ~= nil then
		for _, recipes in pairs(cooking.cookbook_recipes or {}) do
			for fname, frecipe in pairs(recipes) do
				WIT.cook_foods[fname] = frecipe
			end
		end
		for iname, idata in pairs(cooking.ingredients or {}) do
			WIT.ingredient_tags[iname] = idata.tags
		end

		local cooker_types = {"cookpot", "portablecookpot"}
		for _, cooker_type in ipairs(cooker_types) do
			for fname, frecipe in pairs(cooking.recipes[cooker_type] or {}) do
				-- 1) 兜底：优先用 FALLBACK_CARD_DEF
				if frecipe.test and not frecipe.card_def and FALLBACK_CARD_DEF[fname] then
					frecipe.card_def = FALLBACK_CARD_DEF[fname]
				end
				-- 2) 自动生成 card_def：对没有示例配方的料理，通过 test() 反推合法食材组合
				if frecipe.test and not frecipe.card_def then
					frecipe.card_def = GenerateCardDef(frecipe, cooking)
				end
				if not WIT.cook_foods[fname] then
					WIT.cook_foods[fname] = frecipe
				end
				-- 3) 食材关联：只要有了 card_def 就走标准流程
				if frecipe.test and frecipe.card_def and frecipe.card_def.ingredients then
					for iname, _ in pairs(cooking.ingredients or {}) do
						local item_tags = WIT.ingredient_tags[iname]
						if item_tags then
							local ok = false
							for slot_idx = 1, #frecipe.card_def.ingredients do
								local names, tags = {}, {}
								for j, ci in ipairs(frecipe.card_def.ingredients) do
									local name = ci[1]
									for _ = 1, ci[2] do
										if j == slot_idx then name = iname end
										names[name] = (names[name] or 0) + 1
										local ing_data = (cooking.ingredients or {})[name]
										if ing_data then
											for kk, vv in pairs(ing_data.tags) do
												tags[kk] = (tags[kk] or 0) + vv
											end
										end
									end
								end
								if frecipe.test("cookpot", names, tags) then ok = true; break end
							end
							if ok then
								if not WIT.cook_by_ingredient[iname] then WIT.cook_by_ingredient[iname] = {} end
								local exists = false
								for _, r in ipairs(WIT.cook_by_ingredient[iname]) do
									if r.name == fname then exists = true; break end
								end
								if not exists then table.insert(WIT.cook_by_ingredient[iname], frecipe) end
							end
						end
					end
				end
				-- 4) 探测烹饪条件
				if frecipe.test and frecipe.card_def and not WIT_PROBED_CONDITIONS[fname] then
					local probed = ProbeCookCondition(frecipe)
					if probed then
						WIT_PROBED_CONDITIONS[fname] = probed
					end
				end
			end
		end
	end
end