# Assets 资源管线

```
assets/
├── fonts/          # UI 字体（开源中文字体）
├── audio/          # 音效 / BGM（可先空，程序占位音效仍可用）
└── sprites/
    ├── ui/         # HUD 图标、边框装饰、locations/ 建筑热点
    ├── chars/      # 玩家 / 敌人像素立绘
    ├── cards/      # 卡牌 ID 插画与类型回退图标
    └── bg/         # 菜单 / 探索 / 战斗场景底图
```

色板见 `src/ui/ui_colors.gd`。当前字体：LXGW WenKai（SIL OFL 1.1）。

## 命名与尺寸

| 类别 | 命名 | 交付尺寸 | 透明 |
| --- | --- | --- | --- |
| 背景 | `{scene}.png` | 1280×720 | 否 |
| 角色 | `player_{major}.png` / `enemy_{id}.png` | 最短边 ≥384、完整包围盒 | 是 |
| 卡牌插画 | `{card_id}.png` | 256×256 | 是 |
| 卡牌类型回退 | `{card_type}.png` | 96×96 | 是 |
| UI / 地点图标 | 语义化英文名 `.svg` | 64×64 viewBox | 是 |

运行时不直接引用生成器原图，只引用上述标准化资产。108 张正式卡牌均应具备与卡牌 ID 同名的 256×256 插画；专业核心牌和类型图标只作为异常回退。

批量卡牌表可用项目自带工具切片：

```bash
tools/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/slice_card_sheet.gd -- \
  --sheet=/绝对路径/卡牌表.png --columns=4 --rows=4 \
  --ids=card_a,card_b,... --output=res://assets/sprites/cards
```

切片工具会按比例计算边界，兼容生成器输出尺寸不能被网格数整除的情况，并统一缩放到 256×256。

## Godot 导入清单

- 图片使用 PNG 或 SVG，禁止有损压缩和内嵌 ICC 特效。
- 像素素材节点必须使用 `TEXTURE_FILTER_NEAREST`，关闭重复纹理。
- 背景不得烘焙人物、文字、按钮、状态栏或任务标记。
- 透明角色先以纯色键背景生成，再去色键；检查四角 Alpha、彩边和脚部完整性。
- 接入前检查目标尺寸、长宽比、透明通道和 1280×720 实机遮挡关系。
- 每批素材在 `assets/art_manifest.json` 登记生成方式、提示版本和游戏内路径。

## 分层约定

- `bg/` 只放不会遮挡角色和交互标记的静态底图。
- 需要遮挡玩家的树冠、门楣等前景，在场景中作为独立节点引用，并使用 `_foreground` 后缀。
- 角色、热点和效果不得合并到背景，保证移动、受击、悬停和压力圈动效可独立控制。
