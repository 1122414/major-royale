# 专业大逃杀（Major Royale）— 1.1.0-vertical-slice

一款像素 2.5D 半开放世界动作卡牌肉鸽。玩家选择大学专业作为战斗流派，在校园异化赛场中探索、构筑卡组、通过实时答辩窗口应对敌方追问，并在终极答辩中争夺“唯一上岸者”。

## 版本

- **当前版本**：`1.1.0-vertical-slice`
- **引擎**：Godot 4.4
- **平台**：Windows / macOS 桌面
- **网络**：默认完整离线；在线 AI 增强为可选项

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

> 在线 AI 默认关闭。不开服务、不填写 API Key 或完全断网时，AI Native 敌人会使用本地白名单策略，不影响主流程。

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

- **主菜单**：开始/继续游戏、新开一局、设置、退出；一局进度会在安全节点自动保存
- **专业选择**：从计算机 / 法学 / 医学 / 金融 / 艺术中选择；每个预设专业有三条卡面标注的构筑流派，也可点买八维创建自定义专业
- **校园探索**：WASD / 方向键 / 左摇杆移动，靠近建筑后按 `E` 或手柄 `A` 交互；顶栏查看生命、精神与压力圈
- **战斗**：鼠标或手柄焦点选择卡牌；使用专业技能；结束回合后用 `A/D`、方向键或左摇杆换位，`Space` / 手柄 `A` 确认答辩窗口
- **答辩窗口**：安全换位可减伤并避开控制；留在危险位抓准金色刻度可打断、反击并获得下回合能量
- **暂停与辅助**：`Esc` / 手柄 `Start` 打开设置；可调整答辩反应时间、减少动态效果并关闭震动
- **AI Native 战**：左侧档案、右侧可选行动高亮
- **奖励**：三选一；若选新卡可再点具体卡牌
- **卡牌关键词**：0 费牌带“消耗”，每场战斗只能使用一次；专业终结牌会读取 Bug、拖延、流血、护盾、手牌或本回合连击
- **ESC**：返回或继续

## 导出打包

本地交付验证产物位于 `build/mac/MajorRoyale.app` 与 `build/win/MajorRoyale.exe`；`build/` 已加入忽略列表，不进入源码提交。推荐使用候选包脚本，它会预检模板、导入资源、导出双平台包、附带隐私/许可文件并生成 SHA-256 摘要。

1. 在 Godot 编辑器：**编辑器 → 管理导出模板**，安装与引擎版本完全匹配的 `4.4.1.stable` 模板。
2. 打开 **项目 → 导出**，使用预设：
   - `macOS` → `build/mac/MajorRoyale.app`
   - `Windows Desktop` → `build/win/MajorRoyale.exe`
3. 或运行候选包脚本（需已安装模板）：

```bash
tools/export_mvp.sh
```

导出预设见仓库根目录 `export_presets.cfg`。Steamworks 账号、AppID、签名证书与 SteamPipe 人工步骤见 `Plan_/7.17/2026-07-18_Steam上线检查清单.md`。

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
2. 当前版本集中在一张校园地图和五区递进路线，已接通 9 场资格战与终局 Boss，尚未扩展为多地图世界。
3. Steam 成就、Steam Cloud、真实 AppID、商店素材、签名公证与 Valve 审核需要发行方账号或证书，仓库不会伪造完成状态。
4. Windows 最终候选包仍需在独立 Windows/Steam 环境完成从安装到通关的实机验收。

隐私说明见 [PRIVACY.md](PRIVACY.md)，第三方许可见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 更新记录（1.1.0-vertical-slice）

- 以四张参考图为锚点重做主菜单、五专业选择、自由校园探索、普通战与 AI Native 精英战
- 补齐五专业、十名敌人、专业核心卡牌与终局战正式像素素材
- 接通五建筑事件、奖励、牌组、属性、遗物、Boss、成就与本局总结
- 补齐 108 张卡牌独立插画、动作答辩窗口、手柄/辅助选项与版本化安全存档
- 整理五专业各三条构筑流派，加入流派分散奖励、消耗牌与五种专业终结结算
- 移除旧线性节点地图，修复战斗引用环、音频停播与正常退出清理
- 完成 1280×720、1600×900、1920×1080 回归与双平台导出流程
