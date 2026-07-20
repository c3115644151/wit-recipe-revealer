name = "[JEI] What Is This"
description = "悬浮物品按 R 查看配方来源，按 U 查看用途。支持合成、烹饪双向查询，实时背包材料匹配。\n\nHover over an item and press R to see how to craft it, or U to see what it can be used for.\n\n一个类似 JEI 的饥荒配方查询工具。\n\n[v1.4.2] 合成菜单左键/右键/R/U键可指定默认页签；热重载支持；配方网格点击自动跳转。\n[v1.4.2] Left-click/right-click/R/U now configurable to open any default tab; hot reload support; auto-switch on recipe grid click.\n[v1.4.3] 修复部分物品图标在弹窗中无法显示的问题。\n[v1.4.3] Fixed an issue where some item icons wouldn't display in the popup.\n[v1.4.4] 修复配方网格点击自动跳转不生效的问题；修复烹饪配方索引构建时部分 Mod 料理导致崩溃的问题。\n[v1.4.4] Fixed recipe grid auto-jump not working; fixed crash in cooking recipe indexing caused by some mod dishes.\n[v1.4.5] 修复自动查询在各种无关场景（初始化、过滤器切换等）弹窗的问题；修复开启自动暂停后进入角色面板崩溃的问题。\n[v1.4.5] Fixed auto-query popping up in irrelevant scenarios (initialization, filter switching, etc.); fixed crash when entering character panel with auto-pause enabled."
author = "凝筝"
version = "1.4.6"
api_version = 10
client_only_mod = true
dst_compatible = true
all_clients_require_mod = false
priority = 0

-- Workshop 图标
icon_atlas = "images/modicon.xml"
icon = "modicon.tex"

-- ============================
-- 全键盘按键定义（供 KEY_R / KEY_U 使用）
-- ============================
local keyboard = {
    { 'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12' },
    { '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' },
    { 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M' },
    { 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z' },
    { 'Space', 'Tab', 'LShift', 'LCtrl', 'LSuper', 'LAlt' },
    { 'RAlt', 'RSuper', 'RCtrl', 'RShift', 'Enter', 'Backspace' },
    { 'BackQuote', 'Minus', 'Equals', 'LeftBracket', 'RightBracket' },
    { 'Backslash', 'Semicolon', 'Quote', 'Period', 'Comma', 'Slash' },
    { 'Up', 'Down', 'Left', 'Right', 'Insert', 'Delete', 'Home', 'End', 'PageUp', 'PageDown' },
}
local numpad = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'Period', 'Divide', 'Multiply', 'Minus', 'Plus' }
local mouse_btns = { '\238\132\130', '\238\132\131', '\238\132\132' }  -- 中键, 侧键1, 侧键2
local key_disabled = { description = 'Disabled', data = 'KEY_DISABLED' }
keys = { key_disabled }
for i = 1, #keyboard do
    for j = 1, #keyboard[i] do
        local key = keyboard[i][j]
        keys[#keys + 1] = { description = key, data = 'KEY_' .. key:upper() }
    end
    keys[#keys + 1] = key_disabled
end
for i = 1, #numpad do
    local key = numpad[i]
    keys[#keys + 1] = { description = 'Numpad ' .. key, data = 'KEY_KP_' .. key:upper() }
end
for i = 1, #mouse_btns do
    keys[#keys + 1] = { description = mouse_btns[i], data = mouse_btns[i] }
end

-- 配置项（运行时由 _OpenSettings 根据语言动态本地化）
configuration_options =
{
    {
        name = "LANGUAGE",
        label = "界面语言",
        hover = "选择 Mod 界面显示语言（切换后需重启游戏生效）",
        options =
        {
            {description = "自动", data = "auto"},
            {description = "中文", data = "zh"},
            {description = "英文", data = "en"},
        },
        default = "auto",
    },
    {
        name = "KEY_R",
        label = "来源查询键",
        hover = "悬浮物品后按下此键，查看该物品的制作/烹饪配方及获取来源",
        options = keys,
        default = "KEY_R",
    },
    {
        name = "KEY_U",
        label = "用途查询键",
        hover = "悬浮物品后按下此键，查看该物品的用途",
        options = keys,
        default = "KEY_U",
    },
    {
        name = "KEY_NAV_BACK",
        label = "导航后退键",
        hover = "在 WIT 弹窗中按下此键，回退到上一个浏览的物品",
        options = keys,
        default = '\238\132\131',
    },
    {
        name = "KEY_NAV_FORWARD",
        label = "导航前进键",
        hover = "在 WIT 弹窗中按下此键，前进到下一个浏览的物品",
        options = keys,
        default = '\238\132\132',
    },
    {
        name = "POPUP_POSITION",
        label = "弹窗位置",
        hover = "信息弹窗的水平显示位置",
        options =
        {
            {description = "自动（跟随合成栏）", data = "auto"},
            {description = "居左", data = "left"},
            {description = "居右", data = "right"},
        },
        default = "auto",
    },
    {
        name = "SHOW_HOVER_INFO",
        label = "图标悬浮详情",
        hover = "在弹窗内悬浮物品图标时，显示该物品的核心属性数值（图标+数字）",
        options =
        {
            {description = "开", data = true},
            {description = "关", data = false},
        },
        default = true,
    },
    {
        name = "CRAFTING_DETAIL_LCLICK",
        label = "合成菜单左键默认页签",
        hover = "在合成菜单详情面板中左键产物图标时，默认跳转到该页签",
        options =
        {
            {description = "关闭", data = "disabled"},
            {description = "获取来源", data = "SOURCES"},
            {description = "制作", data = "CRAFT_FROM"},
            {description = "烹饪", data = "COOK_FROM"},
            {description = "制作用途", data = "CRAFT_USE"},
            {description = "烹饪用途", data = "COOK_USE"},
            {description = "信息", data = "INFO"},
        },
        default = "CRAFT_FROM",
    },
    {
        name = "CRAFTING_DETAIL_RCLICK",
        label = "合成菜单右键默认页签",
        hover = "在合成菜单详情面板中右键图标时，默认跳转到该页签",
        options =
        {
            {description = "关闭", data = "disabled"},
            {description = "获取来源", data = "SOURCES"},
            {description = "制作", data = "CRAFT_FROM"},
            {description = "烹饪", data = "COOK_FROM"},
            {description = "制作用途", data = "CRAFT_USE"},
            {description = "烹饪用途", data = "COOK_USE"},
            {description = "信息", data = "INFO"},
        },
        default = "CRAFT_USE",
    },
    {
        name = "LCLICK_QUERY_TAB",
        label = "弹窗/来源键默认页签",
        hover = "在弹窗槽位中点选图标或按来源键(R)时，默认跳转到该页签",
        options =
        {
            {description = "关闭", data = "disabled"},
            {description = "获取来源", data = "SOURCES"},
            {description = "制作", data = "CRAFT_FROM"},
            {description = "烹饪", data = "COOK_FROM"},
            {description = "制作用途", data = "CRAFT_USE"},
            {description = "烹饪用途", data = "COOK_USE"},
            {description = "信息", data = "INFO"},
        },
        default = "CRAFT_FROM",
    },
    {
        name = "RCLICK_QUERY_TAB",
        label = "弹窗/用途键默认页签",
        hover = "在弹窗槽位中右键图标或按用途键(U)时，默认跳转到该页签",
        options =
        {
            {description = "关闭", data = "disabled"},
            {description = "获取来源", data = "SOURCES"},
            {description = "制作", data = "CRAFT_FROM"},
            {description = "烹饪", data = "COOK_FROM"},
            {description = "制作用途", data = "CRAFT_USE"},
            {description = "烹饪用途", data = "COOK_USE"},
            {description = "信息", data = "INFO"},
        },
        default = "CRAFT_USE",
    },
    {
        name = "CRAFTING_GRID_AUTO_OPEN",
        label = "合成菜单网格自动查询",
        hover = "在合成菜单网格中点击配方时，自动打开 WIT 查询弹窗",
        options =
        {
            {description = "开", data = true},
            {description = "关", data = false},
        },
        default = true,
    },
    {
        name = "AUTO_PAUSE_UI",
        label = "打开UI自动暂停",
        hover = "单人世界中打开本模组主界面时自动暂停世界；多人模式下不生效",
        options =
        {
            {description = "开", data = true},
            {description = "关", data = false},
        },
        default = true,
    },
}
