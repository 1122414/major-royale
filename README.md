# 专业大逃杀（Major Royale）

一款像素 2.5D 半开放世界肉鸽卡牌游戏。玩家选择大学专业作为战斗流派，在校园异化赛场中探索、构筑卡组、遭遇 AI Native 敌人，并在终极答辩中争夺“唯一上岸者”。

## 技术栈

- **游戏本体**：Godot 4.x + GDScript
- **AI 决策服务**：Python + FastAPI
- **数据配置**：JSON
- **测试**：pytest + Godot 场景测试

## 环境准备

1. 安装 Python 3.10+。
2. 安装项目依赖：

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

3. 复制环境变量模板并填入 LLM API Key：

```bash
cp .env.example .env
```

编辑 `.env`：

```env
AI_API_KEY=your_api_key_here
AI_BASE_URL=https://api.openai.com/v1
AI_MODEL=gpt-4o-mini
```

## 运行方式

1. 启动 AI 决策服务：

```bash
source .venv/bin/activate
python run_ai_server.py
```

2. 使用 Godot 编辑器打开 `project.godot`，按 F5 运行游戏。

## 测试

```bash
source .venv/bin/activate
python test_game.py
```

或：

```bash
pytest tests/ -v
```

## 开发阶段

每完成一个阶段进行一次本地中文 commit，不 push。
