# 专业大逃杀（Major Royale）— 1.1.0-vertical-slice

一款像素 2.5D 半开放世界肉鸽卡牌游戏。玩家选择大学专业作为战斗流派，在校园异化赛场中探索、构筑卡组、遭遇 AI Native 敌人，并在终极答辩中争夺“唯一上岸者”。

## 版本

- **当前版本**：`1.1.0-vertical-slice`
- **引擎**：Godot 4.4
- **平台**：Windows / macOS 桌面

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
- **专业选择**：从计算机 / 法学 / 医学 / 金融 / 艺术中选择，或点买八维创建自定义专业
- **校园探索**：WASD / 方向键移动，靠近建筑后按 `E` 交互；顶栏查看生命、精神与压力圈
- **战斗**：点击手牌出牌；技能；结束回合
- **AI Native 战**：左侧档案、右侧可选行动高亮
- **奖励**：三选一；若选新卡可再点具体卡牌
- **ESC**：返回或继续

## 导出打包

本地交付验证产物位于 `build/mac/MajorRoyale.app` 与 `build/win/MajorRoyale.exe`；`build/` 已加入忽略列表，不进入源码提交。

1. 在 Godot 编辑器：**编辑器 → 管理导出模板**，安装与引擎版本完全匹配的 `4.4.1.stable` 模板。
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
python -m pytest tests/ -v
tools/Godot.app/Contents/MacOS/Godot --headless --path . --scene tests/test_runner.tscn
```

## 演示材料

见 [docs/DEMO.md](docs/DEMO.md)。仓库内含 43 秒无声预览；完整演示应覆盖主菜单与五专业、自由校园探索、普通战、AI Native 精英战、奖励和终局总结。

## 已知边界

1. 角色目前使用静态立绘与程序动效，尚未制作逐帧行走/攻击动画图集。
2. 音效与 BGM 为可替换的轻量 WAV；资源路径与循环已接通。
3. 当前竖切集中在一张校园地图和五个建筑热点，尚未扩展为多地图世界。
4. AI 服务失败时使用同一行动白名单的本地规则兜底，不中断战斗。

## 更新记录（1.1.0-vertical-slice）

- 以四张参考图为锚点重做主菜单、五专业选择、自由校园探索、普通战与 AI Native 精英战
- 补齐五专业、十名敌人、专业核心卡牌与终局战正式像素素材
- 接通五建筑事件、奖励、牌组、属性、遗物、Boss、成就与本局总结
- 移除旧线性节点地图，修复战斗引用环、音频停播与正常退出清理
- 完成 1280×720、1600×900、1920×1080 回归与双平台导出流程
