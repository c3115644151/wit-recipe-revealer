-- wit_lang: 国际化模块
-- 自动适应 DST 游戏语言, 也可在配置中强制切换
-- 所有玩家可见文本都集中在此

local LANG = GetModConfigData("LANGUAGE") or ""
if LANG == "" or LANG == "auto" then
	if TheNet then
		local locale = TheNet:GetLanguageCode()
		if locale and locale:sub(1,2) == "zh" then
			LANG = "zh"
		else
			LANG = "en"
		end
	else
		LANG = "en"
	end
end

local TXT = {}

if LANG == "zh" then
	-- ======== 中文 ========
	TXT.TAB_CRAFTING = "制作"
	TXT.TAB_COOKING = "烹饪"
	TXT.PRIORITY = "P"
	TXT.CLOSE = "✕"
	TXT.LOADING = "加载中..."
	TXT.AUTO_COOK_TIP = "自动放入"

	-- 标签条件
	TXT.TAG_NAMES = {
		meat = "肉度", monster = "怪物度", veggie = "蔬菜度", fruit = "水果度",
		egg = "蛋度", fish = "鱼度", sweetener = "甜味剂度", fat = "油脂度",
		dairy = "乳制品度", inedible = "不可食用度", seed = "种子度", magic = "魔法度",
		decoration = "装饰度", precook = "预处理度", dried = "干货度", frozen = "冰度",
	}

else
	-- ======== 英文 ========
	TXT.TAB_CRAFTING = "Crafting"
	TXT.TAB_COOKING = "Cooking"
	TXT.PRIORITY = "P"
	TXT.CLOSE = "✕"
	TXT.LOADING = "Loading..."

	TXT.TAG_NAMES = {
		meat = "Meat", monster = "Monster", veggie = "Vegetable", fruit = "Fruit",
		egg = "Egg", fish = "Fish", sweetener = "Sweetener", fat = "Fat",
		dairy = "Dairy", inedible = "Inedible", seed = "Seed", magic = "Magic",
		decoration = "Decoration", precook = "Precooked", dried = "Dried", frozen = "Frozen",
	}
end

function CN(tag)
	local t = TXT.TAG_NAMES[tag]
	if t then return t end
	return tag
end

WIT_TXT = TXT
