# Lessons

## 2026-07-15
- 在功能构想对话中，用户提出与候选功能同域的状态问题时，先判断它们是否是在定义界面必须回答的问题；语义仍可两解时先确认意图，不要直接把它当作当前仓库诊断。
- 当用户选择驱动异步子列表加载时，切换入口必须立即清空上一选择的数据；每个异步结果提交前还必须核对当前选择的稳定 ID，避免旧请求晚到后覆盖新界面。
- 设计 Codex session 恢复体验时，不要用“最近更新”代替会话身份确认；当标题不足以区分 session 时，应先提供用户/助手正文预览，再让用户决定 resume 或跳转。

## 2026-06-18
- 在 Shark 项目中开始实现非平凡功能前，必须先更新 `tasks/todo.md` 写出假设、计划和验证项。即使用户已经批准 UI 方案，也不能直接进入代码编辑。
- 如果用户指出流程遗漏，先补齐 `tasks/todo.md` 和本文件，再继续实现或验证。

- 做 macOS 终端/AppleScript 跳转时，首次实现必须记录入口参数、目标 app、normalized tty、AppleScript result/error 和 fallback 分支；否则用户点击无效时无法从 `Shark.log` 判断卡在哪一层。
- AppleScript 控制 Terminal/iTerm 属于 macOS Automation 权限；实现前必须同时检查 `NSAppleEventsUsageDescription` 和 `com.apple.security.automation.apple-events`，否则会出现 `-1743 Not authorized to send Apple events`。

- 如果某个 UI 功能会触发系统级异常（例如输入法/光标卡死），优先移除危险入口；不要继续围绕权限或 AppleScript 做补丁。
- Codex session 不能用 terminal tab title 做身份匹配；同一个 tab 可能运行多个 session。必须优先使用稳定运行态标识（iTerm session id、tty、pid 等），没有稳定标识就不要声称可以精确跳转。

## 2026-06-25
- 为原生 App 设计 npm 发布流程时，不要默认把 DMG 文件放进 npm 包；标准方式是让 `install.js` 在 `npm install` 时下载对应版本 DMG 并打开。
- npm 包名必须带 scope/prefix；如果不能从现有 `package.json`、npm 登录态或项目归属可靠推断，先询问用户。
