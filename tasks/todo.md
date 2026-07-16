# 发布 SharkSpace 1.13.0

## 状态
- 进行中（2026-07-16，本地发布准备完成，等待远端确认与 npm 登录）

## 目标
- [x] 将 npm package 与 Xcode marketing version 从 `1.12.1` 更新到 `1.13.0`，build number 从 `14` 递增到 `15`，同步 lockfile 与 changelog。
- [x] 修正 DMG 产物命名，使本地构建、GitHub Release、README 和 npm 安装器统一使用 `SharkSpace-1.13.0.dmg`。
- [x] 复用并完善 `scripts/build-tool.ts`，生成带时间戳目录的 DMG 与 SHA256，失败不静默、临时目录可清理，并支持 `NO_SIGN=1` fallback。
- [x] 构建 Release App 和 DMG，完成 `hdiutil verify`、版本/build number、codesign 与 checksum 检查，然后打开 DMG。
- [x] 完成 npm pack/publish dry-run 和远端版本检查，提交 release 准备改动。
- [ ] 在远端动作清单得到确认后创建 `v1.13.0`、推送 `main`/tag、创建 GitHub Release、发布 `@ssbun/sharkspace@1.13.0` 并验证。

## 已确认事实
- 发布前 Git/Xcode/npm 版本为 `1.12.1`、Xcode build number 为 `14`；本地 release 准备已更新为 `1.13.0` / build `15`。
- release 准备已提交，本地 `main` 比 `origin/main` 领先 1 个提交；npm registry latest 为 `1.12.1`，`1.13.0` 尚未发布。
- npm 登录态失效；正式 publish 前必须恢复登录。
- GitHub 当前没有 `v1.12.1` Release；`v1.13.0` tag/release 尚不存在。
- 现有 `scripts/build-tool.ts` 是项目 DMG 构建入口；不新增重复 `create-dmg.sh`。

## 边界
- 不安装到 `/Applications`；只打开验证后的 DMG。
- 不增加 notarization、Sparkle appcast 或新的发布依赖。
- 远端 tag、push、GitHub Release 和 npm publish 必须在发布清单确认后执行。

## 验证标准
- Release App 的 `CFBundleShortVersionString` 为 `1.13.0`、`CFBundleVersion` 为 `15`。
- DMG 文件名和 GitHub Release 下载 URL 与 `install.js` 一致，`hdiutil verify` 和 SHA256 校验通过。
- npm tarball 只含 README、install.js、package.json，dry-run 版本为 `1.13.0`。
- 最终 `main`、`v1.13.0`、GitHub Release asset 和 npm latest 指向同一版本。

## 本地验证
- `npx tsx scripts/build-tool.ts create-dmg 1.13.0` 通过；产物为 `dist/SharkSpace-1.13.0_20260716T024627Z/SharkSpace-1.13.0.dmg`，SHA256 为 `4815003febd8ffd1617f411fd0e3619596c59866af1d85f471e90819d47df1b2`。
- Release App 的 marketing version 为 `1.13.0`、build number 为 `15`；`hdiutil verify`、checksum 和 `codesign --verify --deep --strict` 通过，DMG 已打开。
- App 使用 `Apple Development: caishilin@zhihu.com (X27C8L3NVA)` 签名；不是 Developer ID，未 notarized。
- `npm pack --dry-run --json` 与 `npm publish --dry-run --access public --json` 通过，tarball 仅含 README、install.js、package.json；registry 中 `1.13.0` 尚不存在。
- Git Overview、Codex preview/refresh/sessions UI、SwiftUI structure、virtual workspace、terminal opener 全部通过；workflow YAML、无效版本拒绝和 `git diff --check` 通过。

## Review
- GitHub workflow 改为直接调用现有 build-tool，消除 CI 查找错误 App 名和生成 `Shark-*.dmg` 的分叉逻辑。
- build-tool 只验证 package version，不再在 publish 命令中单独改 package.json，避免 package-lock、Xcode 与 changelog 漂移。
- npm 登录当前返回 E401；正式 npm publish 必须在用户恢复登录后执行。

# 缓存 workspace folder 的 Git 状态

## 状态
- 已完成（2026-07-15）

## 目标
- [x] 按 repository 路径缓存本次 App 会话已加载的 Git 状态，切回 workspace 时立即复用，不再逐个重扫。
- [x] 同一路径使用不同 Folder ID 时仍命中缓存；只扫描未缓存的 repository。
- [x] Git 面板关闭后的本地刷新和 `Fetch & Refresh` 忽略缓存，确保显式刷新不会返回旧状态。
- [x] 不缓存 unavailable 结果，避免权限或临时错误被长期保留。

## 边界
- 缓存只存在于 `WorkspaceGitStatusStore` 生命周期内，不增加磁盘格式、过期策略或新依赖。
- 不改变 Git 状态字段、展示或远端 freshness 语义。

## 验证标准
- 首次加载路径 A 扫描一次；切换到 B 再返回 A 时，A 不产生第二次 Git status 请求且新 Folder ID 能读取缓存。
- 强制本地刷新和 fetch refresh 都会重新扫描 A；unavailable 的 A 下次加载会重试。
- Git Overview 专项检查、Swift parse、diff check 和 Debug 构建通过。

## 验证
- 新增专项运行检查：A → B → A 后 A 的 status 请求仍为 1 次，且第二个 A 的 Folder ID 立即读取 `scan-1`。
- 本地 `refresh` 将 A 更新为 `scan-2`；`fetchAndRefresh` 更新为 `scan-3` 且 freshness 为 Fetched。
- unavailable repository 两次进入产生 2 次请求，确认失败结果未缓存。
- `bash scripts/verify-git-overview.sh`、`bash scripts/verify-swiftui-structure.sh`、Swift parse、`git diff --check` 和 Debug `xcodebuild` 全部通过。

## Review
- 根因修复在 `WorkspaceGitStatusStore`：以前 repository 路径集合改变就清空状态并全量扫描；现在先按路径映射会话缓存，只加载缺失项。
- 默认 workspace 加载复用缓存；Git 面板关闭和 Overview 的 `Fetch & Refresh` 继续强制刷新，没有改变现有显式操作语义。
- 缓存随 store 生命周期释放，不增加持久化、TTL、后台定时器或依赖。

# 将 Folder Git 状态移到 cell 右侧

## 状态
- 已完成（2026-07-15）

## 目标
- [x] Version、Working Tree 和 Upstream 状态在 cell 右侧单行展示，不再占用标题下方的第三行。
- [x] 保留左侧标题、branch badge 和路径的现有信息层级。
- [x] 状态位于删除按钮左侧；窄窗口、长 tag、Detached HEAD 和 No Upstream 时仍保持稳定布局。

## 边界
- 只调整 `FolderRow` 布局，不改变 Git 状态采集、语义或刷新行为。
- 不新增视图抽象或配置项。

## 验证标准
- Git 状态组位于最外层横向布局的右侧，而不是左侧内容 `VStack` 内。
- 状态保持单行，删除按钮仍可见并可点击。
- 专项回归、Swift parse、diff check 和 Debug 构建通过。

## 验证
- `FolderRow` 结构检查确认 Git 状态组已移到外层 `HStack` 的 `Spacer(minLength: 12)` 之后、删除按钮之前；左侧 `VStack` 只保留标题和路径。
- 三个 `GitStatusValueView` 本身保持 `lineLimit(1)`，状态组使用布局优先级；长 tag、Detached HEAD、No Upstream 和窄窗口下不会换回标题下方。
- `xcrun swiftc -parse Shark/Views/FolderListView.swift`、`bash scripts/verify-git-overview.sh`、`git diff --check` 和 Debug `xcodebuild` 全部通过。
- Debug App 启动成功；新实例被 macOS Documents 授权弹窗挡住，未在不修改用户系统权限的前提下完成真实 folder 数据截图。

## Review
- 改动只移动既有状态视图，没有改变状态数据、文案、颜色、刷新或点击行为。
- 删除按钮仍是最右侧交互控件；状态位于其左侧且不接收点击，标题、branch badge 与路径保持原布局。
- 未新增视图抽象、状态或配置；这是满足反馈所需的最小布局改动。

# 将 Codex Session 刷新降到亚秒级并分阶段显示

## 状态
- 已完成（2026-07-15）

## 目标
- [x] 将逐 PID 串行 `lsof` 改为一次批量查询，并保留 PID → session 映射和进程退出 race 下的有效 stdout。
- [x] 复用 SQLite `threads` 作为主索引，只读取数据库未覆盖的 JSONL 首行，并保留数据库不可用 fallback。
- [x] 先发布 session metadata，再异步补充运行状态，让列表尽快出现。
- [x] 留下可运行的行为/性能回归检查，并完成现有回归和 Debug 构建。

## 验证标准
- 批量与旧串行路径识别出的运行 session 集合一致。
- SQLite-first 与旧全量 JSONL 路径得到相同 session ID 和排序；stale DB path 不进入结果。
- workspace 切换时旧列表仍立即清空，旧 metadata 或 runtime 结果都不能覆盖当前 workspace。
- 当前 2,500+ session 数据上 metadata 首次发布低于 `0.25s`，完整刷新低于 `0.75s`。

## 验证
- 修复前真实路径红灯：metadata 加 runtime 耗时 `3.689s`，超过 `0.25s` 目标。
- 最终 `bash scripts/verify-codex-session-refresh.sh` 通过：231 个匹配 session，metadata `0.156s`，runtime `0.322s`，合计约 `0.478s`。
- batch lsof fixture 同时传入有效 PID 与不存在 PID，确认非零退出时仍保留有效 session 映射。
- SQLite fixture 覆盖有效 DB record、JSONL-only fallback、无效 JSONL 首行和 stale DB path。
- `bash scripts/verify-codex-sessions-ui.sh`、preview、SwiftUI structure、virtual workspace、terminal opener 全部通过。
- `swiftc -parse`、`git diff --check` 和 Debug `xcodebuild` 全部通过。

## Review
- 运行态检测保留现有 `ps` 过滤语义，仅将候选 PID 合并到一次 `lsof`；按 `p`/`n` 字段恢复映射。
- metadata 扫描按 rollout path 复用 SQLite thread record；路径未覆盖时才读取 JSONL，数据库不可用会自然退回全量 JSONL。
- `WorkspaceStore` 先提交 inactive metadata，再提交 runtime-enriched sessions；load ID 同时阻止 workspace 切换和同 workspace 重刷的旧结果覆盖。
- workspace 变更或选择清空时同步重置列表与 loading，避免失效任务留下永久 spinner。
- 没有增加依赖、缓存或额外 SwiftUI 状态；现有列表在 metadata 到达后会直接显示，并继续用刷新按钮 spinner 表示 runtime 尚在加载。

# Workspace Git Overview

## 状态
- 已完成（2026-07-15）

## 目标
- [x] 从现有 workspace、folder 和 Codex session 主路径中找出仍未解决的高频摩擦。
- [x] 排除已有能力、低频装饰功能和需要服务端的新系统。
- [x] 提出 2–3 个可独立交付的方向，说明用户收益、最小版本与关键边界。
- [x] 与用户收敛下一项最值得设计或实现的功能。

## 边界
- 本轮只做产品构想与取舍，不实现产品代码，不创建设计文档。
- 优先复用现有 session preview、workspace metadata 和 macOS 原生交互。
- 必须考虑全局历史规模、文件失效、重复匹配和异步切换等边界，不能用新增功能放大当前刷新性能问题。

## 已选择方向：Workspace Git Overview
- 用户确认 Workspace Git Overview 有价值，下一步收敛其使用目标与交互范围。
- 面板的核心任务已明确：对 workspace 中的每个 Git repository 回答“最新版本是什么”“是否有未提交改动”“本地提交是否已推送到远端”。
- “未提交改动”必须区分 staged、unstaged、untracked；submodule 状态是否纳入需要在设计中明确。
- “已推送”必须区分 synced、ahead、behind、diverged、无 upstream、detached HEAD、远端不可达或认证失败；未知不能显示为已推送。
- “最新版本”仍需明确是最新 Git tag/release，还是项目文件声明的 package/app version；跨技术栈自动读取版本文件会显著扩大范围。
- 远端结论必须标明新鲜度：仅比较本地 remote-tracking ref 可能过期，实时 fetch/查询则会引入网络、认证和等待成本。
- 当前 folder row 只展示 branch/tag；完整 clean、modified、staged、untracked、conflict、ahead/behind 状态仅存在于单仓库 Git 面板。
- 最小版本应只读并按需刷新；不在 overview 中批量执行 pull、push、commit、stash 等写操作。
- 必须区分非 Git folder、目录缺失或无权限、detached HEAD、无 upstream 和 Git 命令失败，不能把未知状态显示成 clean。
- 扫描必须支持 workspace 切换取消与稳定 ID 校验，避免旧 workspace 结果覆盖当前界面；多仓库查询需要限制并发，避免同时启动过多进程。

## 已确认设计
- `latest version` 指 Git tag；使用 Git version sort 选择最新已知 tag，没有 tag 时明确显示 `No Tag`。
- Folder cell 直接显示 version、working tree 和 upstream 三项摘要；Overview 使用原生 macOS 表格展示同一份状态。
- 初次进入 workspace 只读取本地状态和现有 remote-tracking refs，不自动联网；Overview 提供 `Fetch & Refresh`，成功 fetch 后再更新 tag 和 upstream 状态。
- 保留现有单仓库 Git Operations，避免移除 pull、push、commit、stash 和 branch 能力。
- submodule 不递归扫描；它在父仓库 `git status` 中产生的改动按普通 working-tree change 计数。

## 实施计划
- [x] 将 repository status 扫描收敛到 `git status --porcelain=v2 --branch` 与 tag 查询，解析 staged、unstaged、untracked、conflict 和 upstream 状态。
- [x] 添加 workspace 级共享 Git status store，串行扫描 repository，并用 refresh ID/取消检查阻止旧 workspace 结果覆盖新界面。
- [x] 在 Folder cells 展示 tag、working tree 和 upstream 的关键状态。
- [x] 在 Folders header 添加 Workspace Git Overview 入口，使用原生表格和 `Fetch & Refresh`。
- [x] 添加可运行解析/集成检查，覆盖 clean、dirty、ahead、behind、diverged、无 upstream、detached HEAD、无 tag 和命令失败。
- [x] 运行专项检查、现有回归、Swift parse、diff check 和 Debug 构建。

## 验证标准
- 每个 Git folder cell 能回答最新 tag、是否有未提交改动、当前分支提交是否已推送。
- Overview 与 cells 使用同一状态源；打开 Overview 不重复扫描已加载状态。
- 非 Git、缺失、无权限、无 upstream、detached HEAD 和 fetch 失败不会显示为 clean/synced。
- workspace 快速切换或 folders 变化时，旧扫描结果不会写入当前列表。

## 验证
- `bash scripts/verify-git-overview.sh` 通过；fixture 覆盖 clean/synced、dirty/ahead、behind、diverged、无 upstream、detached HEAD、无 tag 和 unavailable。
- `bash scripts/verify-codex-session-refresh.sh`、preview、sessions UI、SwiftUI structure、virtual workspace 和 terminal opener 全部通过。
- 相关 Swift 文件 `swiftc -parse` 与 `git diff --check` 通过。
- Debug `xcodebuild` 通过；仅保留既有 Settings 和 ComponentSearchFilter warning。
- 启动 Debug App 进行视觉冒烟：Folder cells 正确显示 tag、Clean/changes 和 Synced/unpushed/behind 等摘要，窄列表下可读。

## Review
- `GitManager` 从每仓库 4 次查询收敛为 porcelain-v2 status 加 version-sorted tag 查询；Git 子进程离开 MainActor，避免批量扫描阻塞 UI。
- Folder cells 与原生 `Table` Overview 读取同一个 `WorkspaceGitStatusStore`；串行扫描避免进程风暴，request ID 和任务取消阻止旧结果串台。
- 初次扫描不会联网，upstream 显示基于现有 tracking refs；显式 `Fetch & Refresh` 后标记为 Fetched，认证或网络失败显示 Fetch Failed。
- 无 upstream、detached HEAD、diverged、缺失 tag 和不可用状态都有独立语义，不会误报为 Synced 或 Clean。
- 保留现有单仓库 Git Operations；本次没有加入批量 push/pull/commit 等高风险写操作。

# 研究并量化 Codex Session 刷新优化

## 状态
- 已完成（2026-07-15）

## 目标
- [x] 解释当前 `lsof` 检查的输入、输出与用途。
- [x] 用真实数据复测基线，并验证批量 `lsof`、SQLite 直读和 hooks 快速路径的耗时。
- [x] 基于第一方资料给出按收益/风险排序的最小优化方案。
- [x] 将研究结论写入 `docs/research/`，不修改产品代码。

## 验证标准
- 优化建议有当前机器实测数据与第一方资料共同支撑。
- 区分“降低实际总耗时”和“仅改善首屏感知时间”。
- 明确正确性风险、回退路径与不值得现在做的复杂方案。

## 验证
- 现路径稳态约 `2.6–2.7s`；19 次 Swift `Process` 串行 `lsof` 为 `1.84–1.88s`。
- 单次批量 `lsof -Fn -p pid1,...` 为 `0.124–0.126s`，返回的 10 个 session 文件与串行调用完全一致。
- SQLite threads 查询、解码和文件存在检查为 `0.081–0.084s`；排除 4 个缺失 rollout 文件后，228 个 session ID 与现路径完全一致。
- hooks 的 13 个 active snapshots 中仅 2 个 PID 仍存活，已证伪 hooks-only。
- 官方 lsof 文档确认 `-p` 支持逗号分隔 PID 集合，`-F` 的 `p`/`n` 字段足以恢复 PID → 文件映射。
- `git diff --check` 通过；临时 benchmark 与 instrumentation 已删除。

## Review
- 第一优先级是单次批量 `lsof`，预计完整刷新降到约 `0.9s`，不改变现有进程筛选语义。
- 第二优先级是 SQLite-first + JSONL delta fallback，预计与批量 `lsof` 组合后约 `0.35–0.45s`。
- 批量 lsof 必须解析非零退出时的非空 stdout，避免单个 PID 退出导致整批结果丢失。
- 不采用并行多进程、hooks-only、`lsof -O`、常驻 lsof、libproc 或新缓存；当前收益不足以承担复杂度与正确性风险。
- 完整报告：`docs/research/codex-session-refresh-performance.md`。

# 诊断 Codex Session 列表刷新缓慢

## 状态
- 已完成（2026-07-15）

## 目标
- [x] 建立能测量实际 session 扫描路径的秒级反馈循环。
- [x] 分解扫描、metadata 和运行态检测成本，确认主耗时来源。
- [x] 只报告证据与最小优化方向，不修改产品代码。

## 验证标准
- 给出可复现的计时数据，而不是只根据代码形状猜测。
- 明确 workspace session 数量或全局历史规模如何影响刷新时间。

## 验证
- 使用真实 `CodexSessionManager.sessions` 路径连续运行三次：`2.75s`、`2.59s`、`2.60s`。
- 当前 `~/.codex` 有 2,538 个 JSONL；以用户 home directory 作为匹配根路径时得到 227 个 session。
- 稳态分项：19 次串行 `lsof` 约 `1.83s`，JSONL metadata 读取与筛选约 `0.52s`，`ps` 约 `0.15s`，SQLite thread index 约 `0.09s`。

## Review
- 主因是运行态检测对每个命令含 `codex` 的终端进程串行启动一次 `lsof`，约占总时长 70%。
- 次因是每次刷新先枚举全局历史并读取所有 JSONL 首行，再筛选当前 workspace；成本随全局历史数量增长，而非只随当前列表增长。
- 临时计时 instrumentation 和 benchmark 已清理，产品代码没有因诊断发生改动。

# Workspace 切换时立即清空 Codex Sessions

## 状态
- 已完成（2026-07-15）

## 假设
- 慢扫描期间显示旧列表，是因为切换入口没有先清空 `codexSessions`。
- 快速连续切换时，旧 workspace 的异步扫描还可能晚于新扫描返回并覆盖当前列表。
- 修复应留在 `WorkspaceStore` 的共享加载路径，不在 SwiftUI cell 或单个调用方补状态。

## 计划
- [x] 添加可检测“切换时未清空”和“旧结果覆盖”的回归检查，并确认当前失败。
- [x] 在 workspace 加载开始时立即清空 session 列表。
- [x] 在异步扫描提交结果前验证 workspace 仍然匹配。
- [x] 更新 lessons，并运行专项检查、现有回归、diff check 和 Debug 构建。

## 验证标准
- 选择另一个 workspace 后，旧 session rows 立即消失。
- 旧 workspace 的慢扫描完成后不能覆盖当前 workspace 的 sessions。
- 手动刷新当前 workspace 时仍保留现有加载行为。

## 验证
- 修复前，新增专项检查按预期失败：`WorkspaceStore must clear stale Codex sessions as soon as workspace selection changes`。
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-codex-session-preview.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `bash scripts/verify-virtual-workspace.sh` 通过。
- `bash scripts/verify-terminal-opener.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- `selectedWorkspace` 的稳定 ID 发生变化时同步清空 `codexSessions`；同一 workspace 刷新或重命名不会触发列表闪烁。
- 文件授权返回和后台 session 扫描完成后都会核对当前 workspace ID，旧请求不能再写入新 workspace 的界面。
- 修复只修改共享状态入口和结果提交点，没有给 SwiftUI 视图增加重复状态或新抽象。
- 当前存储依赖具体单例，缺少低成本可注入的运行时单测 seam；本次用先红后绿的专项结构回归覆盖关键约束，并以现有回归和完整 Debug 构建补充验证。

# 实现 Codex Session Preview

## 状态
- 已完成（2026-07-15）

## 假设
- 双击 session cell 打开单个可复用、非模态、可缩放的 SwiftUI window。
- 预览只解析 JSONL `event_msg.user_message` 与 `event_msg.agent_message`。
- 首条用户消息单独展示；Recent Messages 保留其后的最后 8 条消息。
- 不改变现有单击、Command 多选、resume、jump、archive 和 delete 行为。

## 计划
- [x] 添加预览模型与可取消的逐行 JSONL 加载器。
- [x] 添加最小可运行解析检查，覆盖过滤、截断、损坏行和重复记录。
- [x] 添加预览状态与原生 SwiftUI 独立窗口。
- [x] 将 session cell 双击接入预览窗口，并复用现有终端动作。
- [x] 运行解析检查、现有回归脚本、diff check 和 Debug 构建。

## 验证标准
- 双击打开/更新同一个预览窗口；单击和多选不受影响。
- 预览展示 metadata、Initial Prompt 和最近 8 条消息。
- reasoning、tool、system/developer、`response_item` 和损坏行不会进入预览。
- 文件读取失败时展示错误状态，不崩溃、不自动 resume。

## 验证
- `bash scripts/verify-codex-session-preview.sh` 通过。
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `bash scripts/verify-virtual-workspace.sh` 通过。
- `bash scripts/verify-terminal-opener.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。
- Debug 可执行文件启动后保持运行且未崩溃；启动日志仅包含既有 componentsSearchPath bookmark 格式警告。

## Review
- 使用单个 SwiftUI `Window` 复用预览窗口；AppDelegate 不再把它误识别为主窗口。
- 双击通过 `simultaneousGesture` 接入内容区域，保留 `List(selection:)`，且不会覆盖右侧 Jump 按钮。
- JSONL 使用可取消的逐行读取，只解码 user/assistant 可见事件；解析状态和文件错误在窗口内明确展示。
- 预览操作复用现有 `TerminalOpener`，没有增加终端实现或新依赖。
- Computer Use 原生管道不可用，因此未完成自动化视觉点击检查；已由静态交互回归、启动冒烟和完整构建覆盖可自动验证部分。

# Shark 下一步实用功能构想

## 状态
- 已完成（2026-07-15）

## 目标
- [x] 核实现有功能与近期演进方向，排除重复或偏离定位的想法。
- [x] 明确下一阶段最重要的用户价值目标：减少日常重复操作。
- [x] 提出 2–3 组可选方向，说明收益、成本与取舍。
- [x] 与用户收敛出优先级最高的候选方案。

## 边界
- 本轮只做产品构想与取舍，不实现代码，不写设计文档。
- 优先复用 macOS、文件系统和现有工作区模型能力，避免引入服务端或账号系统。

## 已确认现状
- Shark 的主线已从 IDE 专属 workspace 转为 agent/IDE 无关的 virtual folder。
- 当前差异化能力集中在 Codex session 浏览、恢复、运行态识别和 iTerm2 跳转。
- Workspace health 已覆盖 metadata、folder、symlink 和 Codex hooks 的检查与部分修复。
- 日常主路径可分为三类：组装 workspace、查找/切换 workspace、恢复/跳转 Codex session。
- 用户选择优先优化 Codex 工作上下文恢复。

## 候选方向
- Smart Continue：为 workspace 提供统一继续入口，运行中则跳转，已停止则 resume 最近 session。
- Recent Activity：按最近 session 活动重排或展示 workspace，先找到最近在做什么，再继续。
- Session Favorites：允许固定少量关键 session，适合长期并行任务，但需要用户主动维护。

## 用户反馈后的方向调整
- 用户认为 Smart Continue 不能解决“确认目标 session”的问题，因此不采用。
- 新目标：点击 Codex session cell 后打开预览窗口，通过会话内容确认是否为目标 session。
- JSONL 已确认包含 `response_item` 下的 user/assistant message；预览可忽略 reasoning、工具调用、system/developer 消息和重复事件记录。
- 预览内容确定为首条用户消息 + 最近 8 条 user/assistant 消息。
- 交互确定为双击 session cell 打开预览，保留单击与 Command 多选。
- 预览采用单个可复用的非模态窗口，包含 metadata、Initial Prompt、Recent Messages，以及 resume/jump 和次要操作。
- 解析确定为后台逐行读取 JSONL，仅接受 `event_msg.user_message` 和 `event_msg.agent_message`，保留首条用户消息与最后 8 条非重复消息。

## Review
- 最终方案是 Codex session preview，而不是 Smart Continue。
- 双击 session cell 打开单个可复用的非模态预览窗口；单击和 Command 多选保持不变。
- 预览显示 session metadata、首条用户消息和最近 8 条 user/assistant 消息，并提供 resume/jump 等已有动作。
- 已定义流式解析、重复消息过滤、损坏行容错、加载取消和最小验证范围。
- 本轮只完成设计确认，未实现功能，也未写入 `docs/plans/`。

# Virtual Folder Workspace 重构

## 假设
- 目标：移除 Cursor workspace 类型，只保留单一 virtual folder workspace 模型。
- virtual folder 是真实目录，目录内包含项目/组件目录的符号链接和元数据文件。
- 这个模型应保持 agent/IDE 无关，因为普通工具只需要打开这个目录即可。
- 不迁移旧 `.code-workspace` 文件；旧类型从模型、UI、扫描、打开逻辑中移除。

## 计划
- [x] 梳理 Cursor/Claude workspace 类型影响面。
- [x] 明确旧 `.code-workspace` 行为：不再扫描、创建、导入或打开。
- [x] 提出并确认设计：使用单一 virtual folder 模型。
- [x] 写入设计规格文档。
- [x] 写入实施计划和验证步骤。
- [x] 添加最小回归检查脚本。
- [x] 删除 Cursor workspace 类型和 `.code-workspace` 相关逻辑。
- [x] 将 Claude-specific workspace 文件泛化为 `VirtualWorkspaceFile`。
- [x] 更新 UI：移除类型选择、导入、类型分组、duplicate conversion 和 IDE 默认设置。
- [x] 更新 README / CHANGELOG 的相关行为说明。
- [x] 运行静态清理脚本。
- [x] 运行 macOS Debug 构建。

## 执行记录
- 新增 `VirtualWorkspaceFile`，元数据文件为 `.shark-workspace.json`。
- `Workspace` 不再持有 `WorkspaceType`，`filePath` 统一表示虚拟工作区目录。
- `WorkspaceManager` 只扫描包含 `.shark-workspace.json` 的目录，只创建 virtual workspace。
- `MainWorkspaceView` 只读写 virtual workspace 元数据和符号链接。
- `WorkspaceListView` 移除了 workspace 类型入口、导入入口和类型分组。
- `WorkspaceOpener` 改为打开虚拟工作区目录。
- 旧 virtual workspace 的 `.claude-workspace.json` 仍可被扫描和读取；后续保存会写入新的 `.shark-workspace.json`。
- `SettingsView` 移除了默认 IDE 配置。

## 验证
- `bash scripts/verify-virtual-workspace.sh` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- 已完成实现和验证。
- 构建中仍有既有 warning：`SettingsView.swift` 的 `allowedFileTypes` 已废弃、`AlertManager.swift` 有未使用变量；这两个不属于本次 virtual folder 重构范围。

# SwiftUI 结构优化

## 计划
- [x] 提交 virtual folder 重构现有改动。
- [x] 添加最小结构检查脚本。
- [x] 引入 `@MainActor @Observable` 的 `WorkspaceStore`。
- [x] 简化 `MainWorkspaceView`，让它只负责布局和 presentation。
- [x] 让 `WorkspaceListView` 通过 store 执行动作，移除 workspace manager glue。
- [x] 运行结构检查、virtual workspace 检查和 Debug 构建。

## 验证
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `bash scripts/verify-virtual-workspace.sh` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

# Codex Sessions 面板

## release skill 审计

### 假设
- 审计对象是 `/Users/caishilin/Desktop/personal/skills/skills/release/SKILL.md`。
- 重点检查信息泄露、发布安全边界、流程缺陷和不适合现代 npm/native app 发布的设计。

### 计划
- [x] 读取完整 release skill。
- [x] 用行号定位高风险规则。
- [x] 输出按严重度排序的审计结论。

### Review
- release skill 没有直接硬编码 token，但会诱导输出本地文件路径、版本 grep 结果、tag/remote/publish 状态等信息。
- npm/native app 发布规则过粗，需要拆分为更安全的专用 SOP。

## npm 发布 SOP

### 假设
- 需要一个跨项目可复用的用户级 SOP。
- SOP 覆盖 CLI 工具和原生 App 通过 npm 分发两类场景。
- 正式发布到 npm 必须由用户明确确认。

### 计划
- [x] 创建 `~/.sops/npm-publish-tool-or-native-app.md`。
- [x] 写入检查、打包、dry-run、发布和错误处理流程。
- [x] 验证 SOP 文件存在并包含 frontmatter。
- [x] 按用户纠正改为 DMG 远端下载模型，并要求 npm 包名带 scope/prefix。

### Review
- SOP 已作为用户级流程沉淀，后续 agent 可在匹配 npm 发布任务时直接读取执行。
- 原生 App 的标准 npm 模式是包内提供 `install.js`，在 `npm install` 时下载并打开对应版本 DMG。

## Release 1.11.0

### 假设
- 目标版本为 `1.11.0`。
- 需要创建 DMG，并将新版本安装到 `/Applications/SharkSpace.app`。
- 不自动 push，不发布 npm。

### 计划
- [x] 更新 Xcode、npm 和 lockfile 版本号。
- [x] 将 CHANGELOG Unreleased 内容发布为 `1.11.0`。
- [x] 运行验证和 Release DMG 打包。
- [x] 提交 release commit 并创建 `v1.11.0` tag。
- [x] 替换 `/Applications/SharkSpace.app` 并验证安装版本。

### 验证
- `bash scripts/verify-virtual-workspace.sh && bash scripts/verify-codex-sessions-ui.sh && bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。
- `npx tsx scripts/build-tool.ts create-dmg 1.11.0` 通过，生成 `dist/SharkSpace-1.11.0.dmg`。
- DMG SHA-256：`8b40cbe18b96377a82efb1d2e753b6753153cfcf37de263c2320da2ada60e674`。
- `/Applications/SharkSpace.app` 已安装为 `1.11.0 (12)`。

### Review
- 版本号更新为 `1.11.0`，build number 更新为 `12`。
- CHANGELOG 已新增 `1.11.0` 发布条目。
- 新版 DMG 已创建并安装到 Applications。

## npm 发布准备

### 假设
- 参考 `/Users/caishilin/Desktop/work/apps/venom-verge` 的 npm 包模式。
- 当前版本使用已有 `1.11.0` DMG 发布到 npm。
- 正式 `npm publish` 需要用户明确确认，并且需要有效 npm 登录态。

### 计划
- [x] 对比 `venom-verge` 的 `package.json` 和 `install.js`。
- [x] 验证 npm 包内容包含稳定文件名 `SharkSpace.dmg`。
- [x] 清理 npm publish dry-run 中的 package metadata 警告。
- [ ] 等待用户确认后执行正式 `npm publish --access public`。

### 验证
- `npm pack --dry-run` 通过，包内容包含 `README.md`、`SharkSpace.dmg`、`install.js`、`package.json`。
- `npm publish --dry-run --access public` 通过。
- `npm view @ssbun/sharkspace version versions --json` 显示 npm 最新为 `1.9.0`。
- `npm whoami` 返回 401，当前 shell 没有 npm 登录态。

### Review
- SharkSpace 已具备与 `venom-verge` 相同的 npm 安装包结构。
- `package.json` 的 bin path 与 lockfile 对齐为 `install.js`。

## 终端启动 gitconfig lock 修复

### 假设
- 新终端标签页报错来自 zsh 启动链路。
- `~/.gitconfig.lock` 是残留锁文件，不是当前 git 进程正在持有。
- 保持现有 `proxy_on` 行为，只避免每次启动重复写全局 git 配置。

### 计划
- [x] 检查 shell 启动脚本和残留 lock 文件。
- [x] 修改 `~/.aliases`，让 git proxy 配置只在值变化时写入。
- [x] 删除残留 `~/.gitconfig.lock`。
- [x] 启动新的 zsh 验证不再报错。

### Review
- 根因是 `~/.zshrc` 每次启动都会调用 `proxy_on`，而 `proxy_on` 每次都会写 `git config --global`。
- 已保留 `proxy_on` 设置代理的行为，但当前值已正确时不再写 `~/.gitconfig`。
- `TERM=xterm-256color zsh -lic 'echo shell-start-ok'` 通过，没有再出现 gitconfig lock 报错。

## Release 1.12.0 本地提交

### 假设
- “new minor version” 表示从 `1.11.0` 升到 `1.12.0`。
- 本次只做本地版本更新和 commit，不创建 tag、不 push、不 npm publish。
- 用户要求 commit all changes，因此提交包含当前 Shark 仓库内所有未提交改动。

### 计划
- [x] 读取 release skill 和 release-orchestrator SOP。
- [x] 检查工作区状态和当前版本。
- [x] 更新 npm、Xcode 版本号和 CHANGELOG。
- [x] 运行现有验证脚本、diff check 和 macOS Debug 构建。
- [x] 提交所有 Shark 仓库改动。

### Review
- 目标版本为 `1.12.0`，Xcode build number 为 `13`。
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `bash scripts/verify-virtual-workspace.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## 安装 SharkSpace 1.12.0 到 Applications

### 假设
- 目标是把当前仓库版本 `1.12.0 (13)` 安装到 `/Applications/SharkSpace.app`。
- 只替换本机 Applications 里的 app，不创建 tag、不 push、不 npm publish。
- 如果旧版正在运行，先退出再替换。

### 计划
- [x] 构建 Release 版本。
- [x] 替换 `/Applications/SharkSpace.app`。
- [x] 验证 Applications 中安装版本为 `1.12.0 (13)`。

### Review
- `xcodebuild -scheme Shark -configuration Release -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO clean build` 通过。
- `/Applications/SharkSpace.app` 已替换为构建产物。
- Applications 中 `CFBundleShortVersionString` 为 `1.12.0`，`CFBundleVersion` 为 `13`。

## README / CHANGELOG 更新

### 假设
- README 需要反映当前 virtual folder、Codex sessions、workspace health 功能。
- CHANGELOG 的 1.10.0 之后改动放在 Unreleased。
- 文档必须使用中文。

### 计划
- [x] 更新 README，移除旧导入说明并补充新功能。
- [x] 更新 CHANGELOG 的 Unreleased。
- [x] 运行文档相关检查。

### 验证
- `bash scripts/verify-virtual-workspace.sh` 通过。
- `git diff --check` 通过。
- README 已移除旧 import / `.code-workspace` / UserDefaults metadata 描述。

### Review
- README 已更新为当前 virtual folder、Codex sessions、Codex hooks 和 workspace health 功能说明。
- CHANGELOG 的 Unreleased 已记录 session 时间分组、workspace health 和 README 更新。

# iTerm2 工作区打开修复

## 假设
- 截图中的工作区行箭头调用 `WorkspaceOpener.openWorkspace`，最终走 `TerminalOpener.openFolder`。
- 用户已在 Settings > Terminal 选择 iTerm2，但点击箭头仍打开 Terminal。
- 本机 iTerm 应用可通过 bundle id `com.googlecode.iterm2` 找到，但 `open -a iTerm2` 找不到。

## 计划
- [x] 追踪箭头按钮到终端打开调用链。
- [x] 验证 iTerm2 app name 与 bundle id 的实际查找行为。
- [x] 将 iTerm2 打开逻辑改为 bundle id。
- [x] 增加最小验证脚本，避免回退到 app name。
- [x] 运行验证脚本和 Debug 构建。

## Review
- 根因是 `TerminalOpener.openWithITerm2` 使用 `open -a iTerm2`，但本机可解析的应用名是 `iTerm`，导致命令失败后 fallback 到 Terminal。
- 已改为 `open -b com.googlecode.iterm2`，不再依赖应用名。
- `bash scripts/verify-terminal-opener.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

# Release 1.12.1 本地安装

## 假设
- “fix version” 表示从 `1.12.0` 发布 patch 版本 `1.12.1`。
- 只做本地 release：提交、创建本地 tag、构建 DMG、安装到 `/Applications/SharkSpace.app`。
- 不 push，不 npm publish。

## 计划
- [x] 更新 Xcode、npm 和 lockfile 版本号。
- [x] 将 iTerm2 打开修复写入 CHANGELOG。
- [x] 运行验证脚本、diff check 和 Debug 构建。
- [x] 构建 Release DMG。
- [x] 替换 `/Applications/SharkSpace.app` 并验证安装版本。
- [x] 提交所有改动并创建 `v1.12.1` tag。

## Review
- `bash scripts/verify-terminal-opener.sh && bash scripts/verify-codex-sessions-ui.sh && bash scripts/verify-swiftui-structure.sh && bash scripts/verify-virtual-workspace.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。
- `npx tsx scripts/build-tool.ts create-dmg 1.12.1` 通过，生成 `dist/SharkSpace-1.12.1.dmg`。
- DMG SHA-256：`183230216aa9eafd8d921e275aa485dcfc1953052f76cdfc5d7f7744a4062cbd`。
- `/Applications/SharkSpace.app` 已安装为 `1.12.1 (14)`。

## Workspace Health 菜单入口

### 假设
- 入口放在 workspace 右键菜单。
- 本次先实现检查结果 sheet，不做自动修复。
- 菜单项需要带图标，符合现有 context menu 样式。

### 计划
- [x] 在 workspace context menu 增加 `Check Health...` 图标菜单项。
- [x] 增加当前 workspace 的最小 health report。
- [x] 运行 SwiftUI 结构检查和 Debug 构建。

### 验证
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

### Review
- Workspace 右键菜单新增带 `stethoscope` 图标的 `Check Health...`。
- Sheet 显示 workspace directory、metadata、linked folders、symlinks、unexpected symlinks、Codex hooks 状态。
- 暂不做修复动作，先只读检查。

### 后续计划
- [x] 增加 `Recreate Symlinks` 修复动作。
- [x] 增加 `Remove Missing Links` 修复动作，并在写 metadata 前确认。
- [x] 修复后刷新 health report。

### 后续验证
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Codex Session 时间分组

### 假设
- “active date” 使用 session 的 `updatedAt`。
- 只分组 active sessions；archived sessions 保持原来的折叠分组。
- 分组为 8 小时内、2 天内、1 周内、更早。

### 计划
- [x] 在 `CodexSessionListView` 内按 `updatedAt` 分组 active sessions。
- [x] 保持多选、右键菜单和 archived 折叠行为不变。
- [x] 更新 Codex sessions UI 检查并运行验证。

### 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

### Review
- Active Codex sessions 现在按 `updatedAt` 分为 Last 8 Hours、Last 2 Days、Last Week、Older。
- Archived sessions 继续保持原来的折叠分组。

## Codex Session 显示名

### 假设
- 只修改 Shark 内展示名，不写 Codex 私有 sqlite。
- 显示名保存到 workspace 的 `.shark-workspace.json`。
- 空显示名表示回退到 Codex 原始标题。

### 计划
- [x] 在 virtual workspace 元数据中增加 Codex session display name 字段。
- [x] 加载 Codex sessions 时优先使用 workspace 保存的 display name。
- [x] 在 session context menu 增加 Rename Display Name。
- [x] 更新最小验证脚本并运行验证。

### 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

### Review
- Codex session display name 现在保存到 workspace 的 `.shark-workspace.json`。
- 列表标题优先使用 Shark display name，空值回退到 Codex 原始标题。
- 只支持单个 session 改名；批量改名没有明确语义，先不做。

## Codex Session iTerm Split Resume

### 假设
- 目标：多选 Codex sessions 后点击 `Resume in Terminal`，在 iTerm2 中使用同一个 tab 的多个 split panes，而不是多个 tabs。
- iTerm2 支持 AppleScript split session；macOS 自带 Terminal 没有可脚本化 split pane API。
- 非 iTerm2 终端保持现有 `.command` 文件打开行为作为 fallback。

### 计划
- [x] 在 `TerminalOpener` 增加批量命令入口，iTerm2 走单 tab 多 split。
- [x] 将 Codex session resume 改为调用批量入口。
- [x] 更新最小 UI 验证脚本，检查批量 resume 路径。
- [x] 运行 Codex sessions UI 检查、diff check 和 macOS Debug 构建。

### 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `git diff --check` 通过。
- `osacompile` 编译 iTerm2 split AppleScript 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

### Review
- 多选 Codex sessions 现在会通过 `TerminalOpener.runCommands` 批量 resume。
- 默认终端为 iTerm2 时，会创建一个 tab，并为每个 session 写入一个 split pane。
- 非 iTerm2 终端仍回退到现有多 `.command` 文件行为，因为自带 Terminal 没有可脚本化 split pane API。

## Codex Session Split Resume 设置

### 假设
- “pages” 指多选的 Codex sessions。
- Settings 里需要一个开关控制多 session resume 是否使用 iTerm2 split panes。
- Settings 里需要一个 split layout 选择；默认 `Automatic Grid` 按 2/3/4 sessions 使用用户描述的布局。
- 超过 4 个 sessions 时先继续使用简单 split 链，不额外设计复杂网格。

### 计划
- [x] 在 `SettingsManager` 增加 split 开关和 layout 持久化。
- [x] 在 Terminal 设置页增加 Toggle 和 Picker。
- [x] 让 `TerminalOpener.runCommands` 读取设置并按 layout 生成 iTerm2 split AppleScript。
- [x] 更新最小验证脚本并跑构建。

### 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `git diff --check` 通过。
- `osacompile` 编译 iTerm2 3/4 pane split AppleScript 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

### Review
- Settings > Terminal 新增多 session resume split 开关。
- Settings > Terminal 新增 split layout 选择：Automatic Grid、Vertical Splits、Horizontal Splits。
- Automatic Grid 对 2/3/4 sessions 分别使用左右分、左一右二、四象限布局；超过 4 个 sessions 回退为竖向 split 链。

## 假设
- 目标：在选中的 workspace 详情区域中增加 Codex sessions 列表。
- UI 采用已确认的方案 1：右侧区域上下分割，上方 folders，下方 Codex Sessions。
- Codex session 来源为本机 `~/.codex/sessions` 和 `~/.codex/archived_sessions` 的 `.jsonl` 文件。
- session 是否属于当前 workspace：匹配 session metadata 的 `cwd` 是否位于 workspace 目录或当前 workspace folders 路径下。
- 先实现只读列表和基础动作，不实现搜索、筛选、恢复会话等扩展功能。

## 计划
- [x] 检查 Codex session 文件格式和索引文件。
- [x] 添加最小回归检查脚本。
- [x] 新增 `CodexSession` 模型。
- [x] 新增 `CodexSessionManager`，读取 session metadata 和 `session_index.jsonl`。
- [x] 新增 `CodexSessionListView`。
- [x] 在 `WorkspaceStore` 中维护 sessions 状态并随 workspace/folders 刷新。
- [x] 将 `MainWorkspaceView` 右侧改为 `VSplitView`：folders + sessions。
- [x] 提供 Open、Show in Finder、Copy Path 基础动作。
- [x] 运行 Codex sessions UI 检查。
- [x] 运行 SwiftUI 结构检查。
- [x] 运行 macOS Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- 已实现右侧下方面板展示 Codex sessions。
- 当前只读取 session metadata 的第一行和 `session_index.jsonl`，避免全文扫描 session 内容。
- 刻意未加入搜索、过滤、恢复会话能力；等列表数量和使用方式明确后再加。

# Codex Sessions 信息补全

## 假设
- Codex App 的列表标题优先来自最新的 `~/.codex/state_5.sqlite` 或 `~/.codex/sqlite/state_5.sqlite` 的 `threads.title`，为空时回退到 `first_user_message` / `preview`。
- archived 状态优先来自 `threads.archived`，缺失时根据文件是否位于 `archived_sessions` 判断。
- 只补全列表所需信息：标题、archived 状态、source/model；不读取完整对话内容。

## 计划
- [x] 扩展 `CodexSession` 模型保存 archived/source/model。
- [x] 让 `CodexSessionManager` 优先读取 Codex sqlite threads。
- [x] 在 session 行显示 archived 状态和 source/model。
- [x] 更新最小验证脚本。
- [x] 运行验证和 Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- 列表标题现在优先使用最新 Codex App sqlite 的 `threads.title`，空标题时回退到 `first_user_message` / `preview` / `session_index.jsonl` 的 `thread_name`，最后才显示 id。
- archived 状态优先使用 sqlite `threads.archived`，缺失时按 `archived_sessions` 路径判断。
- 未加入全文摘要或恢复会话能力，避免扫描完整 jsonl。

# Codex Sessions Loading 卡住修复

## 假设
- loading 一直显示，是因为 sqlite 子进程 stdout pipe 写满后，`waitUntilExit()` 永远等不到退出。
- `isLoadingCodexSessions` 应使用 `defer` 重置，避免正常失败路径留下 loading 状态。

## 计划
- [x] 调整 sqlite 读取顺序：先读取 stdout 到 EOF，再 `waitUntilExit()`。
- [x] 给 `loadCodexSessions()` 添加 `defer` 重置 loading。
- [x] 运行 Codex sessions 检查、SwiftUI 结构检查和 Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- 根因：sqlite 子进程输出很大，先 `waitUntilExit()` 会让 stdout pipe 写满后互相等待。
- 修复：先 `readDataToEndOfFile()` drain stdout，再 `waitUntilExit()`；loading 状态用 `defer` 清理。

# Codex Sessions Archived 折叠分组

## 假设
- Active sessions 保持直接展示。
- Archived sessions 默认收起到一个可展开分组。
- 不新增搜索、筛选或持久化展开状态。

## 计划
- [x] 在 `CodexSessionListView` 内部分离 active/archived sessions。
- [x] 用默认折叠的 `DisclosureGroup` 展示 archived sessions。
- [x] 更新最小验证脚本。
- [x] 运行验证和 Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- Active sessions 仍直接显示。
- Archived sessions 现在放在默认折叠的 `Archived Sessions (count)` 分组里。
- 未持久化展开状态，避免增加不必要设置。

# Codex Sessions Resume 菜单

## 假设
- 不再显示 session 行右侧跳转图标。
- Resume 使用当前设置的 terminal 执行 `codex resume <session_id>`。
- Context menu 需要新增 `Resume in Terminal` 和 `Copy Session ID`。

## 计划
- [x] 给 `TerminalOpener` 增加最小命令执行入口。
- [x] 在 `WorkspaceStore` 增加 resume 和 copy session id 动作。
- [x] 更新 `CodexSessionListView`：移除右侧跳转按钮，新增 context menu。
- [x] 更新验证脚本。
- [x] 运行验证和 Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- 移除了 session 行右侧跳转按钮。
- Context menu 新增 `Resume in Terminal`，使用当前设置的 terminal 执行 `codex resume <session_id>`。
- Context menu 新增 `Copy Session ID`。

# Codex Sessions 多选操作

## 假设
- 移除 context menu 里的 `Open`。
- 支持多选 session。
- 右键菜单对当前选中项批量执行 `Resume in Terminal`、`Archive`、`Delete`。
- `Delete` 是永久删除，需要确认。

## 计划
- [x] 在 `CodexSessionListView` 增加 `List(selection:)` 多选状态。
- [x] Context menu 使用选中项作为批量目标。
- [x] 在 `WorkspaceStore` 增加批量 resume/archive/delete。
- [x] 更新验证脚本。
- [x] 运行验证和 Debug 构建。

## 验证
- `codex archive --help` 和 `codex delete --help` 确认 CLI 支持对应命令。
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- Codex session context menu 已移除 `Open`。
- Session 列表支持多选；右键已选中项时，`Resume in Terminal`、`Archive`、`Delete` 会对全部选中项生效。
- `Delete` 先弹出 App 级确认，再执行 `codex delete --force <session_id>`，避免后台 CLI 卡在二次确认。

# Codex Session 终端运行态

## 假设
- 只需要识别 Codex CLI session 是否正在 Terminal 里运行。
- 运行态来自本机进程打开的 session jsonl 文件和 tty。
- 双击 cell 优先跳转到当前设置终端里对应 tty 的窗口/标签；暂不做跨所有终端的复杂窗口枚举。

## 计划
- [x] 新增运行态模型和检测工具。
- [x] 加载 sessions 时合并运行态。
- [x] 列表 cell 增加状态点并支持双击跳转。
- [x] 更新验证脚本。
- [x] 运行验证和 Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- Session 运行态通过 `ps` + `lsof` 读取正在打开的 Codex rollout jsonl 文件并映射到 tty。
- Cell 左侧绿色状态点表示正在 terminal 中运行，灰点表示未运行。
- 双击正在运行的 session 会按 tty 尝试激活 Terminal/iTerm2 对应 tab；其他 terminal 先只激活应用。

# Codex Session 跳转图标

## 假设
- 单击行应保持 List 原生选择行为。
- 只有正在 terminal 运行的 session 需要显示跳转图标。
- 图标点击执行已有 terminal tab 激活动作。

## 计划
- [x] 移除 row 双击手势。
- [x] 为 active runtime session 增加跳转图标按钮。
- [x] 更新验证脚本。
- [x] 运行验证和 Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- 移除了 session row 的双击手势，避免影响 `List(selection:)` 的单击选择。
- 只有正在 terminal 运行的 session 显示跳转图标。
- 点击跳转图标会调用已有 tty 激活逻辑跳到活跃 terminal tab。

# Codex Session 跳转日志

## 假设
- 点击跳转无反馈，需要日志覆盖 UI 点击、store 分发、终端激活、AppleScript 返回值和错误。
- 日志使用现有 `Log`，会进入 `/Users/caishilin/.venom/logs/Shark.log`。
- 顺手兼容 tty 的 `/dev/ttys013` 与 `ttys013` 两种 AppleScript 表达。

## 计划
- [x] 在跳转按钮 action 添加点击日志。
- [x] 在 `WorkspaceStore.activateCodexSessionTerminal` 添加 session/tty 日志。
- [x] 在 `TerminalOpener.activateTerminalTab` 和 AppleScript 执行结果添加日志。
- [x] 在 runtime detector 添加识别结果日志。
- [x] 更新 lesson 和验证脚本。
- [x] 运行验证和 Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- 跳转链路现在会输出 `[TerminalJump]` 日志：按钮点击、session id、tty、目标 terminal app、AppleScript result/error、fallback。
- 运行态扫描会输出 `[CodexRuntime]` 日志：扫描进程数、识别到的 session/pid/tty、最终状态数量。
- AppleScript tty 匹配同时尝试 `/dev/ttysxxx` 和 `ttysxxx`，避免不同终端返回格式不一致。

# Codex Session 终端跳转权限修复

## 假设
- 日志中的 `-1743 Not authorized to send Apple events to iTerm` 是跳转无效的直接原因。
- 需要给生成的 Info.plist 增加 `NSAppleEventsUsageDescription`。
- Hardened Runtime 下需要 Apple Events entitlement。

## 计划
- [x] 增加 Apple Events usage description。
- [x] 增加 Apple Events automation entitlement。
- [x] 运行验证和 Debug 构建。
- [x] 说明已有拒绝权限时的系统设置处理方式。

## 验证
- 从 `/Users/caishilin/.venom/logs/Shark.log` 确认跳转失败原因为 `NSAppleScriptErrorNumber = "-1743"`，即 Apple Events 未授权。
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- 已为生成的 Info.plist 增加 `NSAppleEventsUsageDescription`，用于系统弹出自动化权限提示。
- 已为 hardened runtime 增加 `com.apple.security.automation.apple-events` entitlement。
- 如果本机已拒绝过权限，需要在系统设置中允许 Shark 控制 iTerm/Terminal，或重置 Apple Events 权限后重试。

# Codex Session 移除危险跳转

## 假设
- AppleScript/Automation 跳转 terminal tab 会触发系统级输入法/光标异常，必须先移除入口。
- 保留运行状态点即可，用户仍可看到 session 是否运行中。
- 不再申请 Apple Events 权限，避免触发 TCC/Automation 路径。

## 计划
- [x] 移除 Codex session row 跳转按钮。
- [x] 移除 Codex session terminal activation 回调链路。
- [x] 移除本次为跳转添加的 Apple Events Info.plist 和 entitlement。
- [x] 更新验证脚本，禁止 Codex jump/TerminalJump 路径。
- [x] 运行验证和 Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- 已移除 Codex session 的危险 terminal tab 跳转按钮。
- 已移除 Codex session 专用 `TerminalJump` 回调链路和 Apple Events 权限配置。
- 保留运行状态点，只展示 session 是否在 terminal 中运行。

# Codex Session iTerm 标题跳转

## 假设
- 只支持 iTerm2，避免重新引入多终端 AppleScript 分支。
- Shark 启动的 Codex session 会设置唯一 tab title。
- 跳转只按 tab title 查找，不再按 tty/session id 枚举。
- 既有未通过 Shark 启动的 tab 可能没有标题，暂不处理。

## 计划
- [x] `resume` 时设置 iTerm tab title。
- [x] 增加按 title 跳转 iTerm tab 的最小方法。
- [x] 恢复运行中 session 的跳转按钮，但仅对 iTerm2 可用。
- [x] 补回 Apple Events 权限配置。
- [x] 更新验证脚本。
- [x] 运行验证和 Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- `Resume in Terminal` 现在会先设置 tab title：`Codex <session-id-prefix>`。
- 跳转按钮使用 iTerm2 AppleScript 按 tab title 精确选择，不再按 tty 或 session id 枚举。
- 既有不是通过 Shark 启动的 Codex tab 不一定有该 title，可能无法跳转。

# Codex Session iTerm TTY 跳转

## 假设
- 不能用 tab title 匹配 session；同一个 tab 可能连续运行多个 Codex session。
- CodeIsland 的关键做法是保存终端稳定标识，如 iTerm session id 或 tty。
- Shark 目前没有 hook 采集 `ITERM_SESSION_ID`，但运行态检测已经能从进程拿到 tty。
- 最小正确实现：删除 title-based 路径，按运行中 session 的 tty 选择 iTerm2 tab。

## 计划
- [x] 参考 CodeIsland 的 iTerm tty fallback 逻辑。
- [x] 移除 `Resume in Terminal` 设置 tab title。
- [x] 将跳转改为 `tty of session` 匹配。
- [x] 更新验证脚本，禁止 title-based 匹配。
- [x] 运行验证和 Debug 构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- 已删除 tab title 作为 Codex session 身份的实现。
- `Resume in Terminal` 现在只执行 `codex resume <session_id>`，不再写 terminal title。
- 运行中 session 的 jump 按钮现在使用进程运行态里的 tty，通过 iTerm2 `tty of session` 选择对应 tab/session。
- 未引入 CodeIsland 的 hook/IPC 架构；等需要跨终端或 iTerm session id 级别精确匹配时再加。

# Codex Hooks 设置注入

## 假设
- 目标是在 Settings 页面提供一个按钮，让用户把 Shark 的 Codex hook 注入 Codex 配置。
- 使用官方支持的 `~/.codex/hooks.json`，不修改 `config.toml`。
- 最小事件集：`SessionStart` 记录终端标识，`Stop` 标记 inactive，`PreToolUse` / `PostToolUse` 刷新 lastSeen。
- helper 写本地快照到 Shark App Support，Shark session runtime 优先读取快照，再用现有 `lsof` 扫描兜底。
- 不实现卸载、hook trust UI 或 socket server；用户仍需在 Codex `/hooks` 中信任新 hook。

## 计划
- [x] 新增 Codex hook installer：生成 helper 脚本并合并 `~/.codex/hooks.json`。
- [x] 新增 runtime snapshot 读取，支持 iTerm session id 和 tty。
- [x] Settings Terminal tab 增加 Codex Hooks 安装入口和状态文案。
- [x] iTerm 跳转优先用 `unique ID of session`，再用 tty。
- [x] 更新验证脚本并运行构建。

## 验证
- `bash scripts/verify-codex-sessions-ui.sh` 通过。
- `bash scripts/verify-swiftui-structure.sh` 通过。
- `git diff --check` 通过。
- `xcodebuild -scheme Shark -configuration Debug -derivedDataPath build -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build` 通过。

## Review
- Settings 的 Terminal tab 新增 Codex Hooks 安装入口。
- 安装会生成 `~/Library/Application Support/Shark/codex-session-hook`，并把 `SessionStart`、`Stop`、`PreToolUse`、`PostToolUse` 注入 `~/.codex/hooks.json`。
- helper 将 session runtime 快照写入 `~/Library/Application Support/Shark/CodexSessionRuntime`。
- Session 跳转现在优先用 hook 捕获的 iTerm session id，再回退到 tty 和现有 `lsof` 检测。
- 未实现卸载、socket server 和 hook trust 管理；Codex 要求时仍需用户在 `/hooks` 中信任。

# npm 发布 1.12.1

## 假设
- npm 当前最新版为 `1.11.0`，目标版本 `1.12.1` 尚未发布。
- 原生 App 的 npm 包只包含安装脚本；DMG 由 GitHub Release `v1.12.1` 提供稳定下载地址。
- 本地 `v1.12.1` tag 尚未推送；发布准备提交后需让 tag 指向最终 release commit。
- npm 登录、push、GitHub Release 和 `npm publish` 都是独立失败点，正式远端动作前再次确认。

## 计划
- [x] 将 npm 包改为远端下载 DMG，并同步 lockfile。
- [x] 验证目标 DMG、npm 包内容和 publish dry-run。
- [x] 核对 npm 登录态、远端 tag 和 GitHub Release 状态。
- [ ] 列出正式发布动作并取得用户确认。
- [ ] 提交发布准备、推送 tag、上传 DMG 并发布 npm 包。
- [ ] 从 npm registry 验证 `latest` 为 `1.12.1`。

## Review
- `npm pack --dry-run --json` 与 `npm publish --dry-run --access public --json` 通过，包内只有 `README.md`、`install.js`、`package.json`。
- 安装脚本模拟验证通过：按 `1.12.1` 生成 GitHub Release URL、写入临时 DMG 并调用 `open`。
- `dist/SharkSpace-1.12.1.dmg` 已存在，SHA-256 为 `183230216aa9eafd8d921e275aa485dcfc1953052f76cdfc5d7f7744a4062cbd`。
- 远端尚无 `v1.12.1` tag 和 GitHub Release；DMG URL 当前返回 404。
- `npm whoami` 返回 `E401`，需完成 npm 登录后才能正式发布。
