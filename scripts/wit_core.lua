-- wit_core: 数据层 - 所有与游戏状态/数据相关的逻辑
--
-- 职责范围:
--   - 玩家库存统一访问
--   - 配方/烹饪索引构建
--   - 客户端物品属性采集 (Pure Client-side Hack)
--   - 烹饪卡片求解器 (注入/替换/自动烹饪判定)
--   - 烹饪条件探测 + 格式化
--   - 烹饪上下文管理 (快照/缓存)
--
-- 不包含任何 UI 渲染代码。所有函数在此文件中定义为全局，
-- 上层 wit_ui.lua 或 modmain.lua 直接调用。

WIT_COOKING_ALIASES = { cookedsmallmeat = "smallmeat_cooked", cookedmonstermeat = "monstermeat_cooked", cookedmeat = "meat_cooked" }
WIT_INGREDIENT_PREFAB_MAP = { egg = "bird_egg" }

-- ============================
-- 统一库存遍历 (消除 3 份重复)
-- ============================

-- 低阶迭代器：遍历主背包 + 溢出背包，对每个物品执行 callback
-- callback(item, container_entity) 返回 true 则提前终止
local function _IterateInventory(callback)
    if ThePlayer == nil or ThePlayer.replica == nil then return end
    local inv = ThePlayer.replica.inventory
    if inv == nil then return end

    local classified = inv.classified
    if classified == nil or classified.GetItems == nil then return end

    local items = classified:GetItems()
    for _, item in pairs(items) do
        if callback(item, ThePlayer) then return end
    end

    local overflow = inv:GetOverflowContainer()
    if overflow ~= nil and overflow.classified ~= nil and overflow.classified.GetItems ~= nil then
        local oitems = overflow.classified:GetItems()
        for _, item in pairs(oitems) do
            if callback(item, overflow.inst) then return end
        end
    end
end

-- 统计玩家库存中某物品总数
function CountPlayerItem(prefab)
    local count = 0
    _IterateInventory(function(item)
        if item.prefab == prefab then
            local stack = item.replica.stackable
            count = count + (stack and stack:StackSize() or 1)
        end
    end)
    return count
end

-- 拉平背包食材列表（自动烹饪用，同物品最多 4 个）
function GetPlayerIngredientList()
    local list = {}
    _IterateInventory(function(item)
        if item.replica.inventoryitem then
            local stackable = item.replica.stackable
            local cnt = stackable and stackable:StackSize() or 1
            for _ = 1, math.min(cnt, 4) do
                table.insert(list, item.prefab)
            end
        end
    end)
    return list
end

-- 在库存中查找某物品的槽位
function FindItemSlotInInventory(prefab)
    local found_slot, found_owner = nil, nil
    _IterateInventory(function(item, owner)
        if item.prefab == prefab then
            found_owner = owner
            return true  -- 提前终止
        end
    end)
    return found_slot, found_owner
end

-- ============================
-- 烹饪食材 tag/name 累加 (消除 3 份重复)
-- ============================

local cooking_cache = nil
local function _GetCooking()
    if cooking_cache == nil then
        cooking_cache = GLOBAL.require("cooking")
    end
    return cooking_cache
end

-- 将预制件名（带 alias 解析）累加到 names/tags 表中
local function _AccumulateIngredient(name, count, names, tags)
    local resolved = WIT_COOKING_ALIASES[name] or name
    names[resolved] = (names[resolved] or 0) + count
    local cooking = _GetCooking()
    local data = cooking and cooking.ingredients and cooking.ingredients[resolved]
    if data then
        for kk, vv in pairs(data.tags) do
            tags[kk] = (tags[kk] or 0) + vv * count
        end
    end
end

-- 主力：从原始食材列表构建模拟输入 (names + tags)
function BuildSimInput(slot_list, slot_override)
    local sim_names, sim_tags = {}, {}
    for ii, ing in ipairs(slot_list) do
        local name = slot_override and slot_override[ii] or ing
        _AccumulateIngredient(name, 1, sim_names, sim_tags)
    end
    return sim_names, sim_tags
end

-- 基础工具函数
function FlattenIngredients(ingredients)
    local list = {}
    if not ingredients then return list end
    for _, ci in ipairs(ingredients) do
        for _ = 1, ci[2] do
            table.insert(list, ci[1])
        end
    end
    return list
end

function BuildNeedMap(ingredients)
    local map = {}
    if not ingredients then return map end
    for _, ci in ipairs(ingredients) do
        map[ci[1]] = (map[ci[1]] or 0) + ci[2]
    end
    return map
end

function PadSlots(slots, count)
    while #slots < count do
        table.insert(slots, nil)
    end
    return slots
end

-- ============================
-- 索引构建 (from wit_build.lua)
-- ============================

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

function GenerateCardDef(recipe, cooking)
    if not recipe.test or not cooking or not cooking.ingredients then return nil end

    local fillers = {"berries", "ice", "twigs", "carrot", "corn", "red_cap", "honey"}
    local pool = {}
    for name, _ in pairs(cooking.ingredients) do
        if not name:match("_cooked$") and not name:match("_dried$") then
            table.insert(pool, name)
        end
    end
    -- 1: 单种食材 x4
    for _, name in ipairs(pool) do
        local names, tags = {[name]=4}, {}
        _AccumulateIngredient(name, 4, names, tags)
        if recipe.test("cookpot", names, tags) then
            return {ingredients = {{name, 4}}}
        end
    end
    -- 2: 1 主料 + 3 填充
    for _, name in ipairs(pool) do
        for _, filler in ipairs(fillers) do
            if filler ~= name then
                local names, tags = {}, {}
                _AccumulateIngredient(name, 1, names, tags)
                _AccumulateIngredient(filler, 3, names, tags)
                if recipe.test("cookpot", names, tags) then
                    return {ingredients = {{name, 1}, {filler, 3}}}
                end
            end
        end
    end
    -- 3: 两两组合
    for idx1 = 1, #pool do
        for idx2 = idx1, #pool do
            local a, b = pool[idx1], pool[idx2]
            local names, tags = {}, {}
            _AccumulateIngredient(a, 2, names, tags)
            _AccumulateIngredient(b, 2, names, tags)
            if recipe.test("cookpot", names, tags) then
                return {ingredients = {{a, 2}, {b, 2}}}
            end
        end
    end
    return nil
end

-- ============================
-- 按键配置：持久化重绑定
-- ============================

WIT_KEYS = {
    R = GetModConfigData("KEY_R") or 114,
    U = GetModConfigData("KEY_U") or 117,
}
WIT_REBINDING = nil  -- { action = "R" } when waiting for keypress

local function _SavePath() return "WIT_keybind" end

function LoadKeyOverrides()
    local ok, str = pcall(TheSim.GetPersistentString, TheSim, _SavePath())
    if not ok or str == nil or str == "" then return end
    local ok2, data = pcall(json.decode, str)
    if ok2 and type(data) == "table" then
        if data.R then WIT_KEYS.R = data.R end
        if data.U then WIT_KEYS.U = data.U end
    end
end

function SaveKeyOverrides()
    pcall(TheSim.SetPersistentString, TheSim, _SavePath(), json.encode(WIT_KEYS))
end

function StartRebinding(action, on_complete)
    WIT_REBINDING = { action = action, on_complete = on_complete }
end

function CompleteRebinding(keycode)
    if not WIT_REBINDING then return end
    local action = WIT_REBINDING.action
    local on_complete = WIT_REBINDING.on_complete
    WIT_REBINDING = nil
    if keycode == 27 then  -- ESC 取消
        if on_complete then on_complete(nil) end
        return
    end
    WIT_KEYS[action] = keycode
    SaveKeyOverrides()
    if on_complete then on_complete(keycode) end
end

-- 完整按键名称映射表（Free key binding 用）
WIT_KEY_NAMES = {}
local function _InitKeyNames()
    local t = {}
    for i = 97, 122 do t[i] = string.char(i - 32) end  -- a-z → A-Z
    for i = 48, 57 do t[i] = string.char(i) end           -- 0-9
    t[32] = "SPACE"; t[13] = "ENTER"; t[27] = "ESC"; t[9] = "TAB"
    t[8] = "BACK"; t[127] = "DEL"; t[277] = "INS"
    t[273] = "↑"; t[274] = "↓"; t[275] = "←"; t[276] = "→"
    t[268] = "HOME"; t[269] = "END"; t[280] = "PGUP"; t[281] = "PGDN"
    for i = 282, 293 do t[i] = "F" .. (i - 281) end  -- F1-F12
    t[304] = "LSHIFT"; t[303] = "RSHIFT"; t[306] = "LCTRL"; t[305] = "RCTRL"
    t[308] = "LALT"; t[307] = "RALT"
    t[44] = ","; t[46] = "."; t[47] = "/"; t[59] = ";"; t[39] = "'"
    t[91] = "["; t[93] = "]"; t[92] = "\\"; t[45] = "-"; t[61] = "="
    t[192] = "~"; t[107] = "KP+"; t[106] = "KP*"; t[111] = "KP/"
    t[109] = "KP-"; t[110] = "KP."; t[269] = "KP0"
    WIT_KEY_NAMES = t
end
_InitKeyNames()

function KeyName(code)
    return code and (WIT_KEY_NAMES[code] or string.char(code) or "?") or "?"
end

-- 加载持久化覆盖
LoadKeyOverrides()

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
    local cooking = _GetCooking()
    if cooking ~= nil then
        for _, recipes in pairs(cooking.cookbook_recipes or {}) do
            for fname, frecipe in pairs(recipes) do
                WIT.cook_foods[fname] = frecipe
            end
        end
        for iname, idata in pairs(cooking.ingredients or {}) do
            WIT.ingredient_tags[iname] = idata.tags
        end
        for _, cooker_type in ipairs({"cookpot", "portablecookpot"}) do
            for fname, frecipe in pairs(cooking.recipes[cooker_type] or {}) do
                if frecipe.test and not frecipe.card_def then
                    frecipe.card_def = FALLBACK_CARD_DEF[fname]
                end
                if frecipe.test and not frecipe.card_def then
                    frecipe.card_def = GenerateCardDef(frecipe, cooking)
                end
                if not WIT.cook_foods[fname] then
                    WIT.cook_foods[fname] = frecipe
                end
                if frecipe.test and frecipe.card_def and frecipe.card_def.ingredients then
                    for iname, _ in pairs(cooking.ingredients or {}) do
                        local item_tags = WIT.ingredient_tags[iname]
                        if item_tags then
                            for slot_idx = 1, #frecipe.card_def.ingredients do
                                local names, tags = {}, {}
                                for j, ci in ipairs(frecipe.card_def.ingredients) do
                                    local n = ci[1]
                                    if j == slot_idx then n = iname end
                                    _AccumulateIngredient(n, ci[2], names, tags)
                                end
                                if frecipe.test("cookpot", names, tags) then
                                    WIT.cook_by_ingredient[iname] = WIT.cook_by_ingredient[iname] or {}
                                    local exists = false
                                    for _, r in ipairs(WIT.cook_by_ingredient[iname]) do
                                        if r.name == fname then exists = true; break end
                                    end
                                    if not exists then table.insert(WIT.cook_by_ingredient[iname], frecipe) end
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ============================
-- 烹饪条件格式化（仅使用硬编码表，源自 wiki 数据）
-- ============================

-- 硬编码烹饪条件表
local HARDCODED_CONDITIONS = {
    ["baconeggs"] = {{"meat",">1.0"}, {"egg",">1.0"}, {"veggie","=="}},
    ["bananajuice"] = {{"cave_banana","×2"}},
    ["barnaclepita"] = {{"barnacle","+1"}, {"veggie","≥0.5"}},
    ["barnaclesushi"] = {{"barnacle","+1"}, {"kelp","+1"}, {"egg",">0"}},
    ["barnaclinguine"] = {{"barnacle","×2"}, {"veggie","≥2.0"}},
    ["bananapop"] = {{"cave_banana","+1"}, {"ice","+1"}, {"twigs","+1"}},
    ["barnaclestuffedfishhead"] = {{"barnacle","+1"}, {"fish","≥1.25"}},
    ["batnosehat"] = {{"batnose","+1"}, {"kelp","+1"}, {"dairy","≥1.0"}},
    ["beefalofeed"] = {{"inedible",">0"}, {"seed","≥1"}, {"forgetmelots","+1"}},
    ["beefalotreat"] = {{"acorn","+1"}, {"inedible",">0"}, {"forgetmelots","+1"}},
    ["bonestew"] = {{"meat","≥3.0"}},
    ["bunnystew"] = {{"meat",">0"}, {"frozen","≥2"}},
    ["butterflymuffin"] = {{"butterflywings","+1"}, {"veggie","≥0.5"}},
    ["californiaroll"] = {{"seaweed","+2"}, {"fish","≥1.0"}},
    ["dragonpie"] = {{"dragonfruit","+1"}},
    ["figkabab"] = {{"fig","+1"}, {"meat","≥1.0"}, {"twigs","+1"}},
    ["fishtacos"] = {{"corn","+1"}, {"fish","≥0.25"}},
    ["fishsticks"] = {{"fish",">0"}, {"twigs","×1.0"}},
    ["flowersalad"] = {{"cactus_flower","+1"}, {"veggie","≥2.0"}},
    ["frogglebunwich"] = {{"froglegs","+1"}, {"veggie","≥0.5"}},
    ["fruitmedley"] = {{"fruit","≥3.0"}},
    ["guacamole"] = {{"cactus_flower","+1"}, {"veggie","≥0.5"}},
    ["honeyham"] = {{"honey","+1"}, {"meat",">1.5"}},
    ["honeynuggets"] = {{"honey","+1"}, {"meat",">0"}},
    ["hotchili"] = {{"pepper","+1"}, {"meat","≥1.0"}},
    ["icecream"] = {{"ice","+1"}, {"dairy","≥1.0"}, {"sweetener","≥1.0"}},
    ["jammypreserves"] = {{"fruit",">0"}},
    ["jellybean"] = {{"royal_jelly","+1"}},
    ["justeggs"] = {{"egg","≥3.0"}},
    ["kabobs"] = {{"meat",">0"}, {"twigs","+1"}},
    ["koalefig_trunk"] = {{"trunk_summer","+1"}, {"fig","+1"}},
    ["leafloaf"] = {{"plantmeat","×2"}},
    ["leafymeatburger"] = {{"plantmeat","+1"}, {"onion","+1"}, {"veggie","≥2.0"}},
    ["leafymeatsouffle"] = {{"plantmeat","×2"}, {"sweetener","≥2.0"}},
    ["lobsterbisque"] = {{"wobster_sheller_land","+1"}, {"ice","+1"}},
    ["lobsterdinner"] = {{"wobster_sheller_land","+1"}, {"butter","+1"}},
    ["mandrakesoup"] = {{"mandrake","+1"}},
    ["mashedpotatoes"] = {{"potato","×2"}, {"garlic","+1"}},
    ["meatballs"] = {{"meat",">0"}},
    ["meatysalad"] = {{"plantmeat","+1"}, {"veggie","≥3.0"}},
    ["monsterlasagna"] = {{"monstermeat","×2"}},
    ["pepperpopper"] = {{"pepper","+1"}, {"meat","≥1.0"}},
    ["perogies"] = {{"egg",">0"}, {"meat",">0"}, {"veggie",">0"}},
    ["potatotornado"] = {{"potato","+1"}, {"twigs","+1"}},
    ["powcake"] = {{"twigs","+1"}, {"honey","+1"}, {"corn","+1"}},
    ["pumpkincookie"] = {{"pumpkin","+1"}, {"sweetener","≥2.0"}},
    ["ratatouille"] = {{"veggie","≥0.5"}},
    ["salsa"] = {{"tomato","+1"}, {"onion","+1"}},
    ["shroomcake"] = {{"moon_cap","+1"}, {"red_cap","+1"}, {"blue_cap","+1"}, {"green_cap","+1"}},
    ["stuffedeggplant"] = {{"eggplant","+1"}, {"veggie",">1.0"}},
    ["surfnturf"] = {{"meat","≥2.5"}, {"fish","≥1.5"}},
    ["sweettea"] = {{"honey","+1"}, {"ice","+1"}},
    ["taffy"] = {{"sweetener","≥3.0"}},
    ["trailmix"] = {{"berries","+1"}, {"fruit","≥0.5"}},
    ["turkeydinner"] = {{"drumstick","×2"}, {"meat",">1.0"}},
    ["unagi"] = {{"eel","+1"}, {"cutlichen","+1"}},
    ["vegstinger"] = {{"asparagus","+1"}, {"tomato","+1"}, {"veggie",">2.0"}, {"frozen","≥1.0"}},
    ["waffles"] = {{"butter","+1"}, {"egg",">0"}, {"berries","+1"}},
    ["watermelonicle"] = {{"watermelon","+1"}, {"ice","+1"}, {"twigs","+1"}},
    ["frognewton"] = {{"fig","+1"}, {"froglegs","+1"}},
    ["figatoni"] = {{"fig","+1"}, {"veggie","≥2.0"}},
    ["frozenbananadaiquiri"] = {{"cave_banana","+1"}, {"frozen","≥1.0"}},
    ["asparagussoup"] = {{"asparagus","+1"}, {"veggie","≥1.5"}},
    ["ceviche"] = {{"ice","+1"}, {"fish","≥2.0"}},
    ["seafoodgumbo"] = {{"fish",">2.0"}},
    ["talleggs"] = {{"tallbirdegg","+1"}, {"veggie","≥1.0"}},
    ["veggieomlet"] = {{"egg","≥1.0"}, {"veggie","≥1.0"}},
    ["wetgoop"] = {{}},
    ["dustmeringue"] = {{"refined_dust","+1"}},
    ["shroombait"] = {{"moon_cap","≥2"}, {"monstermeat","+1"}},
    -- 沃利便携锅专属
    ["voltgoatjelly"] = {{"sweetener","≥2"}},
    ["glowberrymousse"] = {{"fruit","≥2"}},
    ["frogfishbowl"] = {{"fish","≥1"}},
    ["gazpacho"] = {{"frozen","≥2"}},
    ["potatosouffle"] = {{"egg",">0"}},
    ["monstertartare"] = {{"monster","≥2"}},
    ["freshfruitcrepes"] = {{"fruit","≥1.5"}},
    ["bonesoup"] = {{"inedible","<3"}},
    ["moqueca"] = {{"fish",">0"}},
    ["nightmarepie"] = {{"nightmarefuel","+1"}},
    ["dragonchilisalad"] = {{"dragonfruit","+1"}},
}

local function FormatCondValue(v)
    if v == nil then return "" end
    if v == "==" then return WIT_TXT.FMT_COND_ZERO end
    local prefix = v:match("^([^%d.]+)")
    local num_str = v:match("([%d.]+)$")
    if num_str then
        local n = tonumber(num_str)
        if n ~= nil and n == math.floor(n) then num_str = tostring(math.floor(n)) end
        local mapped = {["≥"]="≥", [">"]="＞", ["×"]="＝", ["+"]="≥", ["-"]=""}
        local p = mapped[prefix] or prefix
        return p .. num_str
    end
    return v
end

function FormatCookCondition(recipe, _)
    local conds = HARDCODED_CONDITIONS[recipe.name]
    if conds then
        local parts = {}
        for _, c in ipairs(conds) do
            if c[1] ~= nil then
                table.insert(parts, CN(c[1]) .. " " .. FormatCondValue(c[2]))
            end
        end
        return parts
    end
    return {}
end

-- ============================
-- 客户端物品属性采集 (from wit_itemdata_client.lua)
-- ============================

WIT_ITEM_DB = WIT_ITEM_DB or {}

-- 食物类型 → 可食用角色的映射（非玩家可食用的特殊类型）
local _EATER_HINT_MAP = {
    ROUGHAGE = WIT_TXT.EATER_BEEFALO,
    GEARS = "WX-78",
    WOOD = "",
    ELEMENTAL = "",
    HORRIBLE = WIT_TXT.EATER_SHADOW,
    BURNT = WIT_TXT.EATER_SHADOW,
}

local function CollectItemData(inst)
    local data = {}
    if inst.components.weapon ~= nil then
        if type(inst.components.weapon.damage) == "function" then
            local ran, val = pcall(inst.components.weapon.damage, inst, GLOBAL.ThePlayer)
            if ran then data.weapon = { damage = val } end
        else
            data.weapon = { damage = inst.components.weapon.damage }
        end
        if data.weapon then
            data.weapon.attackrange = inst.components.weapon.attackrange
            data.weapon.projectile = inst.components.weapon.projectile
        end
    end
    if inst.components.armor ~= nil then
        data.armor = {
            absorb_percent = inst.components.armor.absorb_percent,
            maxcondition = inst.components.armor.maxcondition,
        }
    end
    if inst.components.tool ~= nil then
        data.tools = {}
        if type(inst.components.tool.actions) == "table" then
            for act, eff in pairs(inst.components.tool.actions) do
                table.insert(data.tools, { action = act.id, efficiency = eff })
            end
        end
    end
    if inst.components.edible ~= nil then
        local ft = inst.components.edible.foodtype
        -- 检查玩家是否可食用（基于食物类型的 eater tag 体系）
        local player_can_eat = true
        local eater_hint = nil
        if ft ~= nil and ft ~= "GENERIC" then
            local eater_tag = ft .. "_eater"
            if ThePlayer ~= nil and ThePlayer:HasTag(eater_tag) then
                player_can_eat = true
            elseif _EATER_HINT_MAP[ft] ~= nil then
                player_can_eat = false
                if #_EATER_HINT_MAP[ft] > 0 then
                    eater_hint = _EATER_HINT_MAP[ft]
                end
            end
        end
        data.edible = {
            health = inst.components.edible.healthvalue,
            hunger = inst.components.edible.hungervalue,
            sanity = inst.components.edible.sanityvalue,
            foodtype = ft,
            temperaturedelta = inst.components.edible.temperaturedelta,
            temperatureduration = inst.components.edible.temperatureduration,
            player_can_eat = player_can_eat,
            eater_hint = eater_hint,
        }
    end
    if inst.components.perishable ~= nil then
        data.perishable = { perishtime = inst.components.perishable.perishtime }
    end
    if inst.components.fuel ~= nil then
        data.fuel = { fuelvalue = inst.components.fuel.fuelvalue }
    end
    if inst.components.burnable ~= nil then
        data.burnable = { burntime = inst.components.burnable.burntime }
    end
    if inst.components.finiteuses ~= nil then
        data.finiteuses = { maxuses = inst.components.finiteuses.maxuses or inst.components.finiteuses.total }
    end
    if inst.components.equippable ~= nil then
        data.equippable = {
            equipslot = inst.components.equippable.equipslot,
            walkspeedmult = inst.components.equippable.walkspeedmult,
            dapperness = inst.components.equippable.dapperness,
        }
    end
    if inst.components.sanityaura ~= nil then
        data.sanityaura = { aura = inst.components.sanityaura.aura }
    end
    if inst.components.healer ~= nil then
        data.healer = { health = inst.components.healer.health }
    end
    if inst.components.deployable ~= nil then
        data.deployable = { mode = inst.components.deployable.mode }
    end
    if inst.components.waterproofer ~= nil then
        data.waterproofer = { effectiveness = inst.components.waterproofer.effectiveness }
    end
    if inst.components.insulator ~= nil then
        data.insulator = { insulation = inst.components.insulator.insulation, type = inst.components.insulator.type }
    end
    if inst.components.stackable ~= nil then
        data.stackable = { maxsize = inst.components.stackable.maxsize }
    end
    -- Runtime component: repairable (armor, tools etc. with direct repairmaterial)
    if inst.components.repairable ~= nil then
        data.repairable = { repairmaterial = inst.components.repairable.repairmaterial }
    end

    -- Hardcoded scrapbook data: sewable + repairitems for placed entities (walls, boats)
    -- sewable is NOT a runtime component/tag; it's only defined in scrapbookdata.lua
    local sb_ok, sb_data = pcall(GLOBAL.require, "screens/redux/scrapbookdata")
    if sb_ok and type(sb_data) == "table" then
        local entry = sb_data[inst.prefab]
        if entry then
            if entry.sewable then data.sewable = true end
            -- Direct: placed things (walls, boats) list repairitems in scrapbook
            if entry.repairitems then
                data.repairable = data.repairable or {}
                data.repairable.repairitems = entry.repairitems
            -- Indirect: items (wall_stone_item) reference a placed thing via deps
            elseif entry.deps then
                for _, dep in ipairs(entry.deps) do
                    local dep_entry = sb_data[dep]
                    if dep_entry and dep_entry.repairitems then
                        data.repairable = data.repairable or {}
                        data.repairable.repairitems = dep_entry.repairitems
                        break
                    end
                end
            end
        end
    end
    if inst.components.fueled ~= nil then
        data.fueled = { maxfuel = inst.components.fueled.maxfuel, fueltype = inst.components.fueled.fueltype }
    end
    if inst.components.tradable ~= nil then
        data.tradable = { goldvalue = inst.components.tradable.goldvalue }
    end
    if inst.tags ~= nil then
        data.tags = {}
        for tag, _ in pairs(inst.tags) do
            table.insert(data.tags, tag)
        end
    end
    -- Determine which mod added this prefab (if any)
    data.mod_source = GetPrefabModName(inst.prefab)
    return data
end

-- ============================
-- Prefab 来源 Mod 查询
-- ============================

-- Iterate all enabled mods to find which one registered this prefab
function GetPrefabModName(prefab_name)
    if ModManager == nil or ModManager.enabledmods == nil then return nil end
    for _, modname in ipairs(ModManager.enabledmods) do
        local mod = ModManager:GetMod(modname)
        if mod and mod.Prefabs and mod.Prefabs[prefab_name] then
            return KnownModIndex and KnownModIndex:GetModFancyName(modname) or modname
        end
    end
    return nil
end

function GetItemInfo(prefab)
    if prefab == nil then return nil end
    if WIT_ITEM_DB[prefab] ~= nil then return WIT_ITEM_DB[prefab] end

    local IsMasterSim = GLOBAL.TheWorld.ismastersim
    GLOBAL.TheWorld.ismastersim = true
    WIT_SPAWNING_ITEM = true

    local ok, data = pcall(function()
        local inst_copy = GLOBAL.SpawnPrefab(prefab)
        if inst_copy ~= nil then
            local d = CollectItemData(inst_copy)
            inst_copy:Remove()
            return d
        end
        return nil
    end)

    WIT_SPAWNING_ITEM = false
    GLOBAL.TheWorld.ismastersim = IsMasterSim

    WIT_ITEM_DB[prefab] = (ok and data ~= nil) and data or {}
    return WIT_ITEM_DB[prefab]
end

-- ============================
-- 烹饪卡片求解器 (from wit_cook_card_resolver.lua)
-- ============================

function TryInjectFocusIngredient(recipe, slots, focus_name)
    local found = false
    for _, v in ipairs(slots) do
        if v == focus_name then found = true; break end
    end
    if found or not recipe.test then return slots end

    for try_slot = #slots, 1, -1 do
        local override = {}
        for ii = 1, #slots do override[ii] = (ii == try_slot) and focus_name or slots[ii] end
        local sim_names, sim_tags = BuildSimInput(slots, override)
        if recipe.test("cookpot", sim_names, sim_tags) then
            slots[try_slot] = focus_name
            break
        end
    end
    return slots
end

function SubstituteMissingIngredients(recipe, slots, snapshot)
    if not recipe.test or not snapshot then return slots end
    local cooking = _GetCooking()
    local bp_avail = {}
    for name, count in pairs(snapshot.counts) do
        if cooking and cooking.ingredients and cooking.ingredients[name] then
            bp_avail[name] = count
        end
    end
    for _, ing in ipairs(slots) do
        if bp_avail[ing] and bp_avail[ing] > 0 then bp_avail[ing] = bp_avail[ing] - 1 end
    end
    local focus_count = 0
    if WIT_NAME then
        for _, v in ipairs(slots) do
            if v == WIT_NAME then focus_count = focus_count + 1 end
        end
    end
    for slot_i = 1, #slots do
        local cur = slots[slot_i]
        if cur ~= nil then
            local need_count = 0
            for _, v in ipairs(slots) do if v == cur then need_count = need_count + 1 end end
            if (snapshot.counts[cur] or 0) < need_count then
                if cur == WIT_NAME and focus_count <= 1 then
                    -- 保留最后一个焦点食材
                else
                    local best_sub = nil
                    for bp_name, bp_count in pairs(bp_avail) do
                        if bp_count > 0 and bp_name ~= cur then
                            local override = {}
                            for ii = 1, #slots do override[ii] = (ii == slot_i) and bp_name or slots[ii] end
                            local sim_names, sim_tags = BuildSimInput(slots, override)
                            if recipe.test("cookpot", sim_names, sim_tags) then
                                best_sub = bp_name; break
                            end
                        end
                    end
                    if best_sub then
                        slots[slot_i] = best_sub
                        bp_avail[best_sub] = bp_avail[best_sub] - 1
                        if cur == WIT_NAME then focus_count = focus_count - 1 end
                    end
                end
            end
        end
    end
    return slots
end

-- ============================
-- 自动烹饪判定 (统一版，消除 2 份重复)
-- ============================

function CanAutoCook(view)
    if view == nil or view.need_map == nil then return false end
    local pot = WIT_OPEN_COOKPOT
    if pot == nil then return false end
    if pot.replica.stewer ~= nil then
        if pot.replica.stewer:IsCooking() or pot.replica.stewer:IsDone() then return false end
    end
    -- view.need_map uses resolved names (like meat_cooked)
    -- We need to check against actual inventory counts
    local snapshot = CollectIngredientSnapshot()
    for prefab, count in pairs(view.need_map) do
        if (snapshot.counts[prefab] or 0) < count then return false end
    end
    return true
end

function AutoFillCookPot(view)
    if ThePlayer == nil or view == nil or view.slots == nil then return end
    local pot = WIT_OPEN_COOKPOT
    if pot == nil then return end
    local classified = ThePlayer.replica.inventory and ThePlayer.replica.inventory.classified
    if classified == nil then return end

    -- Create a reverse alias map to find original prefabs
    local reverse_aliases = {}
    for k, v in pairs(WIT_COOKING_ALIASES) do
        reverse_aliases[v] = k
    end

    for _, prefab in ipairs(view.slots) do
        if prefab ~= nil then
            -- The slot might be a resolved name (meat_cooked). Try to find either original or resolved.
            local search_prefab = reverse_aliases[prefab] or prefab
            local slot, owner = FindItemSlotInInventory(search_prefab)
            if slot == nil and search_prefab ~= prefab then
                slot, owner = FindItemSlotInInventory(prefab)
            end
            if slot ~= nil and owner ~= nil then
                classified:MoveItemFromAllOfSlot(slot, pot)
            end
        end
    end
end

-- ============================
-- 库存快照 + 烹饪上下文管理
-- ============================

function CollectIngredientSnapshot()
    local bp_items = GetPlayerIngredientList() or {}
    local snapshot = { list = bp_items, counts = {}, tags = {} }
    for _, v in ipairs(bp_items) do
        local name = WIT_COOKING_ALIASES[v] or v
        snapshot.counts[name] = (snapshot.counts[name] or 0) + 1
        _AccumulateIngredient(v, 1, {}, snapshot.tags)
    end
    return snapshot
end

function CanAutoCookFromSnapshot(need_map, counts)
    if need_map == nil or counts == nil then return false end
    local pot = WIT_OPEN_COOKPOT
    if pot == nil then return false end
    if pot.replica.stewer ~= nil then
        if pot.replica.stewer:IsCooking() or pot.replica.stewer:IsDone() then return false end
    end
    for prefab, count in pairs(need_map) do
        if (counts[prefab] or 0) < count then return false end
    end
    return true
end

function ResolveCookingCard(recipe, focus_name, snapshot)
    if not recipe.card_def or not recipe.card_def.ingredients then return nil end
    local slots = FlattenIngredients(recipe.card_def.ingredients)
    slots = TryInjectFocusIngredient(recipe, slots, focus_name)
    local raw_need_map = {}
    for _, s in ipairs(slots) do
        if s ~= nil then raw_need_map[s] = (raw_need_map[s] or 0) + 1 end
    end
    slots = SubstituteMissingIngredients(recipe, slots, snapshot)
    slots = PadSlots(slots, 4)
    if focus_name then
        local found = false
        for _, s in ipairs(slots) do
            if s == focus_name then found = true; break end
        end
        if not found then return nil end
    end
    local need_map = {}
    for _, s in ipairs(slots) do
        if s ~= nil then need_map[s] = (need_map[s] or 0) + 1 end
    end
    return {
        slots = slots,
        need_map = need_map,
        raw_need_map = raw_need_map,
        can_auto_cook = CanAutoCookFromSnapshot(need_map, snapshot.counts),
    }
end

function BuildCookContext()
    local snapshot = CollectIngredientSnapshot()
    if WIT_COOK_CONTEXT and (not snapshot or not snapshot.list or #snapshot.list == 0) then return end
    WIT_COOK_REV = (WIT_COOK_REV or 0) + 1
    WIT_COOK_CONTEXT = {
        revision = WIT_COOK_REV,
        snapshot = snapshot,
        resolved = {},
    }
end

function GetResolvedCookingCard(recipe, focus_name)
    local ctx = WIT_COOK_CONTEXT
    if ctx == nil then return nil end
    local key = recipe.name .. "|" .. focus_name
    if ctx.resolved[key] == nil then
        ctx.resolved[key] = ResolveCookingCard(recipe, focus_name, ctx.snapshot)
    end
    return ctx.resolved[key]
end

-- ============================
-- 烹饪锅状态检测 (from wit_helpers.lua)
-- ============================

function GetOpenCookPot()
    if ThePlayer == nil or ThePlayer.replica == nil then return nil end
    local containers = ThePlayer.replica.inventory:GetOpenContainers()
    if containers == nil then return nil end
    for ent, _ in pairs(containers) do
        if ent:HasTag("stewer") and ent.replica.container ~= nil then
            return ent
        end
    end
    return nil
end