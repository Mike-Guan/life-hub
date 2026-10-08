---
stage: engineering
updated: 2026-10-02
status: 生效
tags: [engineering, ci, cd, quality]
---

# CI/CD 与代码质量

> 目标：技术债在合并前就挡住，发版不靠手工。按一个人的项目来配，不加第三方依赖（格式检查用 Xcode / Swift 自带的 swift-format）。流程规则见 [[开发流程]]。

## 每个 PR 都会跑（`.github/workflows/ci.yml`）

| 检查 | 挡住什么 | 跑在哪 |
| --- | --- | --- |
| PR 标题和分支名 | 标题不是 `feat:` / `fix:` 这类格式，分支不是 `feature/` 等前缀 | Linux，几秒 |
| 格式 | 代码没按 `.swift-format` 格式化；日志里会列出该怎么改 | Linux（Swift 6.2 容器） |
| Lint | 强制 try、隐式解包可选值、分号、import 没排序、命名不规范等 | Linux |
| 单元测试 | HubCore 和 CompanionKit 的测试，编译警告一律当错误 | Mac |
| 覆盖率门槛 | HubCore（数据契约、mode 逻辑）的行覆盖率低于 80% | Mac |
| App 编译 | iOS 和 Mac 两个 App 都要能编译，警告当错误 | Mac |
| 手表启动 | 手表 App 在模拟器上开不起来、20 秒后进程没了，或者 10 秒里 CPU 忙到 80% 以上（HAKU 和 KURO 各开一次，截图作为产物上传）。脚本 `scripts/watch-launch-check.sh` | Mac |
| Companion 画法 | `RunnerArt.swift` 和 `runner-v5-layers.svg` 不一致（改了 SVG 没重新生成，或手改了生成文件） | Linux，几秒 |
| 角色配色 | App 代码里用了不带角色的模式色（`Mode.color`，那是 HAKU 的），会让 KURO 显示 HAKU 的颜色。改用 `Mode.color(for: persona)`；故意只给 HAKU 的行，行尾写 `// HAKU only: 原因`。脚本 `scripts/persona-colors.sh` | Linux，几秒 |

Linux 上的检查不占 Mac 额度（私有仓库 Mac 分钟按 10 倍算）。

改了 RUNNER 的 SVG 之后跑 `make art` 重新生成 `RunnerArt.swift`，`make art-check` 和 CI 用同样的方式检查。需要 Node。

合并时 PR 已经绿、GitHub 显示没有冲突，就直接合，不合新 `main` 重跑（Mike 2026-10-07，见 [[开发流程]]）。依据：332 次运行里 30 次真失败，29 次在第一次推送就抓到；95 次合并后重跑只多抓到 1 次。CI 配置本身没改。

## 发版（`.github/workflows/release.yml`）

| 触发 | 环境 | 做什么 |
| --- | --- | --- |
| 合并进 `main` | **STG** | 先跑完整 CI，再用 Staging 配置 Archive，上传 TestFlight（内部测试） |
| 推送 tag `vX.Y.Z` | **PROD** | 先检查 tag 和 `MARKETING_VERSION` 一致，跑完整 CI，再用 Release 配置上传 TestFlight |

- Build 号 = 1000 + 流水线运行次数，只增不减，App 和以后的小组件共用（经验 DW-05）。
- `ITSAppUsesNonExemptEncryption = NO` 已写进 Info.plist，上传后不会卡在出口合规（经验 DW-05）。
- 用 App Store Connect API Key 自动签名，证书和描述文件都由 Xcode 在云端管理，仓库里不放任何证书。

### 要 Mike 做一次的设置

没设之前，发版流水线会跑完 CI，然后提示“已跳过上传”，不会报错。

1. App Store Connect → 用户和访问 → 集成 → App Store Connect API → 新建密钥，权限选 **App 管理**，下载 `.p8`（只能下载一次）。
2. 在 App Store Connect 里新建 App（Bundle ID `com.guanshiyang.lifehub`）；STG 用的 `com.guanshiyang.lifehub.stg` 也建一个。
3. GitHub 仓库 → Settings → Secrets and variables → Actions，加 4 个 secret：
    - `ASC_KEY_ID`：密钥 ID
    - `ASC_ISSUER_ID`：页面上方的 Issuer ID
    - `ASC_KEY_P8_BASE64`：在 Mac 上运行 `base64 -i AuthKey_XXXX.p8 | pbcopy` 后粘贴
    - `DEVELOPMENT_TEAM`：开发者账号的 Team ID

第一次真正上传之后才算验证过这条流水线，在那之前它只是“写好了”。

### Screen Time（Family Controls）权限

- 「刷手机」用到 Family Controls。开发版（Debug，Xcode 直接装）自带开发权限，可以直接用。
- 上 TestFlight 和正式版要先用 Mike 的开发者账号向 Apple 申请 Family Controls 分发权限（Issue #23）。批下来之前，Staging 和 Release 的 entitlements 里没有它（`project.yml` 只在 Debug 用 `*-Debug.entitlements`），这样上传不会因为签名失败；这两个版本里点「选 App」会显示 Screen Time 没打开，RUNNER 用「晚上在家 + 没走动」兜底。
- 批下来以后：把 `com.apple.developer.family-controls` 加进 `Apps/iOS/LifeHub.entitlements` 和 `Apps/ScreenTime/LifeHubScreenTime.entitlements`，删掉两个 `-Debug` 文件和 `project.yml` 里的 Debug 覆盖。

## 动画录屏（`.github/workflows/recordings.yml`）

手动触发，或推送到 `chore/recordings` 分支时跑，不在 PR 和 `main` 上跑。iPhone 首页和手表表盘，每个模式 × 每个角色录 10 秒（不开减弱动态效果），手表另录加班，每段附一张最后一帧的截图，作为产物 `recordings` 上传（保留 14 天），同时强推到一次性分支 `out/recordings`（只有一个提交，不合并），给下载不了产物的线程用 git 取。不进 `main`。用来审动画。脚本 `scripts/recordings.sh`。

## 本地

```bash
make format   # 自动格式化
make lint     # 和 CI 一样的 lint
make check    # lint + 测试 + 覆盖率，推送前跑
make hooks    # 装 pre-commit：提交前自动 lint 改动的 Swift 文件
```

## 以后再加（现在加是过度设计）

- UI 截图测试：等界面稳定（M1a 之后）。
- 小组件、HealthKit、定位相关的流程按经验 L-QA 必须真机测，不放进 CI。
- 每次发版测一遍全新安装和升级安装（经验 L-QA）。数据层面的升级兼容已由数据契约测试覆盖。

## 已知限制

- 手表启动检查只能挡住模拟器上的明显卡死。真表熄屏启动的卡死在模拟器上复现不出来（2026-10-07），装手表前要按装机前 QA 清单 §5 在真表上检查。
- 目前只有 iOS 会上传 TestFlight。Mac 要先加 App Sandbox 权限，到 M1b 再接进发布流程。
- CI 的格式检查用 Swift 6.2 容器里的 swift-format，本地 `make format` 用的是 Xcode 自带的版本。两边版本不同时，可能本地格式没问题、CI 却报格式错误。这时以 CI 日志为准，或者把本地 Xcode 升级到和 CI 一样的 Swift 版本。
