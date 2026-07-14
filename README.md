# 专业大逃杀（Major Royale）

一款像素 2.5D 半开放世界肉鸽卡牌游戏。玩家选择大学专业作为战斗流派，在校园异化赛场中探索、构筑卡组、遭遇 AI Native 敌人，并在终极答辩中争夺“唯一上岸者”。

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

编辑 `.env`：

```env
AI_API_KEY=your_api_key_here
AI_BASE_URL=https://api.openai.com/v1
AI_MODEL=gpt-4o-mini
```

> 若不填写 API Key，AI Native 敌人会自动使用规则兜底，不影响主流程。

## 项目结构

```
major-royale/
├── assets/             # 字体、像素精灵、场景底图（见 assets/README.md）
├── data/               # JSON 数据：专业、卡牌、敌人、事件
├── src/
│   ├── autoload/       # 全局单例：Config、Settings、GameState 等
│   ├── logic/          # 战斗、地图、奖励、事件逻辑
│   ├── ai/             # Godot AI 客户端与规则兜底
│   ├── resources/      # 自定义 Resource 脚本
│   ├── server/         # Python FastAPI AI 服务
│   └── ui/             # Theme、色板、场景与控件
├── tests/              # 测试脚本
├── tools/Godot.app     # Godot 编辑器（自动下载）
└── project.godot       # Godot 项目文件
```

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
- **专业选择**：点击专业卡片进入游戏
- **地图探索**：点击可用节点移动，⚙ 图标打开设置
- **战斗**：点击手牌出牌，点击“技能”使用专业主动技能，点击“结束回合”
- **奖励/事件**：按提示选择
- **ESC**：返回或继续

## 测试

### 运行全部测试

```bash
source .venv/bin/activate
python test_game.py
```

### 单独运行 Python 测试

```bash
source .venv/bin/activate
pytest tests/ -v
```

### 单独运行 Godot 自动化测试

```bash
tools/Godot.app/Contents/MacOS/Godot --headless --path . --scene tests/test_runner.tscn
```

## 调试

- **Godot 调试**：在编辑器中设置断点，使用远程场景树和输出面板。
- **AI 服务调试**：设置 `.env` 中 `AI_DEBUG=true` 查看请求日志。
- **数据校验**：修改 `data/` 下 JSON 后，运行 `pytest tests/test_data.py -v` 自动校验。

## 已知问题

1. 音效为占位实现，使用程序生成简单波形。
2. 像素美术为占位资源，使用 ColorRect 和 Label 表示。
3. 2.5D 地图当前为节点地图，斜 45 度视角为简化实现。
4. 部分卡牌效果（如费用修改）尚未完全实现。
5. Godot headless 测试退出时可能有资源泄漏警告，不影响游戏运行。

## 开发阶段 Commit 记录

每个阶段已完成一次本地中文 commit，未 push 到远程。可通过 `git log --oneline` 查看。

## 后续扩展

- 更多专业（土木、金融、艺术等）
- 更多 AI Native 敌人
- 转专业 / 辅修系统
- 精致像素美术与动画
- 多结局分支
