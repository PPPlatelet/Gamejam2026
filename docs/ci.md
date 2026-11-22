# Godot CI

负责人：PPPlatelet；审核人按团队规范为 Gaoj22。固定使用 Godot 4.7.2 stable，Python 3.11 或更高版本。

向 dev/master 提 PR，以及这两条分支更新时，GitHub Actions 运行 `Godot validation`。CI 配置分支 `codex/godot-ci` 也运行，方便合入前验证。

检查内容：

1. checkout 下载 Git LFS；逐个核对资源的 SHA-256 和长度，拒绝残留指针或损坏文件。
2. 拒绝已跟踪的 `.godot/`、`build/`、exe/pck 导出产物。
3. 从官方发行页下载固定版 Godot，并对照该发行页 SHA-512 清单校验。
4. 全新 headless 导入；即便进程退出码为 0，只要日志出现 Godot ERROR/SCRIPT ERROR/Parse Error 也失败。
5. 主场景与存在的菜单、游戏、结束场景分别启动 10 帧，单步超时则失败。starter 尚无主场景时明确记录跳过；游戏工程导入后自动启用。
6. 成功或失败均保留日志 7 天。下载失败发生在验证前时可能没有日志附件，查看 Actions 步骤日志。

本机复现（先 `git lfs pull`）：

```powershell
python tools/ci/validate.py --godot 'D:/AkkoAkko/godot/Godot_v4.7.2-stable_win64.exe'
```

这是资源、解析和场景启动检查，不代表完整试玩、交互正确、导出发行版可用。PR #3 的 `tools/test_logic.gd` 仍引用旧接口，尚不纳入必过检查；后续修复并验证稳定后接入。Windows 导出与打包内容检查也留待下一步。

初次上线先观察真实运行；配置 PR 仍须非作者审核。确认游戏工程上的 CI 稳定后，再把 `Godot validation` 设为 dev/master 必需检查，保留现有人工审核要求。
