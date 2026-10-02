---
tags: [energy-bank, companion, rive]
updated: 2026-10-02
---

# RUNNER 夜跑者：Rive 搭建步骤

角色设定见 [RUNNER 角色设定](https://claude.ai/artifact/Vny8JZBtb37WtkUkKiwUPY)。这份是在 Rive 编辑器里把它做成一个能切 mode 的动画文件的步骤。做完得到一个 `runner.riv`，App 往里塞 mode 和 energy，角色自己动。

## 先知道的三件事

1. **Rive 已经不推荐用状态机 Inputs 了。** 官方文档把 Inputs 标为旧系统，新项目用 Data Binding（View Model）。所以设定页里的 `mode / energy / tap / cheer` 在这里都做成 View Model 属性，效果一样。
2. **免费版可以导出 .riv，但会带一个 Rive 启动画面。** 去掉要 Cadet 档，$9/月（2026-10-02 官网价格页）。自己用先免费就够。
3. **分层素材已经准备好。** `runner-v5-layers.svg` 里每个零件都是一个命名的组，四个 mode 的眼睛、面罩、道具全叠在一起，导入后看起来会很乱，这是正常的，下面用 Solo 收起来。四张 `runner-v5-<mode>.svg` 是每个 mode 的完成图，当参考。

## 第 1 步：建文件，导入素材

1. 新建文件 `runner`，画板改名 `RUNNER`，尺寸 480 × 504。
2. 把 `runner-v5-layers.svg` 拖进画板。
3. 打开左边的 Hierarchy，对一下组名，应该是下面这棵树。名字没带过来的话手动改，后面绑定都靠名字。
4. 面罩上的 `¥¥` 是文字，SVG 里的文字可能导不进来。导不进来就在 `led` 组里用 Text 工具重新打一个 `¥¥`，金色 #FFD23F，命名 `led_yen`。
5. 在最底层加一个铺满画板的矩形，命名 `bg_mode`，背景色后面跟 mode 变。

```
RUNNER
├─ bg_mode
├─ body: jacket, stripe_neon, hood_collar
├─ head
│  ├─ hair_back, ear_L, ear_R, face_base
│  ├─ eyes: eyes_work, eyes_chill, eyes_box, eyes_money
│  ├─ mouth: mouth_smile, mouth_fang
│  ├─ mask
│  │  ├─ mask_up: panel_lines, led (led_line, led_yen)
│  │  └─ mask_down
│  ├─ hair_fringe, earring_neon, earbud, headband
└─ props: headset (cup_L, cup_R, mic), glove_L, glove_R, monster_can, chain_gold
```

## 第 2 步：把互斥的零件包成 Solo

Solo 一次只显示一个子元素，正好用来切表情和面罩。在 Hierarchy 里选中这些组，右键 **Wrap in Solo**：

| Solo | 子元素 | 说明 |
|---|---|---|
| `eyes` | eyes_work / eyes_chill / eyes_box / eyes_money | 四套眼睛 |
| `mouth` | mouth_none / mouth_smile / mouth_fang | 先建一个空组 `mouth_none`，戴面罩时用 |
| `mask` | mask_up / mask_down | 戴在脸上或拉到脖子 |
| `led` | led_off / led_line / led_yen | 先建一个空组 `led_off` |

其他道具（headset、headband、两只拳套、monster_can、chain_gold、earbud、earring_neon）不用 Solo，在动画里调透明度 0 / 100。

## 第 3 步：调好会动的组的中心点

- `head`：旋转中心挪到脖子，大约 (60, 100)。点头、弹跳都绕这里转。
- `monster_can`：中心挪到罐底，喝的时候绕手腕转。
- `glove_L` / `glove_R`：中心挪到拳套后面，出拳往前推。
- 第一版不用骨骼。等做拳击侧面站姿时再给手臂加骨骼。

## 第 4 步：建 View Model

1. 在 **Data** 面板点 `+`，先建一个 **Enum**，命名 `Mode`，值依次为 `work`、`chill`、`box`、`money`。
2. 再点 `+` 选 **View Model**，命名 `Runner`，点 **Add View Model Property** 加四个属性：

| 属性 | 类型 | 默认值 | 用途 |
|---|---|---|---|
| `mode` | Enum（Mode） | work | 当前 mode，App 写入 |
| `energy` | Number | 80 | 0–100，来自 iOS 状态判断；低于 30 显示没电 |
| `tap` | Trigger | | 点角色时触发，Rive 里也能自己触发 |
| `cheer` | Trigger | | 完成一件事时由 App 触发 |

3. 把 `Runner` 的默认实例挂到 `RUNNER` 画板上。

## 第 5 步：做动画

在 Animate 模式下建下面这些时间线。每个 mode 的“姿势”放在它待机动画的第 0 帧：设好 Solo 显示哪个子元素、道具透明度、外套颜色和背景色。

| 时间线 | 类型 | 时长 | 内容 |
|---|---|---|---|
| `idle_work` | Loop | 2.4s | 第 0 帧：eyes_work，mask_up，led_line，headset 显示，外套 #1B1C26，背景 #7FB7FF。之后头每 0.5s 点一下，LED 透明度 60↔100 呼吸，2s 处眼皮慢慢眨一次 |
| `idle_chill` | Loop | 8s | 第 0 帧：eyes_chill，mouth_smile，mask_down，monster_can 和 earbud 显示，外套 #3A6B58，背景 #8FDB9E。全程身体左右晃，周期 3s；6.8s 到 8s 举罐喝一口 |
| `idle_box` | Loop | 2s | 第 0 帧：eyes_box，mouth_fang，mask_down，headband 和两只拳套显示，背景 #FF7A6B。每 0.6s 小跳一次，拳套交替上下，右眼光晕透明度 20↔60 |
| `idle_money` | Loop | 4s | 第 0 帧：eyes_money，mask_up，led_yen，chain_gold 显示，外套 #121219，背景 #FFD25C。链子上一道白色高光从左扫到右，¥¥ 左右缓慢平移 |
| `pop` | One shot | 0.12s | 整个 RUNNER 压扁到 105% × 92% 再弹回，旁边一颗黑色四角星闪一下。每次切 mode 先播它 |
| `tap_work` / `tap_chill` / `tap_box` / `tap_money` | One shot | 0.5–0.8s | 翻白眼加 LED 变 “...”／举罐干杯／刺拳加直拳／抛硬币 |
| `cheer` | One shot | 0.8s | 跳起来，撒几颗星星，所有 mode 通用 |
| `tired` | Loop | 3s | 眼皮再压低，eyebags 加深，整体动作变慢；只改叠加的部分，不碰姿势 |

动画里切 mode 的过渡（耳机落下、拉下面罩、头带一甩）第一版先不做，用 `pop` 盖过去，效果够了再加。

## 第 6 步：搭状态机

新建状态机，命名 `Runner`，加三个图层（Layer）：

**图层 1：mode**
- 四个待机状态：`idle_work`、`idle_chill`、`idle_box`、`idle_money`，Entry 连到 `idle_work`。
- 再建四个过渡状态 `pop_work`、`pop_chill`、`pop_box`、`pop_money`，都用同一段 `pop` 动画，播完分别自动进对应的待机状态。
- 从 **Any State** 拉线到四个 `pop_` 状态，条件分别是 `mode` = work / chill / box / money。
- 播的时候看一下：如果 mode 没变它也在反复弹，就不要从 Any State 连，改成从另外三个待机状态分别连过来。

**图层 2：反应**
- 一个空状态 `rest`，Entry 连到它。
- Any State → `tap_work`，条件：`tap` 触发并且 `mode` = work。其他三个 mode 同理。播完回 `rest`。
- Any State → `cheer`，条件：`cheer` 触发。播完回 `rest`。

**图层 3：没电**
- 两个状态：`fresh`（空）和 `tired`。
- `fresh` → `tired`：`energy` < 30。`tired` → `fresh`：`energy` ≥ 30。

**点击**
- 在角色身上加一个透明矩形当点击区域，加一个 Listener：Target 选它，Listen To 选 **Pointer Down**，Action 选改 View Model 属性，触发 `tap`。这样不用写代码也能点。

## 第 7 步：测试和导出

1. 播放状态机，在 Data 面板里直接改 `mode`、`energy`，点 `tap`、`cheer`，看四个 mode 和没电状态都对。
2. 导出 `.riv`，文件名 `runner.riv`，放回这个文件夹。

## 第 8 步：App 里怎么用（给工程那边参考）

App 只做三件事：写 `mode`，写 `energy`，在需要时触发 `cheer`。用 rive-ios（MIT，iOS 14+，macOS 13.1+）的数据绑定，大致是这样：

```swift
import RiveRuntime

let runner = RiveViewModel(fileName: "runner", stateMachineName: "Runner")

runner.riveModel?.enableAutoBind { instance in
    instance.enumProperty(fromPath: "mode")?.value = "box"
    instance.numberProperty(fromPath: "energy")?.value = 42
    instance.triggerProperty(fromPath: "cheer")?.trigger()
}

// SwiftUI 里：runner.view()
```

Rive 也有一套更新的异步 API（`File`、`Worker`、`AsyncRiveUIViewRepresentable`），用哪套由技术框架那边定。

## 参考

- Data Binding 概念：https://rive.app/docs/editor/data-binding/overview
- View Model：https://rive.app/docs/editor/data-binding/view-models
- Solo：https://rive.app/docs/editor/manipulating-shapes/solos
- Listener：https://rive.app/docs/editor/state-machine/listeners
- Inputs 已弃用的说明：https://rive.app/docs/editor/state-machine/inputs
- Apple 运行时：https://rive.app/docs/runtimes/apple/apple
- 价格：https://rive.app/pricing
