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

## 生成安装器（.pkg）

```bash
./scripts/build_installer.sh
```

生成结果：`build/WYClean-installer.pkg`

## 文本清洗策略文档

- 规则对照与迁移说明见：[`docs/cleaning-rules.md`](docs/cleaning-rules.md)
