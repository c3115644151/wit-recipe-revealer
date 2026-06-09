-- [JEI] What Is This - modmain
-- 入口文件: 注册事件 + 加载子模块

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
WIT_PAGE_SIZE = 3
WIT_KEY_R = GetModConfigData("KEY_R") or 114
WIT_KEY_U = GetModConfigData("KEY_U") or 117

-- ============================
-- 数据层
-- ============================
WIT = {}
WIT.by_product = {}
WIT.by_material = {}
WIT.cook_foods = {}
WIT.cook_by_ingredient = {}
WIT.ingredient_tags = {}
WIT.data_built = false

-- ============================
-- 弹窗状态 (WIT_ 前缀避免全局污染)
-- ============================
WIT_POPUP = nil
WIT_NAME = nil       -- 当前查询的物品 prefab
WIT_MODE = nil       -- "SOURCE" 或 "USE"
WIT_CUR_CAT = nil    -- 当前选中的分类
WIT_PAGE = 1
WIT_AVAIL_CATS = {}
WIT_CONTENT = nil
WIT_TAB_BTNS = {}
WIT_PG_TEXT = nil
WIT_PG_PREV = nil
WIT_PG_NEXT = nil
WIT_OPEN_COOKPOT = nil  -- 当前打开的烹饪锅实体

-- ============================
-- 加载子模块
-- ============================
modimport("scripts/wit_lang")
modimport("scripts/wit_tags")
modimport("scripts/wit_build")
modimport("scripts/wit_helpers")
modimport("scripts/wit_slot")
modimport("scripts/wit_sort")
modimport("scripts/wit_render")
modimport("scripts/wit_category")
modimport("scripts/wit_popup")
modimport("scripts/wit_input")

-- ============================
-- 初始化
-- ============================
AddPlayerPostInit(function(inst)
	local function wit_refresh()
		WIT_OPEN_COOKPOT = GetOpenCookPot()
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

-- v1.0 TODO: 合成菜单联动, 暂不启用
