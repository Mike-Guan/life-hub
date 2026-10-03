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

Linux 上的检查不占 Mac 额度（私有仓库 Mac 分钟按 10 倍算）。

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

- 目前只有 iOS 会上传 TestFlight。Mac 要先加 App Sandbox 权限，到 M1b 再接进发布流程。
- CI 的格式检查用 Swift 6.2 容器里的 swift-format，本地 `make format` 用的是 Xcode 自带的版本。两边版本不同时，可能本地格式没问题、CI 却报格式错误。这时以 CI 日志为准，或者把本地 Xcode 升级到和 CI 一样的 Swift 版本。
