-- [JEI] What Is This - modmain
-- 入口文件: 全局常量 + 事件注册 + 模块加载

GLOBAL.setmetatable(env, { __index = function(_, k) return GLOBAL.rawget(GLOBAL, k) end })

-- 模块依赖
GLOBAL.Widget = require("widgets/widget")
GLOBAL.Image = require("widgets/image")
GLOBAL.Text = require("widgets/text")
GLOBAL.TextButton = require("widgets/textbutton")
GLOBAL.ImageButton = require("widgets/imagebutton")

Widget = GLOBAL.Widget
Image = GLOBAL.Image
Text = GLOBAL.Text
TextButton = GLOBAL.TextButton
ImageButton = GLOBAL.ImageButton

-- ============================
-- 全局常量 (WIT_ 前缀避免全局污染)
-- ============================
WIT_COOKING_ALIASES = { cookedsmallmeat = "smallmeat_cooked", cookedmonstermeat = "monstermeat_cooked", cookedmeat = "meat_cooked" }
WIT_INGREDIENT_PREFAB_MAP = { egg = "bird_egg" }
WIT_PAGE_SIZE = 3
WIT_KEY_R = GetModConfigData("KEY_R") or 114
WIT_KEY_U = GetModConfigData("KEY_U") or 117

-- ============================
-- 数据层状态
-- ============================
WIT = {}
WIT.by_product = {}
WIT.by_material = {}
WIT.cook_foods = {}
WIT.cook_by_ingredient = {}
WIT.ingredient_tags = {}
WIT_data_built = false

-- ============================
-- UI 层状态
-- ============================
WIT_POPUP = nil
WIT_NAME = nil
WIT_MODE = nil
WIT_CUR_CAT = nil
WIT_PAGE = 1
WIT_AVAIL_CATS = {}
WIT_CONTENT = nil
WIT_TAB_BTNS = {}
WIT_PG_TEXT = nil
WIT_PG_PREV = nil
WIT_PG_NEXT = nil
WIT_OPEN_COOKPOT = nil

-- ============================
-- 纯客户端实体拦截
-- ============================
WIT_SPAWNING_ITEM = false
AddGlobalClassPostConstruct("entityscript", "EntityScript", function(self)
    local oldRegisterComponentActions = self.RegisterComponentActions
    if oldRegisterComponentActions ~= nil then
        self.RegisterComponentActions = function(self, name)
            if not WIT_SPAWNING_ITEM then
                return oldRegisterComponentActions(self, name)
            end
        end
    end
end)

-- ============================
-- 加载子模块 (顺序: 国际化 → 数据层 → 表现层)
-- ============================
modimport("scripts/wit_lang")
modimport("scripts/wit_core")
modimport("scripts/wit_ui")

-- ============================
-- 初始化事件
-- ============================
AddPlayerPostInit(function(inst)
    local function wit_refresh()
        WIT_OPEN_COOKPOT = GetOpenCookPot()
        BuildCookContext()
        if WIT_POPUP ~= nil and WIT_CONTENT ~= nil and WIT_CUR_CAT ~= nil then
            SelectCategory(WIT_CUR_CAT, false)
        end
    end
    inst:ListenForEvent("refreshcrafting", wit_refresh)
    inst:ListenForEvent("refreshinventory", wit_refresh)
    inst:ListenForEvent("opencontainer", wit_refresh)
    inst:ListenForEvent("closecontainer", wit_refresh)
    inst:DoTaskInTime(0, wit_refresh)
end)

-- 合成菜单联动
AddClassPostConstruct("widgets/redux/craftingmenu_hud", function(self)
    local orig_open = self.Open
    self.Open = function(s, ...)
        local ret = orig_open(s, ...)
        if WIT_POPUP ~= nil then
            WIT_POPUP:MoveTo(WIT_POPUP:GetPosition(), Vector3(881, 35, 0), 0.25)
        end
        return ret
    end
    local orig_close = self.Close
    self.Close = function(s, ...)
        local ret = orig_close(s, ...)
        if WIT_POPUP ~= nil then
            WIT_POPUP:MoveTo(WIT_POPUP:GetPosition(), Vector3(405, 35, 0), 0.25)
        end
        return ret
    end
end)
