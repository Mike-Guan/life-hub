# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/). Versions follow SemVer (see `docs/05 Engineering/开发流程.md`).

## [Unreleased]

### Added
- Bedtime look for RUNNER: at bedtime RUNNER takes the headset off, pulls the mask down, yawns,
  stretches and leans onto a pillow ("该睡了"), then stays sleepy with slow blinks, yawns and Z z z.
  A short loop for the notification and a sleepy still portrait (full or head only) for widgets.
- iPhone and Mac home screen: RUNNER companion per mode, four mode buttons, today's mode timeline.
- Mac menu bar panel with the current mode and mode buttons.
- RUNNER drawn as 36 named vector parts instead of PNGs: per-mode idle loops (work nod and LED
  breathing, chill Monster sip, boxing guard bounce, money chain shine), a reaction on tap, and a
  tired look below 30 energy. `CompanionPortrait` gives a still version for widgets.
- Mode log data contract (`ModeChange`, `ModeLog`, `WidgetSnapshot`) stored as local JSON.
- DEV / STG / PROD build configurations with separate bundle ids.
- CI quality gates (PR title and branch, swift-format, lint, tests, coverage, warnings as errors) and
  TestFlight release workflow for STG and PROD.
