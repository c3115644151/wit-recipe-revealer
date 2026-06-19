# v1.3.0 更新说明

> 2026-06-16

## 新功能

### 获取来源标签页
按 R 查询物品时，新增「获取来源」分类：
- 显示哪些生物会掉落它
- 显示哪些资源点可以采集/挖掘/砍伐获得它
- 来源实体直接用游戏的 3D 模型渲染，和官方图鉴详情页一样直观
- 战利品表支持展开/折叠

### 拆解配方
按 U 查询物品时，如果该物品可以被拆解魔杖分解，制作标签页会显示拆解产物。配方卡片左上角有专属标记。

### 制作站信息
每个配方卡片右上角新增小图标，显示需要什么制作站（科学机器、炼金引擎、暗影操纵者等）、是否为角色专属配方、以及是否需要蓝图。

### 导航优化
弹窗顶部的物品图标现在支持左右键交互：左键查来源，右键查用途。

### 来源详情优化
- 战利品图标下不再显示多余的 "×1"
- 概率掉落显示百分比，固定掉落多件时显示 "×N"
- 每个来源卡片左上角显示交互类型图标

## Bug 修复
- 修复蓝图类物品无玩家上下文时 SpawnPrefab 崩溃的问题
- 修复标题图标点击后重置大小的问题
- 修复部分实体图标渲染不全的问题
- 修复晾肉架等实体渲染时出现红色纹理的问题

## 优化
- 所有实体图标改用 3D 模型渲染，移除多余背景框
- 图标大小和定位算法与官方图鉴详情页同步
- 中英文语言包全面完善

---

# v1.3.0 Release Notes

## New Features

### Sources Tab
Press R on any item to see the new "Sources" tab, showing how to obtain it from the world:
- Mob drops with exact drop chances
- Foraging sources (picking, mining, chopping, digging, hammering)
- Source entities rendered as 3D models (same as the scrapbook detail view)
- Expandable loot tables for entities with many drops

### Deconstruction Recipes
Press U on a deconstructable item, and the crafting tab now shows what you would get from the Deconstruction Staff. Deconstruction cards have a special indicator icon.

### Crafting Station Info
Each recipe card now shows small icons indicating the required crafting station, character-exclusive tags, and blueprint requirements.

### Better Navigation
The title item icon is now interactive: left click for source lookup, right click for usage lookup.

### Smarter Sources Display
- "x1" is now hidden to reduce visual noise
- Probability drops show percentages
- Multiple guaranteed drops show "xN"
- Each source card shows a type icon (combat, pick, chop, dig, hammer)

## Bug Fixes
- Fixed blueprint crash when spawning without player context
- Fixed title icon size reset on click
- Fixed missing entity icons for some creatures
- Fixed red textures appearing on entities like drying racks

## Improvements
- All entity icons now use 3D model rendering instead of flat textures
- Icon sizing and positioning synchronized with the official scrapbook detail view
- Improved Chinese and English localization
