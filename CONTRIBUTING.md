# 东果酱2026 开发规范

## 仓库与角色

GitHub PPPlatelet/Gamejam2026 为唯一日常协作仓库（origin）；AtomGit 为阶段参赛同步仓库（atomgit），不在两边分别开发。

- PPPlatelet：主程序、集成负责人，审核成员 PR，执行最终合并与发布。
- Gaoj22：副程序，审核 PPPlatelet 的 PR。
- 所有人都走 PR，由非作者审核；不使用管理员权限绕过正常审核。
- 平台要求至少一个非作者批准；上述指定审核人、合并人及“只推自己的任务分支”是团队约定。

## 分支与合并

| 分支 | 用途 | 合入方式 |
| --- | --- | --- |
| dev（默认） | 日常集成，保持项目可导入、已有主流程可运行 | 任务分支通过 PR，Squash and merge |
| master | 阶段验收通过的可交付版本 | dev 提 PR，Create a merge commit |
| feature/成员/任务 | 单项功能 | 从最新 dev 创建，合入后手动删除 |
| fix/成员/问题 | 单项修复 | 从最新 dev 创建，合入后手动删除 |
| chore/成员/任务、docs/成员/任务 | 配置和文档 | 与功能分支相同 |

Codex 代办任务使用 codex/任务名，并在 PR 中写明负责人；审核要求相同。

dev/master 禁止直接推送、强推、删除；要求至少一个非作者批准、解决全部讨论，新提交撤销旧批准。正式启用情况以仓库设置为准。

不长期复用个人分支，不在别人的任务分支推送。一次 PR 处理一个可独立审核的任务。任务 PR 不夹带无关格式化、资源重导入或编辑器升级。

## 首次加入

安装 Git、Git LFS 和全队约定的同一 Godot 版本，接受 GitHub 邀请后：

```powershell
git lfs install
git clone https://github.com/PPPlatelet/Gamejam2026.git
cd Gamejam2026
git switch dev
git lfs pull
```

为自己的 Git 身份配置姓名和邮箱；通过自己的 GitHub 账号认证，不使用其他人的凭证。用 Godot 导入 project.godot。当前工程声明 Godot 4.7 / GL Compatibility；全队正式开始功能开发前确认同一具体 patch 版本，不自行升级引擎或更换渲染器。

## 每次任务

以下命令在工作区干净时执行，先保存或提交手头修改，不用 reset --hard 或覆盖文件清掉别人的工作。示例分支名按自己的任务替换。

```powershell
git switch dev
git pull --ff-only origin dev
git switch -c feature/Gaoj22/player-move

# 完成改动后，先检查差异并按实际路径暂存
git status
git diff
# git add <本次任务文件>
git diff --cached
git commit -m "feat: 添加玩家移动"
git push -u origin feature/Gaoj22/player-move
```

开发期间每天及提 PR 前更新远程，在自己的任务分支合入 origin/dev：

```powershell
git fetch origin
git merge origin/dev
git lfs pull
```

冲突由任务负责人处理，并和相关文件负责人确认；不要直接选“全部保留我的/对方的”覆盖整份场景。处理后重新导入、验证、提交并推送。不强推共享分支。

在 GitHub 创建 base=dev 的 PR，选择相应审核人。审阅后有新提交要重新获得批准；通过后由 PPPlatelet 使用 Squash and merge 合入。下一任务从更新后的 dev 重新建分支，不续用已经 squash 的旧任务分支。

## Godot 文件与资源

- 提交 project.godot、脚本、场景、资源、源素材及关联的 .uid 和源素材旁 .import 配置。
- 不提交 .godot/ 缓存、本机编辑器状态、导出产物、凭据或含密钥的导出配置。暂未配置的导出目录在首次使用时添加明确忽略规则。
- 保持 .gitattributes 约定的 LF 与 LFS；上传素材前检查 git lfs status，确认没有只拿到 LFS 指针的缺失资源。变更 LFS 跟踪规则需单独讨论。
- 修改 project.godot 的输入映射、Autoload、主场景、渲染设置前先协调；共享主场景和同一 .tscn 同时仅安排一个编辑负责人，优先通过子场景集成。
- 移动/重命名资源时同步提交引用与 UID，使用 Godot 编辑器完成后检查差异。
- GDScript 使用一致缩进；文件/变量/函数用 snake_case，类名用 PascalCase，常量用 UPPER_SNAKE_CASE；遵循所在模块已有风格，避免混合缩进。
- 第三方素材记录来源、作者、许可证、署名要求和用途；不得将第三方素材自动视为 MIT。记录 AI 工具、用途、生成范围和人工修改，供比赛声明使用。

## PR 验收

- 说明具体问题、改动与验证步骤，相关画面变化附截图或短视频。
- 本机完整导入工程，无本次引入的资源缺失、脚本解析错误；相关功能经过实际操作。文档修改可以注明运行验证不适用。
- 记录未验证项目和已知问题，不把静态检查写成试玩通过。
- 涉及共享配置和素材时核对相关负责人、引用完整性与许可记录。
- 首版以人工检查为准，不要求尚未建立的 CI 状态；自动检查实际落地并稳定通过后再设必需项。

## 阶段发布

1. PPPlatelet 从 dev 向 master 提阶段 PR，列出交付内容、已知问题和验收结果，由 Gaoj22 审核。
2. 使用同一 Godot 版本完成 Windows 构建，在构建产物中试玩已有主流程；核对素材/AI 声明等提交材料。
3. 审核通过后使用 Create a merge commit 合入，保持 dev 和 master 的共同历史；不得 squash 此发布 PR。
4. 为 master 发布提交创建明确的版本 tag。发布后继续从 dev 开发；修复也先走任务分支 → dev，再通过发布 PR 进入 master，避免两条长期分支分别修复。
5. 将 master 和对应 tag 同步到 AtomGit，确认相关 LFS 资源已推送，并记录两个远程提交标识。不得使用 --mirror 覆盖其他远程引用。
6. dev/master 始终保留，只清理完成的任务分支。
