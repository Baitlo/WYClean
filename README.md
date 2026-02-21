# WYClean

适用于 macOS（Apple Silicon/M 系列）的后台菜单栏应用。

## 功能

- 启动后驻留后台（菜单栏）
- 全局快捷键：`Option + C`
  - 自动触发系统复制（`⌘C`）
  - 对剪贴板文本执行清洗
  - 自动写回剪贴板，用户可直接 `⌘V` 粘贴
- 清洗规则：
  - 删除引用角标（如 `[1]`、`[4-7]`、`(2, 3)`）
  - 删除多余空格与换行
  - 全角英文字母/数字转换为半角
  - 中文语境下英文标点转中文全角标点
  - 删除非英文字母之间的空格（如 `我 是` → `我是`）

## 本地运行

1. 用 Xcode 打开 `WYClean.xcodeproj`
2. Build & Run 后允许辅助功能权限
3. 在任意 PDF 阅读器中选中文本，按 `⌥C`

若 `⌥C` 没有复制到剪贴板，请检查：

1. 系统设置 → 隐私与安全性 → 辅助功能，确认 WYClean 已开启
2. 目标 PDF 应用本身是否支持 `⌘C` 复制（先手动测试一次）
3. 点击菜单栏 WYClean 查看状态提示（会显示是否检测到新的复制内容）

## 生成安装器（.pkg）

```bash
./scripts/build_installer.sh
```

生成结果：`build/WYClean-installer.pkg`

可选：使用 Developer ID 证书签名（推荐，能减少“安装器遇到一个错误”这类泛化报错）：

```bash
export APP_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export INSTALLER_SIGN_IDENTITY="Developer ID Installer: Your Name (TEAMID)"
./scripts/build_installer.sh
```

> 若出现 `xcode-select ... CommandLineTools` 错误，说明当前只启用了命令行工具而非完整 Xcode。请先执行：
> `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`

若安装时出现“安装器遇到一个错误”，请优先排查：

1. 当前 pkg 是否未签名或签名无效（脚本会输出 `pkgutil --check-signature` 结果）
2. `/Applications/WYClean.app` 是否已存在且正在运行（先退出并删除旧版本再安装）
3. 查看安装日志：打开“控制台”并筛选 `installer`，或命令行执行：
   `log show --predicate 'subsystem == "com.apple.installer"' --last 10m`

## 文本清洗策略文档

- 规则对照与迁移说明见：[`docs/cleaning-rules.md`](docs/cleaning-rules.md)
