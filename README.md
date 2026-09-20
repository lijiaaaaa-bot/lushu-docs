# 律书（lushu-docs）

律师工作开发软件集群 · **文书生成**产品线。与 [案匣](https://github.com/lijiaaaaa-bot/anxia-support) 同族：案匣管原件与检索，律书把材料写成文书。

当前交付：**材料总结**。后续在同一应用内扩展起诉状、答辩状（`DocumentKind`）。

## 本轮：界面先行

此里程碑先把 macOS SwiftUI 屏幕走通，便于对照后续视觉说明改版式。

已具备、可点穿的界面：

1. **引导 / 来源选择**：案匣 · iCloud 文件夹（优先）与导入文件 / 文件夹（回退）
2. **工作区**：`NavigationSplitView`（左侧案件来源，右侧详情）
3. **材料库**：清单、类型、大小、纳入状态
4. **文书类型**：仅「材料总结」可进入撰稿；起诉状 / 答辩状为禁用占位
5. **撰稿**：章节轨 + 预览 / 编辑 + 本地摘要按钮
6. **导出面板**：Markdown / 纯文本；写回案匣为说明性按钮

未就绪的能力（按钮可点，给出说明，不中断浏览）：

- 系统选档、security-scoped bookmark
- PDF / DOCX 正文解析
- 大模型请求与钥匙串读写
- 真实 NSSavePanel / 写回文件夹

入口说明见 `Lushu/Services/PendingIntegrations.swift`。

## 定位与案匣关系

| 产品 | 职责 |
|------|------|
| 案匣 Anxia | 律师的柜子。原件进格子，检索已索引正文。 |
| 律书 Lushu | 从案匣或导入材料生成文书。不代写法条。 |

材料来源顺序与产品说明一致：先选案匣 / iCloud 案件夹，再回退到导入。

## 扩展文书类型

`Lushu/Models/DocumentKind.swift` 是唯一扩展点：

```swift
enum DocumentKind {
    case summary    // 当前可用
    case complaint  // 起诉状 · 占位
    case answer     // 答辩状 · 占位
}
```

新增类型时：补枚举、标题与模板，在生成器按 `kind` 分发。不要另起仓库或应用。

## 如何打开 Xcode

1. 安装 Xcode 16 或更新（macOS 14+ 部署）。
2. 打开本仓库中的 `Lushu.xcodeproj`（不要只开文件夹当普通目录编译）。
3. 目标选择 **My Mac**，Scheme 选 **Lushu**。
4. 签名：本地运行可用个人团队；iCloud Documents 需正式容器，见下节。
5. Run。首次为引导页；可用「载入示例案件」审阅完整工作区。

```text
Lushu.xcodeproj
Lushu/
  LushuApp.swift
  App/                 状态、色板、示例数据
  Models/              DocumentKind、来源、材料、草稿
  Views/               引导、分栏、材料库、文书类型、撰稿、导出、设置
  Services/            下一轮接线桩
```

快捷键：⌘1 材料 · ⌘2 文书类型 · ⌘3 撰稿 · ⌘G 本地摘要 · ⌘E 导出 · ⌘O 选择案匣文件夹。

## Entitlements / iCloud 占位

`Lushu/Lushu.entitlements` 已打开沙盒、用户自选文件读写、app-scoped bookmarks。

iCloud Documents **未启用**（避免无开发者团队时工程无法编译）。接入案匣 iCloud 目录时：

1. Signing & Capabilities → iCloud → Documents
2. 填写容器 ID（与案匣约定后写入 README）
3. 取消 entitlements 里的占位注释并填入 `icloud-container-identifiers`

密钥：只进钥匙串，禁止提交 `.env`、`Secrets.plist` 或把 Key 写进源码。`.gitignore` 已排除常见密钥文件。

## 视觉

色板与案匣支持站对齐：墨青 `#173F59`、浅空 `#EAF5FB`、纸白、点金 `#B88B2E`。中文文案，密而不挤，不做消费级闪片。更细的视觉说明到达后，在现有结构上改令牌与间距即可。
