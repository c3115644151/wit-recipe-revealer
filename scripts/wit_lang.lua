-- wit_lang: 国际化模块
-- 自动适应 DST 游戏语言, 也可在配置中强制切换
-- 所有玩家可见文本都集中在此

local LANG = GetModConfigData("LANGUAGE") or ""
if LANG == "" or LANG == "auto" then
	local lang_id = (Profile and Profile:GetLanguageID()) or LANGUAGE.ENGLISH
	if lang_id == LANGUAGE.CHINESE_S or lang_id == LANGUAGE.CHINESE_T or lang_id == LANGUAGE.CHINESE_S_RAIL then
		LANG = "zh"
	else
		LANG = "en"
	end
end

local TXT = {}

if LANG == "zh" then
	-- ======== 中文 ========
	TXT.TAB_CRAFTING = "制作"
	TXT.TAB_COOKING = "烹饪"
	TXT.TAB_INFO = "信息"
	TXT.PRIORITY = "P"
	TXT.CLOSE = "✕"
	TXT.LOADING = "加载中..."
	TXT.NO_INFO = "无详细信息"
	TXT.AUTO_COOK_TIP = "自动放入"

	-- 物品信息
	TXT.DMG = "伤害"
	TXT.ABSORB = "吸收"
	TXT.DUR = "耐久"
	TXT.EFF = "效率"
	TXT.ACTION = "动作"
	TXT.HUNGER = "饱食"
	TXT.HEALTH = "生命"
	TXT.SANITY = "精神"
	TXT.FOODTYPE = "食物类型"
	TXT.TEMP = "温度"
	TXT.HEAL = "治疗"
	TXT.SLOT = "装备位"
	TXT.SPEED = "速度"
	TXT.USES = "次数"
	TXT.SPOIL = "保鲜"
	TXT.DAY = "天"
	TXT.BURN = "燃烧"
	TXT.SEC = "秒"
	TXT.FUEL = "燃料"
	TXT.MIN = "分"
	TXT.WATERPROOF = "防水"
	TXT.INSULATE = "保暖"
	TXT.STACK = "堆叠"
	TXT.TRADE = "交易"
	TXT.REPAIRABLE = "可修理"
	TXT.REPAIRABLE_BY = "可被 %s 修理"
	TXT.SEWABLE = "可缝补"
	TXT.INEDIBLE_PLAYER = "非玩家可食"
	TXT.EDIBLE_BY = "可被 %s 食用"

	-- 装备位（EQUIPSLOTS 枚举值）
	TXT.EQUIPSLOT_NAMES = {
		head = "头部",
		body = "身体",
		hands = "手部",
		beard = "胡须",
	}

	-- 标签条件
	TXT.TAG_NAMES = {
		meat = "肉度", monster = "怪物度", veggie = "蔬菜度", fruit = "水果度",
		egg = "蛋度", fish = "鱼度", sweetener = "甜味剂度", fat = "油脂度",
		dairy = "乳制品度", inedible = "不可食用度", seed = "种子度", magic = "魔法度",
		decoration = "装饰度", precook = "预处理度", dried = "干货度", frozen = "冰度",
		-- mod 自定义 tag（永不妥协等）
		insectoid = "虫类度", foliage = "叶绿度", rice = "米粮度",
	}

	-- 食物类型本地化（与官方图鉴翻译一致）
	TXT.FOODTYPE_NAMES = {
		GENERIC = "通用", MEAT = "肉", VEGGIE = "素食",
		ELEMENTAL = "元素", GEARS = "齿轮", HORRIBLE = "可怕",
		INSECT = "昆虫", SEEDS = "种子", BERRY = "浆果",
		RAW = "生的", BURNT = "烧焦", ROUGHAGE = "粗食",
		WOOD = "木质", GOODIES = "好东西", MONSTER = "怪物",
		LUNAR_SHARDS = "月亮碎片", CORPSE = "尸体",
	}

	-- 图标悬浮提示（中文）
	TXT.ICON_TOOLTIPS = {
		icon_hunger = "饥饿值回复",
		icon_health = "生命值回复",
		icon_sanity = "理智值回复",
		icon_damage = "攻击伤害",
		icon_armor = "护甲吸收率",
		icon_uses = "使用次数",
		icon_action = "工具动作",
		icon_clothing = "装备类型",
		icon_food = "食物类型",
		icon_heat = "升温效果",
		icon_cold = "降温效果",
		icon_spoil = "腐坏时间",
		icon_burnable = "燃烧时长",
		icon_fuel = "使用/燃料时长",
		icon_wrench = "可修理",
		icon_sewingkit = "可缝补",
		icon_wetness = "防水效果",
		icon_stack = "最大堆叠",
		cane = "移速加成",
		goldnugget = "交易价值",
	}

else
	-- ======== 英文 ========
	TXT.TAB_CRAFTING = "Crafting"
	TXT.TAB_COOKING = "Cooking"
	TXT.TAB_INFO = "Info"
	TXT.PRIORITY = "P"
	TXT.CLOSE = "✕"
	TXT.LOADING = "Loading..."
	TXT.NO_INFO = "No detailed info"
	TXT.AUTO_COOK_TIP = "Auto Cook"

	-- Item Info
	TXT.DMG = "Damage"
	TXT.ABSORB = "Absorb"
	TXT.DUR = "Durability"
	TXT.EFF = "Efficiency"
	TXT.ACTION = "Action"
	TXT.HUNGER = "Hunger"
	TXT.HEALTH = "Health"
	TXT.SANITY = "Sanity"
	TXT.FOODTYPE = "Food Type"
	TXT.TEMP = "Temp"
	TXT.HEAL = "Heal"
	TXT.SLOT = "Slot"
	TXT.SPEED = "Speed"
	TXT.USES = "Uses"
	TXT.SPOIL = "Spoilage"
	TXT.DAY = "d"
	TXT.BURN = "Burn"
	TXT.SEC = "s"
	TXT.FUEL = "Fuel"
	TXT.MIN = "min"
	TXT.WATERPROOF = "Waterproof"
	TXT.INSULATE = "Insulation"
	TXT.STACK = "Stack"
	TXT.TRADE = "Trade"
	TXT.REPAIRABLE = "Repairable"
	TXT.REPAIRABLE_BY = "Repaired by %s"
	TXT.SEWABLE = "Sewable"
	TXT.INEDIBLE_PLAYER = "Not edible by players"
	TXT.EDIBLE_BY = "Edible by %s"

	TXT.EQUIPSLOT_NAMES = {
		head = "Head",
		body = "Body",
		hands = "Hands",
		beard = "Beard",
	}

	TXT.TAG_NAMES = {
		meat = "Meat", monster = "Monster", veggie = "Vegetable", fruit = "Fruit",
		egg = "Egg", fish = "Fish", sweetener = "Sweetener", fat = "Fat",
		dairy = "Dairy", inedible = "Inedible", seed = "Seed", magic = "Magic",
		decoration = "Decoration", precook = "Precooked", dried = "Dried", frozen = "Frozen",
		-- mod custom tags
		insectoid = "Insectoid", foliage = "Foliage", rice = "Rice",
	}

	-- Food type translations (matching official scrapbook)
	TXT.FOODTYPE_NAMES = {
		GENERIC = "Generic", MEAT = "Meat", VEGGIE = "Vegetable",
		ELEMENTAL = "Elemental", GEARS = "Gears", HORRIBLE = "Horrible",
		INSECT = "Insect", SEEDS = "Seeds", BERRY = "Berry",
		RAW = "Raw", BURNT = "Burnt", ROUGHAGE = "Roughage",
		WOOD = "Wood", GOODIES = "Goodies", MONSTER = "Monster",
		LUNAR_SHARDS = "Lunar Shards", CORPSE = "Corpse",
	}

	-- Icon tooltips (English)
	TXT.ICON_TOOLTIPS = {
		icon_hunger = "Hunger Restored",
		icon_health = "Health Restored",
		icon_sanity = "Sanity Restored",
		icon_damage = "Attack Damage",
		icon_armor = "Armor Absorption",
		icon_uses = "Uses",
		icon_action = "Tool Action",
		icon_clothing = "Equipment Slot",
		icon_food = "Food Type",
		icon_heat = "Heating Effect",
		icon_cold = "Cooling Effect",
		icon_spoil = "Spoilage Time",
		icon_burnable = "Burn Duration",
		icon_fuel = "Use/Fuel Duration",
		icon_wrench = "Repairable",
		icon_sewingkit = "Sewable",
		icon_wetness = "Waterproofing",
		icon_stack = "Max Stack",
		cane = "Speed Bonus",
		goldnugget = "Trade Value",
	}
end

function CN(tag)
	-- 1. 烹饪标签名（蛋度、肉度等）
	local t = TXT.TAG_NAMES[tag]
	if t then return t end
	-- 2. 具体食材/物品名（洞穴香蕉、火龙果等）
	if STRINGS and STRINGS.NAMES then
		local name = STRINGS.NAMES[string.upper(tag)]
		if name then return name end
	end
	-- 3. 动作名（砍树、挖矿等）
	if STRINGS and STRINGS.ACTIONS then
		local act = STRINGS.ACTIONS[string.upper(tag)]
		if act and type(act) == "string" then return act end
		-- Some actions might be tables, e.g. ACTIVATE.GENERIC
		if act and type(act) == "table" and act.GENERIC then return act.GENERIC end
	end
	-- 4. 纯回退
	return tag
end

WIT_TXT = TXT
