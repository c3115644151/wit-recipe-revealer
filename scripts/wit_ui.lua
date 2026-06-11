-- wit_ui: 表现层 - 所有与 UI 渲染/交互相关的逻辑
--
-- 职责范围:
--   - 弹窗创建 + 分页 + 分类切换
--   - 物品图标槽位 + 箭头 + 卡片渲染
--   - 物品百科信息页 (Visual UI, 图鉴风格)
--   - 排序 + 跳转制作
--   - 键盘输入处理 + 弹窗关闭
--
-- 不包含任何游戏数据逻辑（数据层在 wit_core.lua）。
-- 所有函数在此文件中定义为全局，modmain.lua 直接加载。

-- ============================
-- 弹窗状态 (从 modmain.lua 移过来的 UI 专用变量)
-- ============================
-- (WIT_POPUP, WIT_NAME, WIT_MODE, WIT_CUR_CAT, WIT_PAGE,
--  WIT_AVAIL_CATS, WIT_CONTENT, WIT_TAB_BTNS, WIT_PG_TEXT,
--  WIT_PG_PREV, WIT_PG_NEXT 在 modmain.lua 中声明)

-- ============================
-- 通用辅助函数
-- ============================

function GetHoverItem()
    local hud_ent = TheInput:GetHUDEntityUnderMouse()
    if hud_ent == nil then return nil end
    return hud_ent.widget and hud_ent.widget.parent and hud_ent.widget.parent.item
end

function ClosePopup()
    if WIT_POPUP ~= nil then WIT_POPUP:Kill(); WIT_POPUP = nil end
    WIT_NAME = nil; WIT_MODE = nil; WIT_CUR_CAT = nil; WIT_PAGE = 1
    WIT_AVAIL_CATS = {}; WIT_CONTENT = nil; WIT_TAB_BTNS = {}
    WIT_PG_TEXT = nil; WIT_PG_PREV = nil; WIT_PG_NEXT = nil
    WIT_OPEN_COOKPOT = nil; WIT_COOK_CONTEXT = nil
end

-- ============================
-- 排序 + 跳转 (from wit_sort.lua)
-- ============================

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
    local bp_items = GetPlayerIngredientList() or {}
    local function match_count(r)
        if r and r.ingredients then
            local avail = {}
            for _, v in ipairs(bp_items) do
                local name = WIT_COOKING_ALIASES[v] or v
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
        local name = WIT_COOKING_ALIASES[v] or v
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
                local name = WIT_COOKING_ALIASES[ci[1]] or ci[1]
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
            r._cook_match = match_count; r._cook_pass = true
            table.insert(matched, r)
        else
            r._cook_match = match_count; r._cook_pass = false
            table.insert(unmatched, r)
        end
    end
    table.sort(matched, function(a, b)
        if (a.priority or 0) ~= (b.priority or 0) then return (a.priority or 0) > (b.priority or 0) end
        return (a._cook_match or 0) > (b._cook_match or 0)
    end)
    table.sort(unmatched, function(a, b)
        if (a._cook_match or 0) ~= (b._cook_match or 0) then return (a._cook_match or 0) > (b._cook_match or 0) end
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

-- ============================
-- 物品图标 + 箭头 (from wit_slot.lua)
-- ============================

function MakeSlot(parent, prefab, x, y, need_amount, highlight, slot_size, icon_size, _, show_count)
    if parent == nil then return end
    slot_size = slot_size or 54
    icon_size = icon_size or 54
    if show_count == nil then show_count = true end

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
            t:SetColour(not has_enough and 1 or 1, not has_enough and 0.6 or 1, not has_enough and 0.6 or 1, 1)
        end
    end

    if disp_prefab ~= nil and ThePlayer ~= nil then
        slot:SetOnClick(function()
            BuildIndexes()
            ClosePopup()
            CreatePopup(disp_prefab, "SOURCE")
        end)
        local orig_oc = slot.OnControl
        slot.OnControl = function(btn, control, down)
            if down and control == CONTROL_SECONDARY then
                BuildIndexes()
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

-- ============================
-- 卡片渲染 (from wit_render.lua)
-- ============================

function RenderCardCrafting(r, card_y)
    local ings = r.ingredients or {}
    local ing_count = math.min(#ings, 5)
    local start_x = -140
    for ii = 1, ing_count do
        local ing = ings[ii]
        local hl = (ing.type == WIT_NAME)
        MakeSlot(WIT_CONTENT, ing.type, start_x + (ii - 1) * 58, card_y, ing.amount, hl)
    end
    MakeArrow(WIT_CONTENT, start_x + ing_count * 58 - 10, card_y)
    MakeSlot(WIT_CONTENT, r.product or r.name, start_x + ing_count * 58 + 32, card_y, nil, false)

    local state = GetRecipeBuildState(r.name)
    if state ~= nil then
        local can_craft = (state == "has_ingredients" or state == "buffered" or state == "freecrafting" or state == "prototype")
        local craft_btn = WIT_CONTENT:AddChild(ImageButton("images/crafting_menu.xml", "ingredient_craft.tex", "ingredient_craft.tex"))
        if craft_btn then
            craft_btn:SetPosition(start_x + ing_count * 58 + 32 + 32, card_y - 32)
            craft_btn:SetScale(0.35)
            craft_btn.image:SetTint(can_craft and 1 or 0.5, can_craft and 1 or 0.5, can_craft and 1 or 0.5, 1)
            craft_btn:SetOnClick(function() JumpToCraft(r) end)
        end
    end
end

function RenderCardCooking(r, card_y)
    if not r.card_def or not r.card_def.ingredients then return end

    local pri = WIT_CONTENT:AddChild(Text(NEWFONT, 18))
    if pri then
        pri:SetString(WIT_TXT.PRIORITY .. (r.priority or 0))
        pri:SetPosition(130, card_y + 30)
        pri:SetColour(1, 0.88, 0.55, 1)
    end

    local conds = FormatCookCondition(r, WIT_NAME)
    if #conds > 0 then
        local ct = WIT_CONTENT:AddChild(Text(NEWFONT, 20))
        if ct then
            ct:SetString(table.concat(conds, "  "))
            ct:SetRegionSize(320, 30)
            ct:SetPosition(-44, card_y + 30)
            ct:SetHAlign(0)
            ct:SetColour(0.7, 0.65, 0.5, 1)
        end
    end

    local view = GetResolvedCookingCard(r, WIT_NAME)
    if not view then
        local raw = FlattenIngredients(r.card_def and r.card_def.ingredients)
        view = { slots = PadSlots(raw, 4), need_map = BuildNeedMap(r.card_def and r.card_def.ingredients), can_auto_cook = false }
    end

    local slot_start_x = -140
    for ii = 1, 4 do
        local hl = (view.slots[ii] == WIT_NAME)
        local need_amt = view.slots[ii] and view.need_map[view.slots[ii]] or nil
        MakeSlot(WIT_CONTENT, view.slots[ii], slot_start_x + (ii - 1) * 58, card_y - 8, need_amt, hl, nil, nil, nil, false)
    end
    MakeArrow(WIT_CONTENT, slot_start_x + 4 * 58 - 10, card_y - 8)
    MakeSlot(WIT_CONTENT, r.name, slot_start_x + 4 * 58 + 32, card_y - 8, nil, false, nil, nil, nil, false)

    local craft_btn = WIT_CONTENT:AddChild(ImageButton("images/crafting_menu.xml", "ingredient_craft.tex", "ingredient_craft.tex"))
    if craft_btn then
        craft_btn:SetPosition(slot_start_x + 4 * 58 + 32 + 32, card_y - 8 - 32)
        craft_btn:SetScale(0.35)
        craft_btn.image:SetTint(view.can_auto_cook and 1 or 0.5, view.can_auto_cook and 1 or 0.5, view.can_auto_cook and 1 or 0.5, 1)
        craft_btn:SetOnClick(function()
            if not CanAutoCook(view) then return end
            AutoFillCookPot(view)
        end)
    end
end

function RenderCards(recipes, card_h, card_spacing, render_card_fn)
    if WIT_CONTENT == nil then return end
    WIT_CONTENT:KillAllChildren()

    local total = #recipes
    local pages = math.max(1, math.ceil(total / WIT_PAGE_SIZE))
    if WIT_PAGE > pages then WIT_PAGE = 1 end
    if WIT_PAGE < 1 then WIT_PAGE = pages end
    if WIT_PG_TEXT then WIT_PG_TEXT:SetString(WIT_PAGE .. " / " .. pages) end

    local start_i = (WIT_PAGE - 1) * WIT_PAGE_SIZE + 1
    local end_i = math.min(start_i + WIT_PAGE_SIZE - 1, total)
    for idx = start_i, end_i do
        local r = recipes[idx]
        local local_i = idx - start_i
        local card_y = -local_i * card_spacing + 25
        local card_bg = WIT_CONTENT:AddChild(Image("images/global.xml", "square.tex"))
        if card_bg then card_bg:SetSize(370, card_h); card_bg:SetTint(0.12, 0.10, 0.08, 0.6); card_bg:SetPosition(0, card_y) end
        render_card_fn(r, card_y)
    end
end

-- ============================
-- 分类切换 + 配方获取 (from wit_category.lua)
-- ============================

function HasData(name, mode)
    if mode == "SOURCE" then
        return (WIT.by_product[name] and #WIT.by_product[name] > 0) or (WIT.cook_foods[name] ~= nil)
    else
        local has_mat = WIT.by_material[name] and #WIT.by_material[name] > 0
        local has_cook = WIT.cook_by_ingredient[name] and #WIT.cook_by_ingredient[name] > 0
        return has_mat or has_cook
    end
end

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

    -- INFO 页签隐藏翻页控件
    if WIT_PG_PREV then
        if cat == "INFO" then
            WIT_PG_PREV:Hide(); WIT_PG_NEXT:Hide(); WIT_PG_TEXT:Hide()
        else
            WIT_PG_PREV:Show(); WIT_PG_NEXT:Show(); WIT_PG_TEXT:Show()
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
        table.sort(filtered, function(a, b)
            local va, vb = a._cook_view, b._cook_view
            local function GetMissingCount(view)
                if not view or not view.slots then return 4 end
                local missing = 0
                for i = 1, 4 do
                    local s = view.slots[i]
                    if s == nil then
                        missing = missing + 1
                    else
                        local need_amt = view.need_map and view.need_map[s] or 1
                        if (inv_counts[s] or 0) < need_amt then missing = missing + 1 end
                    end
                end
                return missing
            end
            local gap_a, gap_b = GetMissingCount(va), GetMissingCount(vb)
            local tier_a = va and va.can_auto_cook and 0 or (gap_a == 0 and 1 or 2)
            local tier_b = vb and vb.can_auto_cook and 0 or (gap_b == 0 and 1 or 2)
            if tier_a ~= tier_b then return tier_a < tier_b end
            if tier_a == 2 and gap_a ~= gap_b then return gap_a < gap_b end
            return (a.priority or 0) > (b.priority or 0)
        end)
        recipes = filtered
    end
    -- 每次切标签都清空并重建内容容器
    if WIT_POPUP and WIT_CONTENT then WIT_CONTENT:Kill(); WIT_CONTENT = nil end
    if WIT_POPUP then
        WIT_CONTENT = WIT_POPUP:AddChild(Widget("c"))
        if WIT_CONTENT then WIT_CONTENT:SetPosition(0, 20) end
    end
    if cat == "CRAFTING" then
        RenderCards(recipes, 85, 90, RenderCardCrafting)
    elseif cat == "COOKING" then
        RenderCards(recipes, 85, 90, RenderCardCooking)
    elseif cat == "INFO" then
        RenderItemInfo()
    end
end

-- ============================
-- 弹窗创建 (from wit_popup.lua)
-- ============================

function CreatePopup(name, mode)
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
    table.insert(avail_cats, "INFO")
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
    local frame_w = 360; local frame_h = 480

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
            local label = cat == "CRAFTING" and WIT_TXT.TAB_CRAFTING or (cat == "COOKING" and WIT_TXT.TAB_COOKING or WIT_TXT.TAB_INFO)
            tb:SetText(label); tb:SetTextSize(26)
            tb:SetPosition((i - (#WIT_AVAIL_CATS + 1) / 2) * 100, tab_y)
            tb:SetOnClick(function() SelectCategory(cat, true) end)
            WIT_TAB_BTNS[cat] = tb
        end
    end

    WIT_CONTENT = WIT_POPUP:AddChild(Widget("c"))
    if WIT_CONTENT then WIT_CONTENT:SetPosition(0, 20) end

    local pg_y = -210
    WIT_PG_PREV = WIT_POPUP:AddChild(ImageButton(CRAFTING_ATLAS, "scrollbar_arrow_down.tex", "scrollbar_arrow_down_hl.tex"))
    if WIT_PG_PREV then
        WIT_PG_PREV:SetScale(0.4); WIT_PG_PREV:SetPosition(-40, pg_y); WIT_PG_PREV:SetRotation(90)
        WIT_PG_PREV:SetOnClick(function() WIT_PAGE = WIT_PAGE - 1; SelectCategory(WIT_CUR_CAT, false) end)
    end

    WIT_PG_TEXT = WIT_POPUP:AddChild(Text(NEWFONT, 20))
    if WIT_PG_TEXT then WIT_PG_TEXT:SetString("1 / 1"); WIT_PG_TEXT:SetPosition(0, pg_y); WIT_PG_TEXT:SetColour(0.85, 0.78, 0.65, 1) end

    WIT_PG_NEXT = WIT_POPUP:AddChild(ImageButton(CRAFTING_ATLAS, "scrollbar_arrow_down.tex", "scrollbar_arrow_down_hl.tex"))
    if WIT_PG_NEXT then
        WIT_PG_NEXT:SetScale(0.4); WIT_PG_NEXT:SetPosition(40, pg_y); WIT_PG_NEXT:SetRotation(-90)
        WIT_PG_NEXT:SetOnClick(function() WIT_PAGE = WIT_PAGE + 1; SelectCategory(WIT_CUR_CAT, false) end)
    end
    SelectCategory(WIT_AVAIL_CATS[1], true)
end

-- ============================
-- 键盘输入处理 (from wit_input.lua)
-- ============================

TheInput.onkeydown:AddEventHandler(WIT_KEY_R, function()
    local ok, e = pcall(function()
        if ThePlayer == nil then return end
        if TheFrontEnd and TheFrontEnd.textProcessorWidget then return end
        if ThePlayer.components.playercontroller ~= nil and ThePlayer.components.playercontroller.placer ~= nil then return end
        local item = GetHoverItem()
        if item == nil then
            if WIT_POPUP ~= nil then ClosePopup() end
            return
        end
        local name = item.prefab or "unknown"
        BuildIndexes()
        if WIT_POPUP ~= nil then
            if WIT_NAME == name and WIT_MODE == "SOURCE" then ClosePopup(); return end
            ClosePopup()
        end
        CreatePopup(name, "SOURCE")
    end)
    if not ok then print("[WIT] R:", e) end
end)

TheInput.onkeydown:AddEventHandler(WIT_KEY_U, function()
    local ok, e = pcall(function()
        if ThePlayer == nil then return end
        if TheFrontEnd and TheFrontEnd.textProcessorWidget then return end
        local item = GetHoverItem()
        if item == nil then
            if WIT_POPUP ~= nil then ClosePopup() end
            return
        end
        local name = item.prefab or "unknown"
        BuildIndexes()
        if WIT_POPUP ~= nil then
            if WIT_NAME == name and WIT_MODE == "USE" then ClosePopup(); return end
            ClosePopup()
        end
        CreatePopup(name, "USE")
    end)
    if not ok then print("[WIT] U:", e) end
end)

-- ============================
-- 物品信息页渲染 (from wit_iteminfo_render.lua)
-- ============================

local ICON_SIZE = 56
local FONT_SIZE = 24
local START_Y = 65
local ROW_H = 68
local CARD_W = 370
local PADDING = 14

local function _ResolveAtlas(icon)
    local function try_one(name)
        if GLOBAL.GetScrapbookIconAtlas then
            local a = GLOBAL.GetScrapbookIconAtlas(name)
            if a then return a end
        end
        local atlases = {"images/scrapbook_icons1.xml", "images/scrapbook_icons2.xml", "images/scrapbook_icons3.xml"}
        for _, a in ipairs(atlases) do
            if GLOBAL.TheSim:AtlasContains(a, name) then return a end
        end
        local ia = GLOBAL.GetInventoryItemAtlas(name)
        if ia then return ia end
        return nil
    end
    local atlas = try_one(icon)
    if atlas then return atlas end
    local base = icon:match("^(.+)%.tex$")
    if base then
        atlas = try_one(base)
        if atlas then return atlas end
    end
    return nil
end

local function _fmt_num(v)
    if v == nil then return "0" end
    if v == math.floor(v) then return tostring(math.floor(v)):gsub("^-", "－") end
    return (string.format("%.1f", v)):gsub("^-", "－")
end

local function _fmt_time(seconds)
    if seconds == nil then return "?" end
    if seconds >= 480 then
        local d = seconds / 480
        if d == math.floor(d) then return math.floor(d) .. "d" end
        return string.format("%.1f", d) .. "d"
    else
        return math.floor(seconds) .. "s"
    end
end

local function _GetTooltip(icon)
    if not WIT_TXT or not WIT_TXT.ICON_TOOLTIPS then return nil end
    local key = icon:match("^(.+)%.tex$") or icon
    return WIT_TXT.ICON_TOOLTIPS[key]
end

function RenderItemInfo()
    if WIT_CONTENT == nil then return end
    WIT_CONTENT:KillAllChildren()

    local info = GetItemInfo and GetItemInfo(WIT_NAME)
    if not info or next(info) == nil then
        local t = WIT_CONTENT:AddChild(GLOBAL.Text(GLOBAL.NEWFONT, 24))
        if t then t:SetString(WIT_TXT.NO_INFO); t:SetPosition(0, 10); t:SetColour(0.6, 0.55, 0.4, 1) end
        return
    end

    local current_y = START_Y

    local function _RenderGroupCard(blocks)
        if #blocks == 0 then return end
        local MIN_X = -CARD_W/2 + 20
        local MAX_X = CARD_W/2 - 20
        local cx = MIN_X
        local row = 1
        local layouts = {}
        for _, b in ipairs(blocks) do
            local atlas = _ResolveAtlas(b.icon)
            local dummy = GLOBAL.Text(GLOBAL.NEWFONT, FONT_SIZE)
            dummy:SetString(b.text)
            local tw, th = dummy:GetRegionSize()
            dummy:Kill()
            local has_icon = atlas ~= nil
            local bw = has_icon and (ICON_SIZE + 10 + tw) or (tw + 24)
            if cx + bw > MAX_X then cx = MIN_X; row = row + 1 end
            table.insert(layouts, {b=b, atlas=atlas, tw=tw, bw=bw, cx=cx, row=row, has_icon=has_icon})
            cx = cx + bw + 12
        end
        if #layouts == 0 then return end
        local card_h = row * ROW_H + PADDING * 2
        local group = GLOBAL.Widget("info_card")
        WIT_CONTENT:AddChild(group)
        local bg = group:AddChild(GLOBAL.Image("images/global.xml", "square.tex"))
        bg:SetSize(CARD_W, card_h); bg:SetTint(0.12, 0.10, 0.08, 0.7); bg:MoveToBack()
        for _, l in ipairs(layouts) do
            local cy = card_h/2 - PADDING - ROW_H/2 - (l.row - 1) * ROW_H
            local w = group:AddChild(GLOBAL.Widget("block"))
            w:SetPosition(l.cx + l.bw/2, cy)
            local icon_x = -l.bw/2
            if l.has_icon then
                local img = w:AddChild(GLOBAL.Image(l.atlas, l.b.icon))
                img:ScaleToSize(ICON_SIZE, ICON_SIZE)
                img:SetPosition(icon_x + ICON_SIZE/2, 0)
                local tip = l.b.tip or _GetTooltip(l.b.icon)
                if tip then w:SetTooltip(tip) end
                local txt_w = w:AddChild(GLOBAL.Text(GLOBAL.NEWFONT, FONT_SIZE))
                txt_w:SetString(l.b.text)
                txt_w:SetColour(0.85, 0.78, 0.65, 1)
                txt_w:SetPosition(icon_x + ICON_SIZE + 10 + l.tw/2, 0)
            else
                -- Text-only pill for unresolvable icons
                local pill = w:AddChild(GLOBAL.Image("images/global.xml", "square.tex"))
                pill:SetSize(l.bw, ROW_H - 8)
                pill:SetTint(0.25, 0.22, 0.18, 0.8)
                local txt_w = w:AddChild(GLOBAL.Text(GLOBAL.NEWFONT, FONT_SIZE))
                txt_w:SetString(l.b.text)
                txt_w:SetColour(0.85, 0.78, 0.65, 1)
                if l.b.tip then txt_w:SetTooltip(l.b.tip) end
            end
        end
        group:SetPosition(0, current_y - card_h/2)
        current_y = current_y - card_h - 12
    end

    local blocks = {}

    -- 分组 1：食用与恢复
    if info.edible then
        local hg = info.edible.hunger or 0
        local hl = info.edible.health or 0
        local sn = info.edible.sanity or 0
        table.insert(blocks, {icon="icon_hunger.tex", text=(hg > 0 and "＋" or "") .. _fmt_num(hg)})
        table.insert(blocks, {icon="icon_health.tex", text=(hl > 0 and "＋" or "") .. _fmt_num(hl)})
        table.insert(blocks, {icon="icon_sanity.tex", text=(sn > 0 and "＋" or "") .. _fmt_num(sn)})
        
        if info.edible.foodtype and info.edible.foodtype ~= "GENERIC" then
            local ft = tostring(info.edible.foodtype)
            local ft_name = GLOBAL.STRINGS.SCRAPBOOK ~= nil and GLOBAL.STRINGS.SCRAPBOOK.FOODTYPE and GLOBAL.STRINGS.SCRAPBOOK.FOODTYPE[ft]
            if ft_name == nil and WIT_TXT.FOODTYPE_NAMES then
                ft_name = WIT_TXT.FOODTYPE_NAMES[ft]
            end
            table.insert(blocks, {icon="icon_food.tex", text=ft_name or ft})
        end
        if info.edible.temperaturedelta and info.edible.temperaturedelta ~= 0 then
            local icon = info.edible.temperaturedelta > 0 and "icon_heat.tex" or "icon_cold.tex"
            local txt = _fmt_num(info.edible.temperaturedelta) .. "°C"
            if info.edible.temperatureduration then txt = txt .. " / " .. _fmt_num(info.edible.temperatureduration) .. "s" end
            local tip_suffix = info.edible.temperaturedelta > 0 and "升温" or "降温"
            table.insert(blocks, {icon=icon, text=txt, tip=tip_suffix .. "量 / 持续时间"})
        end
    end
    if info.healer then
        table.insert(blocks, {icon="icon_health.tex", text="＋" .. _fmt_num(info.healer.health)})
    end
    _RenderGroupCard(blocks)

    -- 分组 2：战斗与装备
    blocks = {}
    if info.weapon then
        local txt = tostring(info.weapon.damage)
        local tip = "攻击伤害"
        if info.weapon.attackrange and info.weapon.attackrange > 1 then
            txt = txt .. " / " .. info.weapon.attackrange
            tip = tip .. " / 攻击范围"
        end
        table.insert(blocks, {icon="icon_damage.tex", text=txt, tip=tip})
    end
    if info.armor then
        local absorb = info.armor.absorb_percent and math.floor(info.armor.absorb_percent * 100) .. "%" or "?"
        table.insert(blocks, {icon="icon_armor.tex", text=absorb})
        if info.armor.maxcondition then table.insert(blocks, {icon="icon_uses.tex", text=tostring(info.armor.maxcondition)}) end
    end
    if info.equippable then
        if info.equippable.equipslot then
            local slot_txt = tostring(info.equippable.equipslot)
            if WIT_TXT.EQUIPSLOT_NAMES and WIT_TXT.EQUIPSLOT_NAMES[slot_txt] then
                slot_txt = WIT_TXT.EQUIPSLOT_NAMES[slot_txt]
            end
            table.insert(blocks, {icon="icon_clothing.tex", text=slot_txt})
        end
        if info.equippable.walkspeedmult and info.equippable.walkspeedmult ~= 1 then
            table.insert(blocks, {icon="cane.tex", text="x " .. string.format("%.2f", info.equippable.walkspeedmult)})
        end
        if info.equippable.dapperness and info.equippable.dapperness ~= 0 then
            local dpm = info.equippable.dapperness * 60
            local sign = dpm > 0 and "＋" or ""
            table.insert(blocks, {icon="icon_sanity.tex", text=sign .. string.format("%.2f/min", dpm), tip="装备时理智变化（/分钟）"})
        end
    end
    if info.sanityaura and info.sanityaura.aura and info.sanityaura.aura ~= 0 then
        local apm = info.sanityaura.aura * 60
        local sign = apm > 0 and "＋" or ""
        table.insert(blocks, {icon="icon_sanity.tex", text=sign .. string.format("%.2f/min", apm), tip="附近时理智光环（/分钟）"})
    end
    _RenderGroupCard(blocks)

    -- 分组 3：工具与耐久
    blocks = {}
    if info.tools and #info.tools > 0 then
        for _, t in ipairs(info.tools) do
            local eff = t.efficiency or 1
            local txt = CN(t.action) .. "x " .. _fmt_num(eff)
            table.insert(blocks, {icon="icon_action.tex", text=txt, tip="工具效率倍率"})
        end
    end
    if info.finiteuses then table.insert(blocks, {icon="icon_uses.tex", text=tostring(info.finiteuses.maxuses)}) end
    _RenderGroupCard(blocks)

    -- 分组 4：杂项特性
    blocks = {}
    if info.perishable then
        table.insert(blocks, {icon="icon_spoil.tex", text=_fmt_time(info.perishable.perishtime), tip="腐烂时间"})
    end
    if info.burnable then
        table.insert(blocks, {icon="icon_burnable.tex", text=_fmt_time(info.burnable.burntime), tip="作为燃料时燃烧时长"})
    end
    if info.fueled then
        local tip = (info.fueled.fueltype == "USAGE") and "装备磨损耐久" or "燃料时长"
        table.insert(blocks, {icon="icon_fuel.tex", text=_fmt_time(info.fueled.maxfuel), tip=tip})
    end
    if info.sewable then table.insert(blocks, {icon="icon_sewingkit.tex", text=WIT_TXT.SEWABLE, tip="可使用缝纫包修复"}) end
    if info.waterproofer then
        local pct = math.floor((info.waterproofer.effectiveness or 0) * 100)
        table.insert(blocks, {icon="icon_wetness.tex", text=pct .. "%", tip="防水效果百分比"})
    end
    if info.insulator then
        local icon = info.insulator.type == GLOBAL.SEASONS.SUMMER and "icon_heat.tex" or "icon_cold.tex"
        local tip = info.insulator.type == GLOBAL.SEASONS.SUMMER and "隔热时长（夏季）" or "保暖时长（冬季）"
        table.insert(blocks, {icon=icon, text=math.floor(info.insulator.insulation or 0) .. "s", tip=tip})
    end
    if info.stackable and info.stackable.maxsize and info.stackable.maxsize > 1 then
        table.insert(blocks, {icon="icon_stack.tex", text="x " .. info.stackable.maxsize})
    end
    if info.tradable and info.tradable.goldvalue and info.tradable.goldvalue > 0 then
        table.insert(blocks, {icon="goldnugget.tex", text=tostring(info.tradable.goldvalue)})
    end
    if info.repairable then
        if info.repairable.repairmaterial then
            local mat_name = CN(info.repairable.repairmaterial)
            -- icon_wrench.tex is confirmed to exist in scrapbook_icons1.xml
            table.insert(blocks, {icon="icon_wrench.tex", text=mat_name, tip="可使用该材料修复"})
        elseif info.repairable.repairitems and #info.repairable.repairitems > 0 then
            local mat_name = CN(info.repairable.repairitems[1])
            table.insert(blocks, {icon="icon_wrench.tex", text=mat_name, tip="可使用该材料修复"})
        else
            table.insert(blocks, {icon="icon_wrench.tex", text=WIT_TXT.REPAIRABLE, tip="可修复"})
        end
    end
    _RenderGroupCard(blocks)

    -- 标签与注释行
    local bottom_texts = {}
    if info.edible and info.edible.player_can_eat == false then
        if info.edible.eater_hint then
            table.insert(bottom_texts, "可被 " .. info.edible.eater_hint .. " 食用")
        else
            table.insert(bottom_texts, "非玩家可食用")
        end
    end

    if info.tags and #info.tags > 0 then
        local tag_str = ""
        local count = 0
        for _, tag in ipairs(info.tags) do
            if not tag:match("^_") and not tag:match("^edible_") and not tag:match("^fx") then
                if count > 0 then tag_str = tag_str .. "  " end
                tag_str = tag_str .. "[" .. CN(tag) .. "]"
                count = count + 1
                if count >= 6 then break end
            end
        end
        if #tag_str > 0 then table.insert(bottom_texts, tag_str) end
    end

    for i, txt in ipairs(bottom_texts) do
        local t = WIT_CONTENT:AddChild(GLOBAL.Text(GLOBAL.NEWFONT, 18))
        if t then
            t:SetString(txt)
            t:SetPosition(0, current_y - 10 - (i - 1) * 22)
            t:SetColour(0.55, 0.5, 0.4, 1)
        end
    end
end
