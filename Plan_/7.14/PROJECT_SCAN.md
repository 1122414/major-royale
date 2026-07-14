# 专业大逃杀 — 项目扫描与 MVP 差距（Agent 速读）

> 生成日期：2026-07-14  
> 对照计划：`Plan_/MVP/20260706-major-royale-mvp.md`  
> 用途：给开发 Agent 快速建立上下文，避免重复扫仓库。

---

## 0. 一句话结论

**骨架已通、主流程可跑；肉鸽成长未贯通、AI Native 未进局、打包未交付。**  
相对 MVP 计划约 **70–75%**；离「可演示可验收的 v1.0-mvp」还差 **1 轮集成修复 + 阶段 9 打包**。

---

## 1. 项目身份

| 项 | 值 |
|---|---|
| 名称 | 专业大逃杀（Major Royale） |
| 定位 | 2.5D 半开放探索 + 肉鸽卡牌 + 专业流派 + 少量 AI Native 敌人 |
| 引擎 | Godot 4.4（`project.godot`） |
| 版本号 | `0.1.0-mvp` |
| AI 服务 | Python FastAPI（`src/server/`，`run_ai_server.py`） |
| 数据 | JSON 驱动（`data/`） |
| 主场景 | `res://src/ui/screens/menu.tscn` |
| 平台目标 | Win / macOS 桌面（计划）；**尚未导出** |

---

## 2. 目录地图（只记源码，忽略 .venv / .godot）

```
major-royale/
├── Plan_/MVP/20260706-major-royale-mvp.md   # 目标规格
├── Plan_/7.14/PROJECT_SCAN.md               # 本文件（扫描快照）
├── data/                                    # 配置真相源
│   ├── majors/     computer | law | medicine
│   ├── cards/      common + 3 majors
│   ├── enemies/    normal | elite | boss | ai_native
│   └── events/     5 区域各 2 条
├── src/
│   ├── autoload/   Config, GameState, Settings, EventBus, AudioManager
│   ├── logic/      battle, map, reward, event_handler, status, character, card_effect_processor
│   ├── resources/  *Resource.from_dict 解析器
│   ├── ai/         client.gd, fallback_ai.gd, fallback.py
│   ├── server/     api.py, prompts.py
│   └── ui/screens/ menu → major_select → map_explore → battle → result → reward → settings
├── tests/          pytest + Godot headless runner
├── assets/         空目录（audio/fonts/sprites）
├── tools/Godot.app
└── project.godot
```

### Autoload 一览

| 单例 | 文件 | 职责 |
|---|---|---|
| Config | `src/autoload/config.gd` | 启动加载全部 JSON → Resource |
| GameState | `src/autoload/game_state.gd` | 场景切换、run 状态 |
| Settings | `src/autoload/settings.gd` | AI/音量/全屏 → `user://settings.cfg` |
| EventBus | `src/autoload/event_bus.gd` | 信号总线（当前几乎未接线） |
| AudioManager | `src/autoload/audio_manager.gd` | 程序生成占位 beep |
| AIClient | `src/ai/client.gd` | HTTP `/decide` |

### 主流程（实际接线）

```
menu → major_select → start_run → map_explore
  ├─ BATTLE/ELITE/BOSS → battle → result
  │     ├─ 胜 → reward → ESC → map
  │     └─ 负 → menu
  ├─ EVENT → 弹窗 → map
  └─ REST → +15 HP → map
```

---

## 3. 数据盘点（截至扫描日）

| 类别 | 数量 | 路径 / ID |
|---|---|---|
| 专业 | 3 | computer, law, medicine |
| 通用卡 | 3 | strike, defend, draw_card |
| 专业卡 | 5×3=15 | 与计划示例基本对齐 |
| 普通敌人 | 5 | gpa_anxiety … client_phantom |
| 精英 | 2 | all_nighter_king, sports_ace |
| Boss | 1（3 阶段） | employment_pressure |
| AI Native | 2（仅数据） | ai_interviewer, paper_reviewer |
| 事件 | 10（每区 2） | dorm…playground |

---

## 4. 开发阶段对照（计划 §13）

| 阶段 | 计划内容 | 状态 | 证据 |
|---|---|---|---|
| 0 | 仓库初始化 | ✅ | `4f98082` + Godot 可开 |
| 1 | 地图探索 | ⚠️ 节点图，非角色移动 | `map.gd` / `map_explore.gd` |
| 2 | 专业选择 + 八维 | ✅（另有自定义专业 UI） | `major_select.gd` |
| 3 | 卡牌战斗核心 | ✅ | `battle.gd` draw5/energy3 |
| 4 | 三专业卡组技能 | ✅ | 主动+被动已接线 |
| 5 | 奖励/事件/压力 | ⚠️ UI 有，成长不持久 | 见 §5 |
| 6 | 敌人 + Boss | ⚠️ Boss 阶段简化；部分动作未执行 | 见 §5 |
| 7 | AI Native | ⚠️ 服务+兜底有，**地图不刷** | `map.gd:_assign_data_id` |
| 8 | UI/音效打磨 | ✅ 占位级完成 | `c21f25b` |
| 9 | 打包 + README + 演示视频 | ❌ | 无 export、无视频 |

Git 已有阶段 0–8 中文 commit；另有修复与自定义专业：`7ed7d81`, `f045ee0`。

---

## 5. 必须修的缺口（按对 MVP 验收影响排序）

### P0 — 阻塞「真正肉鸽一局」

1. **奖励不进下一场战斗**  
   - `reward.gd` 写入 `deck_additions` / `permanent_stats`  
   - `battle.gd` 的 `_create_player()` **只读 `major.starter_deck`**，忽略 `GameState.player_deck` / `deck_additions` / `permanent_stats`  
   - 每场战斗 **HP 重置满血**，局内损耗不延续

2. **AI Native 永不进局**  
   - 数据与服务完备（`ai_native_enemies.json` + FastAPI + fallback）  
   - `GameMap._assign_data_id()` 只分配 normal/elite/boss，**从不选 AI Native**

3. **`NodeType.REWARD` 死代码**  
   - 枚举与图标有，`_pick_node_type()` 从不生成

### P1 — 体验 / 计划一致性

4. **压力圈只是计数器**（`run_progress` 标签），无缩圈、无强度缩放、无终局门控  
5. **敌人 JSON 动作 `charge` / `counter` / `defend` 部分未在 `_execute_enemy_turn` 完整落地**  
6. **`bleed` 有 tick、无施加源**；`resistance` 有定义、无战斗逻辑  
7. **宿舍事件缺 `area` 字段** → 被当成全局事件池污染  
8. **奖励屏卡牌三选一实际恒取 `options[0]`**  
9. **Boss 阶段 2 缺「召唤小兵 / 限制手牌」**（计划 §9.5）  
10. **AI `ending_flag` 写入意图后未消费**（无结局分支）  
11. **结算文案通用**，缺「唯一上岸者」终局感

### P2 — 交付物（阶段 9）

12. 无 `export_presets.cfg` / 无 Win·macOS 包  
13. 无 1 分钟演示视频  
14. `assets/` 空；美术与音效均为程序占位（计划允许，但交付感弱）  
15. 版本号仍 `0.1.0-mvp`，未到 `v1.0-mvp`

### 计划允许的简化（不算缺口）

- 节点地图代替真 2.5D 自由移动（README 已声明）  
- ColorRect / Label / 程序 beep 占位  
- 不做联网、不做精致动画、不做商业化

---

## 6. MVP「必须做」清单打分（计划 §2.1）

| # | 要求 | 判定 |
|---|---|---|
| 1 | 单人离线主流程 | ✅ |
| 2 | 2.5D 地图移动/区域/交互 | ⚠️ 节点图可交互 |
| 3 | 3 专业 | ✅ |
| 4 | 八维 + 初始卡组 + 主动/被动 | ✅ |
| 5 | 卡牌战斗循环 | ✅ |
| 6 | 肉鸽奖励 | ⚠️ 有屏无成长 |
| 7 | 5 区域 | ✅ |
| 8 | 普通/精英/Boss | ✅ 内容；⚠️ 机制深度 |
| 9 | ≥2 AI Native | ⚠️ 数据+服务；❌ 遭遇 |
| 10 | 完整一局到终局 | ⚠️ 能打到 Boss，构筑感弱 |
| 11 | 中文 UI + 占位音效美术 | ✅ |
| 12 | 每阶段中文 commit | ✅（0–8） |

**功能验收 §14.1：** 约 8/10 表面可过，**#6 #7 实质未过**。

---

## 7. 关键代码锚点（改缺口时直达）

| 主题 | 文件 | 注意 |
|---|---|---|
| 开局 / 场景路由 | `src/autoload/game_state.gd` | `player_deck` 字段已有但未用 |
| 开战造玩家 | `src/ui/screens/battle.gd` `_create_player` | **必须合并奖励** |
| 战斗核心 | `src/logic/battle.gd` | AI 决策、Boss 阶段、技能 |
| 地图生成 | `src/logic/map.gd` | 刷 AI Native / REWARD |
| 奖励应用 | `src/ui/screens/reward.gd` | 选卡逻辑 |
| 事件 | `src/logic/event_handler.gd` | area 过滤 |
| AI 客户端 | `src/ai/client.gd` + `fallback_ai.gd` | 超时兜底 |
| AI 服务 | `src/server/api.py` | `/decide` |

---

## 8. 建议下一轮工作顺序（最小闭环）

1. **持久化一局成长**：HP / 牌组 / permanent_stats 跨战斗  
2. **地图刷出 AI Native**（教学楼/图书馆节点）  
3. 补敌人动作分支 + 宿舍 `area` + 奖励三选一 UI  
4. 压力圈给一点机械效果（例如进度≥N 解锁终局或加伤）  
5. 阶段 9：导出预设、打 macOS/Win 包、更新 README 版本、录演示

完成后可将 `project.godot` 版本升到 `1.0.0-mvp`，并补 commit：`完成 MVP 打包交付与说明文档`。

---

## 9. 四项核心验证（计划 §1）对照

| 验证目标 | 现状 |
|---|---|
| 专业能否形成可传播流派 | **部分**：技能差异有，但无构筑成长则难以体现 |
| 2.5D 探索能否承载氛围 | **弱通过**：节点校园可玩，氛围依赖占位 UI |
| 卡牌肉鸽构筑乐趣 | **未达标**：奖励不进牌组 = 无构筑 |
| AI Native 行为差异 | **未达标**：局内碰不到 |

---

## 10. 快速命令

```bash
# AI 服务（可选）
source .venv/bin/activate && python run_ai_server.py

# 跑游戏
tools/Godot.app/Contents/MacOS/Godot --path .

# 测试
python test_game.py
# 或
pytest tests/ -v
tools/Godot.app/Contents/MacOS/Godot --headless --path . --scene tests/test_runner.tscn
```

---

*本文件随仓库演进应更新；以代码与 `data/` 为准，不以 commit message 为准。*
