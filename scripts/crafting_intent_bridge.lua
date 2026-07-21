-- CraftingMenuIntentBridge
-- 合成菜单点击意图桥接器
--
-- 用显式状态取代全局 ImageButton 钩子 + 时间窗猜测方案。
-- 调用方明确声明自己是"用户点击"还是"程序刷新"。
--
-- 接口:
--   MarkClick(recipe_name)     — 用户点击了配方网格中的一个格子
--   RunProgrammaticUpdate(fn)  — 程序主动刷新详情面板，不触发 WIT 联动
--   ConsumeClickIntent(name)   — Details 层消费点击意图，返回 true 表示需要打开 WIT

WIT_CRAFT_INTENT = {
    pending_recipe = nil,
    suppress_auto_open = false,
}

-- 记录用户对某个配方的显式点击
function WIT_CRAFT_INTENT:MarkClick(recipe_name)
    self.pending_recipe = recipe_name
end

-- 包装一段程序性的 UI 更新，期间抑制 WIT 自动打开
-- fn 执行期间 suppress_auto_open = true，执行后恢复
function WIT_CRAFT_INTENT:RunProgrammaticUpdate(fn)
    self.suppress_auto_open = true
    local ok, ret = pcall(fn)
    self.suppress_auto_open = false
    return ok, ret
end

-- 消费点击意图：
-- 在有用户点击且在 suppress 期外时返回 true
-- 成功消费后会清除 pending_recipe，避免重复触发
function WIT_CRAFT_INTENT:ConsumeClickIntent(recipe_name)
    if self.suppress_auto_open then
        return false
    end
    if self.pending_recipe ~= recipe_name then
        return false
    end
    self.pending_recipe = nil
    return true
end
