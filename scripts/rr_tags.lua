-- rr_tags: 中文标签映射
-- 通过全局变量 TAG_CN / CN 暴露

TAG_CN = {
	meat = "肉度", monster = "怪物度", veggie = "蔬菜度", fruit = "水果度",
	egg = "蛋度", fish = "鱼度", sweetener = "甜味剂度", fat = "油脂度",
	dairy = "乳制品度", inedible = "不可食用度", seed = "种子度", magic = "魔法度",
	decoration = "装饰度", precook = "预处理度", dried = "干货度", frozen = "冰度",
}

function CN(tag) return TAG_CN[tag] or tag end
