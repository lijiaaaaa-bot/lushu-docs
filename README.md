# 律书（lushu-docs）

律师工作开发软件集群 · **文书生成**产品线。与案匣同族：案匣管原件与检索，律书把材料写成文书。

当前交付：**材料总结**。后续在同一应用内扩展起诉状、答辩状（`DocumentKind`）。

## 本轮：界面先行（案匣 Theme 锁定）

产品 UI **只用** LIVE 案匣 `Theme.swift`（文具柜：paper / walnut / brass）。

**不要用** anxia-support 营销站色板（墨青 `#173F59`、浅空 `#EAF5FB`、点金 `#B88B2E`）。那是网站，不是 App。

`Lushu/App/Theme.swift` 与案匣同一套 `Color(light:dark:)`：

| Token | Light | Dark |
|-------|-------|------|
| paper | `#F4EFE6` (`0xF4EFE6`) | `#12100C` (`0x12100C`) |
| card | `#FBF7F0` (`0xFBF7F0`) | `#1C1914` (`0x1C1914`) |
| ink | `#2A2118` (`0x2A2118`) | `#EDE6DA` (`0xEDE6DA`) |
| mute | `#6F675C` (`0x6F675C`) | `#9A9084` (`0x9A9084`) |
| walnut | `#4A3426` (`0x4A3426`) | `#C4A484` (`0xC4A484`) |
| brass | `#A6844A` (`0xA6844A`) | `#C9A86A` (`0xC9A86A`) |

`corner` 14 continuous；`pagePad` 22。卡片：`Theme.card` 底 + `walnut.opacity(0.12)` 描边，强调用 brass。禁止系统蓝 CTA；底栏为衬线字「选材料 · 成文书 · 导出」。

### 三栏

`NavigationSplitView`：

1. **侧栏**：大衬线「律书」、细边检索；来源（案匣 / iCloud 文件夹、导入）；文书类型（材料总结可用，起诉状 / 答辩状禁用占位）；底栏 **选材料 · 成文书 · 导出**
2. **中栏**：材料抽屉卡片（非系统 List）；未归描边，已归填色
3. **详情**：稿纸预览，衬线标题

引导页同一套纸色与底栏。

### 字体

品牌 / 屏幕标题用 **Noto Serif SC** Black / Bold（与案匣相同）。完整 CJK 字重约十余 MB，未入库。

将案匣工程中的 `NotoSerifSC-Black.otf`、`NotoSerifSC-Bold.otf` 拷入 `Lushu/Fonts/` 即可嵌入（`ATSApplicationFontsPath = Fonts`）。未放入时，`Theme.serif` 按 PostScript 名探测，回退宋体（Songti SC）或系统 serif，**不会改色板**。

## 未接线（按钮可点，只说明）

- 系统选档、security-scoped bookmark
- PDF / DOCX 正文解析
- 大模型请求与钥匙串
- NSSavePanel / 写回文件夹

见 `Lushu/Services/PendingIntegrations.swift`。

## 定位与案匣关系

| 产品 | 职责 |
|------|------|
| 案匣 Anxia | 律师的柜子。原件进格子，检索已索引正文。 |
| 律书 Lushu | 从案匣或导入材料生成文书。不代写法条。 |

## 扩展文书类型

`Lushu/Models/DocumentKind.swift`：`summary` 可用；`complaint` / `answer` 侧栏占位。新增类型只加枚举与模板，不另起应用。

## 如何打开 Xcode

1. Xcode 16+，打开 `Lushu.xcodeproj`。
2. Scheme **Lushu**，目标 My Mac。
3. Run。引导页可「载入示例」看三栏。Canvas 预览：引导 / 工作区 / 稿纸。

快捷键：⌘1 选材料 · ⌘2 成文书 · ⌘3 导出 · ⌘O 案匣文件夹 · ⌘E 导出。

## Entitlements / iCloud 占位

沙盒、用户自选读写、app-scoped bookmarks 已开。iCloud Documents 未启用（避免无团队无法编译）。接入时在 Signing & Capabilities 勾选并填写与案匣约定的容器 ID。

密钥只进钥匙串，禁止入库。
