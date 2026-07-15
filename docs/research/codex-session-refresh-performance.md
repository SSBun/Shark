# Codex Session 列表刷新性能研究

## 结论

当前约 2.6–2.7 秒的刷新时间主要来自两处：

1. 对 19 个候选进程串行启动 19 次 `lsof`，约 1.83 秒。
2. 每次打开 2,538 个全局 JSONL 文件读取首行，再筛选 workspace，约 0.52 秒。

推荐分两步优化：

1. 把 19 次 `lsof` 合并为一次批量 PID 查询，预计总刷新降到约 0.9 秒。
2. 复用已经读取的 SQLite `threads` 数据，只对数据库未覆盖的 JSONL 做首行 fallback，预计总刷新进一步降到约 0.4 秒。

不建议 hooks-only、并行启动多个 `lsof`、维护常驻 `lsof` 或立即引入 `libproc`。

## `lsof` 检查在做什么

`lsof` 是 “list open files”。Shark 先运行 `ps`，找出有 TTY 且命令行包含 `codex` 的进程；随后对每个 PID 执行：

```text
/usr/sbin/lsof -Fn -p <PID>
```

`-p` 限制目标进程，`-F` 输出适合程序解析的字段，`n` 表示文件名。Shark 从结果中寻找进程正在打开的 `~/.codex/sessions/**/*.jsonl`，从 rollout 文件名提取 session ID，再把该 session 标记为正在对应 PID/TTY 中运行。这个映射用于列表绿点、运行状态和 Jump to iTerm，而不是用于读取 session 内容。实现见 [`CodexSessionRuntimeDetector.swift`](../../Shark/Utilities/CodexSessionRuntimeDetector.swift)。

lsof 官方文档确认 `-p` 支持无空格的逗号分隔 PID 集合，因此不需要为每个 PID 单独启动进程；字段输出始终包含 `p` PID 字段，并以 process/file sets 组织，可以从一次输出恢复 PID → session 文件映射。[lsof 官方 man page](https://lsof.readthedocs.io/en/stable/manpage/)

## 实测方法与环境

- 数据：`~/.codex/sessions` 与 `archived_sessions` 共 2,538 个 JSONL。
- 进程：19 个满足现有过滤条件的候选 PID。
- 匹配根路径：用户 home directory；该选择不减少前置工作，因为当前实现先扫描全部历史，再按路径筛选。
- 运行：Release 优化的临时 Swift harness，直接调用现有管理器或复刻同一 `Foundation.Process` 路径；每项连续运行三次。
- 临时 instrumentation 和 harness 已在测量后删除。

## 当前耗时分解

| 阶段 | 稳态耗时 | 占约 2.60 秒 | 原因 |
|---|---:|---:|---|
| SQLite `threads` 查询与解码 | 0.087 秒 | 3.3% | 启动一次 `sqlite3` 并解码约 2,542 条记录 |
| `session_index.jsonl` | 0.002 秒 | 0.1% | 文件很小 |
| 枚举 session 文件路径 | 0.007 秒 | 0.3% | 只枚举 URL，成本很低 |
| `ps -axo` | 0.149 秒 | 5.7% | 获取所有进程、TTY 和完整命令 |
| 读取 hook snapshots | 0.003 秒 | 0.1% | 小 JSON 文件读取 |
| 19 次串行 `lsof` | 1.830 秒 | 70.4% | 19 次 `Foundation.Process` 启动及 19 次内核文件表扫描 |
| 打开 JSONL 首行、筛选、排序 | 0.521 秒 | 20.0% | 每次刷新都打开全部 2,538 个 JSONL |

连续完整运行结果约为 2.60、2.60 和 2.75 秒；另一次复测为 2.70 秒。SQLite 不是主因。

## 优化 1：一次批量 `lsof`

保留当前 `ps` 过滤语义，只把候选 PID 连接成一个参数：

```text
/usr/sbin/lsof -Fn -p 123,456,789
```

Swift `Process` 实测：

| 方案 | 三次耗时 | 找到的 session 文件 |
|---|---:|---:|
| 19 次串行调用 | 1.838 / 1.848 / 1.877 秒 | 10 |
| 1 次批量调用 | 0.126 / 0.124 / 0.124 秒 | 10 |

两种方式返回的 session 文件集合完全相同。单项减少约 1.72 秒，完整刷新预计从约 2.60 秒降到约 0.90 秒。

实现时需要保留两个细节：

- 按 `p` 字段切换当前 PID，再把后续 `n` 文件字段归属到该 PID。官方字段格式明确把输出组织为 process set 和 file set。[lsof 官方字段输出说明](https://lsof.readthedocs.io/en/stable/manpage/#output-for-other-programs)
- macOS 自带 lsof 4.91 不支持新版 `-Q`。如果 PID 在 `ps` 和 `lsof` 之间退出，`lsof` 可能返回非零，但 stdout 仍包含其他有效 PID 的结果。因此批量 helper 必须解析非空 stdout，不能因一个 PID race 丢弃整批输出。

不应改成 19 个并行 `lsof`：它仍保留 19 次进程启动和重复内核扫描，只是把资源尖峰换成较短等待。官方文档也明确把进程级 `-p` 选择视为高效过滤方式，并指出重复启动 `lsof` 有启动成本。[lsof 官方 man page](https://lsof.readthedocs.io/en/stable/manpage/)

## 优化 2：SQLite-first，JSONL delta fallback

`CodexSessionManager` 已经从 SQLite `threads` 表加载 `id`、`cwd`、标题、时间、归档状态、`rollout_path`、source 和 model，但随后仍打开所有 JSONL 首行重新取得 ID、cwd 和时间。实现见 [`CodexSessionManager.swift`](../../Shark/Utilities/CodexSessionManager.swift)。

更安全的最小方案不是完全放弃 JSONL，而是：

1. 继续枚举全部 JSONL 路径；该步骤实测只有 0.007 秒。
2. 用已经加载的 `ThreadRecord.rolloutPath` 构建数据库覆盖集合。
3. 直接从有效的 `ThreadRecord` 创建 sessions。
4. 只对数据库未覆盖的 JSONL 读取首行。
5. 数据库不可用或为空时，退回现有全量 JSONL 路径。

当前数据对比：SQLite 路径得到 232 条 home-root 匹配记录，现有 JSONL 路径得到 228 条；SQLite 多出的 4 条全部对应已不存在的 rollout 文件，JSONL-only 为 0。排除缺失文件后，两边 ID 集合完全相同。SQLite 查询、JSON 解码和 2,542 次轻量文件存在检查合计约 0.081–0.084 秒。

该方案消除约 0.52 秒全量文件首行读取，同时保留数据库延迟、缺记录或 schema 不可用时的 JSONL fallback。与批量 `lsof` 组合后，预计完整刷新约 0.35–0.45 秒。

SQLite 官方 CLI 支持 `-json` 输出和 `-readonly` 打开模式；Shark 可以继续使用当前 CLI 路径，无需为约 0.09 秒的查询引入新依赖。[SQLite CLI 官方文档](https://www.sqlite.org/cli.html)

## hooks 为什么不能单独替代 `lsof`

读取 hook snapshots 只需约 0.003 秒，但当前 126 个 snapshot 中有 13 个标记为 active，只有 2 个记录的 PID 仍然存活，另外 11 个已经失效。进程崩溃、强制退出或 Stop hook 未执行都会留下 stale active state。

因此 hooks 适合补充 iTerm session ID 或作为即时提示，不适合作为运行状态的唯一真相。若优化时顺手处理正确性，应使用当前进程/lsof 结果验证 active snapshot，而不是跳过 `lsof`。

## 可选的感知性能优化

如果约 0.4 秒仍不够快，可以分两阶段发布：

1. SQLite/JSONL delta 完成后先展示 session 列表，目标约 0.1 秒。
2. 批量 `lsof` 完成后更新运行绿点和 Jump 状态。

这会改善首屏感知时间，但不会进一步降低总 CPU/I/O；在完成前两项实际优化前不值得增加第二阶段状态管理。

## 暂不采用

- **hooks-only**：实测 stale 比例过高，会显示错误运行状态。
- **`lsof -c codex`**：本机能找到相同文件，但依赖内核 command name 前缀；当前候选进程中还有 `node`，跨安装方式不如沿用现有 `ps` 语义稳妥。
- **`lsof -O`**：官方说明它可能降低启动成本，但会绕过防阻塞策略，并警告可能在内核调用无响应时挂住；约 0.12 秒的单次批量调用不值得承担风险。[lsof 官方选项说明](https://lsof.readthedocs.io/en/latest/options/)
- **lsof repeat mode/常驻进程**：官方确认 repeat mode 可减少启动成本，但需要管理常驻子进程、动态 PID 集合和生命周期；一次批量调用已经足够快。[lsof 官方 man page](https://lsof.readthedocs.io/en/stable/manpage/)
- **直接接入 `libproc`**：可以减少外部进程，但需要 C API 桥接和自行遍历进程文件描述符；应在批量 `lsof` 后仍有可测瓶颈时再考虑。
- **session metadata cache**：需要失效策略，而现有 SQLite 已经是可复用索引；DB-first + delta fallback 更简单。

## 推荐实施顺序与验收

1. 先实现批量 `lsof`，要求结果集合与现有逐 PID 路径一致，且单项耗时低于 0.25 秒。
2. 再实现 SQLite-first + JSONL delta fallback，要求 session ID、title、cwd、archive 和时间排序与现路径一致。
3. 在 0、1、10、100+ 候选进程以及数据库缺失、数据库有 stale path、存在 JSONL-only session 的 fixtures 上验证。
4. 用当前 2,500+ session 数据重新运行完整基准，目标稳态低于 0.5 秒。
