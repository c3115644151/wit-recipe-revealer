-- RecipeRevealer modmain
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
-- 全局常量 (RR_ 前缀避免全局污染)
-- ============================
RR_COOKING_ALIASES = { cookedsmallmeat = "smallmeat_cooked", cookedmonstermeat = "monstermeat_cooked", cookedmeat = "meat_cooked" }
RR_PAGE_SIZE = 3
RR_KEY_R = GetModConfigData("KEY_R") or 114
RR_KEY_U = GetModConfigData("KEY_U") or 117

-- ============================
-- 数据层
-- ============================
RR = {}
RR.by_product = {}
RR.by_material = {}
RR.cook_foods = {}
RR.cook_by_ingredient = {}
RR.ingredient_tags = {}
RR.data_built = false

-- ============================
-- 弹窗状态 (RR_ 前缀避免全局污染)
-- ============================
RR_POPUP = nil
RR_NAME = nil       -- 当前查询的物品 prefab
RR_MODE = nil       -- "SOURCE" 或 "USE"
RR_CUR_CAT = nil    -- 当前选中的分类
RR_PAGE = 1
RR_AVAIL_CATS = {}
RR_CONTENT = nil
RR_TAB_BTNS = {}
RR_PG_TEXT = nil
RR_PG_PREV = nil
RR_PG_NEXT = nil
RR_OPEN_COOKPOT = nil  -- 当前打开的烹饪锅实体

-- ============================
-- 加载子模块
-- ============================
modimport("scripts/rr_tags")
modimport("scripts/rr_build")
modimport("scripts/rr_helpers")
modimport("scripts/rr_slot")
modimport("scripts/rr_sort")
modimport("scripts/rr_render")
modimport("scripts/rr_category")
modimport("scripts/rr_popup")
modimport("scripts/rr_input")

-- ============================
-- 初始化
-- ============================
AddPlayerPostInit(function(inst)
	local function rr_refresh()
		RR_OPEN_COOKPOT = GetOpenCookPot()
		if RR_POPUP ~= nil and RR_CONTENT ~= nil and RR_CUR_CAT ~= nil then
			SelectCategory(RR_CUR_CAT, false)
		end
	end
	inst:ListenForEvent("refreshcrafting", rr_refresh)
	inst:ListenForEvent("refreshinventory", rr_refresh)
	inst:ListenForEvent("opencontainer", rr_refresh)
	inst:ListenForEvent("closecontainer", rr_refresh)
	inst:DoTaskInTime(0, rr_refresh)
end)

-- v1.0 TODO: 合成菜单联动, 暂不启用
