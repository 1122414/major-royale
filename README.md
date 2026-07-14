# 专业大逃杀（Major Royale）— 1.0.0-mvp

一款像素 2.5D 半开放世界肉鸽卡牌游戏。玩家选择大学专业作为战斗流派，在校园异化赛场中探索、构筑卡组、遭遇 AI Native 敌人，并在终极答辩中争夺“唯一上岸者”。

## 版本

- **当前版本**：`1.0.0-mvp`
- **引擎**：Godot 4.4
- **平台**：Windows / macOS 桌面（导出预设已提供，需本机安装导出模板后打包）

## 技术栈

- **游戏本体**：Godot 4.x + GDScript
- **AI 决策服务**：Python + FastAPI
- **数据配置**：JSON
- **测试**：pytest + Godot 自动化场景

## 环境准备

1. 安装 Python 3.10+。
2. 安装项目依赖：

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

3. 复制环境变量模板并填入 LLM API Key（如需使用 AI Native 敌人）：

```bash
cp .env.example .env
```

> 若不填写 API Key，AI Native 敌人会自动使用规则兜底，不影响主流程。

## 项目结构

```
major-royale/
├── assets/             # 字体、像素精灵、场景底图（见 assets/README.md）
├── data/               # JSON 数据：专业、卡牌、敌人、事件
├── docs/               # 演示录制说明等交付文档
├── src/
│   ├── autoload/       # 全局单例：Config、Settings、GameState 等
│   ├── logic/          # 战斗、地图、奖励、事件逻辑
│   ├── ai/             # Godot AI 客户端与规则兜底
│   ├── resources/      # 自定义 Resource 脚本
│   ├── server/         # Python FastAPI AI 服务
│   └── ui/             # Theme、色板、场景与控件
├── tests/              # 测试脚本
├── tools/Godot.app     # Godot 编辑器
└── project.godot       # Godot 项目文件
```

美术与字体资源约定见 `assets/README.md`。色板见 `src/ui/ui_colors.gd`。

## 运行方式

### 1. 启动 AI 决策服务（可选）

```bash
source .venv/bin/activate
python run_ai_server.py
```

服务默认运行在 http://127.0.0.1:8000。

### 2. 启动游戏

用 Godot 编辑器打开 `project.godot`，按 F5 运行。

或使用命令行：

```bash
tools/Godot.app/Contents/MacOS/Godot --path .
```

### 3. 游戏操作

- **主菜单**：开始游戏、设置、退出
- **专业选择**：点击专业卡片进入游戏（计算机 / 法学 / 医学）
- **地图探索**：点击可用节点移动；顶栏查看 HP/精神/压力圈
- **战斗**：点击手牌出牌；技能；结束回合
- **AI Native 战**：左侧档案、右侧可选行动高亮
- **奖励**：三选一；若选新卡可再点具体卡牌
- **ESC**：返回或继续

## 导出打包

1. 在 Godot 编辑器：**编辑器 → 管理导出模板**，安装与引擎版本匹配的模板（4.4.x）。
2. 打开 **项目 → 导出**，使用预设：
   - `macOS` → `build/mac/MajorRoyale.app`
   - `Windows Desktop` → `build/win/MajorRoyale.exe`
3. 或命令行（需已安装模板）：

```bash
tools/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS" build/mac/MajorRoyale.app
tools/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Windows Desktop" build/win/MajorRoyale.exe
```

导出预设见仓库根目录 `export_presets.cfg`（若被 gitignore，本地保留即可）。

## 测试

```bash
source .venv/bin/activate
python test_game.py
# 或
pytest tests/ -v
tools/Godot.app/Contents/MacOS/Godot --headless --path . --scene tests/test_runner.tscn
```

## 演示材料

见 [docs/DEMO.md](docs/DEMO.md)。建议录制 60–90 秒：菜单 → 选专业 → 探索 → 战斗 →（可选 AI）→ 奖励。

## 已知问题 / MVP 边界

1. 像素美术为程序生成占位精灵，后续可替换 `assets/sprites/`。
2. 音效仍为程序波形占位。
3. 探索为节点图，非自由 2.5D 角色移动。
4. 导出包需本机安装 Godot 导出模板后生成。
5. AI 服务失败时规则兜底，不中断战斗。

## 更新记录（1.0.0-mvp）

- 肉鸽牌组 / 属性 / 生命跨战斗持久化
- 地图刷出 AI Native；压力圈伤害缩放与终局解锁
- 主菜单 / 选专业 / 探索 / 战斗 UI 对齐赛博校园参考布局
- AI Native 专属侧栏与行动展示
- 敌人动作补全；Boss 群面限手；终局「唯一上岸者」文案
- 像素场景底图与角色/卡面占位资源
