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

`corner` 14 continuous；`pagePad` 22。卡片：`Theme.card` 底 + `walnut.opacity(0.12)` 描边，强调用 brass。禁止系统蓝 CTA。工位条：导入 → 结构化 → 文书 → 溯源。

### 首页（左话题 + 右聊天）

第一屏是 `HomeChatView` **两栏主壳**，不是单栏居中大标题。

- **左栏**：窄话题列表（`home.topicList`）。「新对话」= home inbox；每个 CaseSource 一条（示例为「海天乙方电费+停车费」）。可新建、选中高亮（胡桃描边，不是系统蓝）、删除。
- **右栏**：当前话题的短对话 + 底栏输入（选材料 / 导入 / 示例 / 发送）。空态有胶囊 chips（`home.haitianChip`）。
- 消息只要短气泡；材料紧凑列表；生成后「点此下载」。任务卡全文与报告正文在工作区。
- 工作区从右上「工作区」进入，不塞进首页、不抢主聊天。

色板仍是案匣 paper / card / ink / mute / walnut / brass。禁止系统蓝列表与 CTA。

### 三栏（生成后 / 深挖）

`NavigationSplitView`：

1. **侧栏**：大衬线「律书」、细边检索；来源；文书类型（材料总结 / 专项报告可用，起诉状 / 答辩状禁用占位）；底栏 **选材料 · 成文书 · 导出**
2. **中栏**：材料抽屉卡片
3. **详情**：稿纸 + 任务卡 chips；右侧仍可打开本案撰稿对话

### 字体

品牌 / 屏幕标题用 **Noto Serif SC** Black / Bold（与案匣相同）。完整 CJK 字重约十余 MB，未入库。

将案匣工程中的 `NotoSerifSC-Black.otf`、`NotoSerifSC-Bold.otf` 拷入 `Lushu/Fonts/` 即可嵌入（`ATSApplicationFontsPath = Fonts`）。未放入时，`Theme.serif` 按 PostScript 名探测，回退宋体（Songti SC）或系统 serif，**不会改色板**。

## 结构化案件包与法索

见 `docs/ARCHITECTURE.md`。

- `CasePack`：`raw/` · `structured/tables/*.xlsx` · `structured/texts/*.jsonl` · `citations/` · `drafts/`
- 表结构化工位写出**真 Excel**（OOXML），不是碎行文本
- `DocumentGenerator` 只接受 `StructuredCaseInputs`；有任务卡时走 `generate(kind:inputs:brief:)`，按 BriefCard 组章节，仍不得编造法条或台账数字
- `LegalCitation` 默认 hidden；溯源工位从 bundled 语料打开原文
- `LegalCorpus` 加载 `Lushu/Resources/LegalKnowledge/`（法索 / LiJiaKit LegalKnowledge **2026.09.0** 子集：`2026.09.0-lushu-subset`，44 部、3788 条块）。范围：民法典各编 + 刑法及修正案 + 明确涉及民法典/刑法的司法解释。**查找失败即报错，不编造。** 完整法索包是后续事项。生成引用只能来自这些 JSON。

## DeepSeek 自备密钥（BYOK）

与**剧本工厂**相同：粘贴自己的 DeepSeek API Key，**只写入 macOS 钥匙串**。禁止提交到仓库、UserDefaults、`.env`。

- 设置页：粘贴 / **保存到钥匙串** / **清除密钥**（中文文案）。首页标题旁也可打开设置。
- 存储：`APIKeyStore`（service `bot.lijiaaaaa.lushu`，account `deepseek.apiKey`，`AfterFirstUnlockThisDeviceOnly`）。本仓库未包含 LiJiaKit KeychainKit；path 可用时替换为本实现。
- 请求：`DeepSeekClient` → `https://api.deepseek.com/chat/completions`，模型 `deepseek-chat`，`thinking.type = disabled`，非流式。本仓库未包含 LLMKit；同模式薄封装。
- **无密钥**：首页仍做确定性 `BriefCard` 解析与结构化本地落稿。模型回执 / 润色只提示打开设置，**不编造内容**。
- **有密钥**：可选回执改写与稿面润色，只改已落地措辞。`GroundedLLM` 禁止编造法条、金额、电价 P、全场灯数 N。
- 单元测试：`LushuTests/DeepSeekClientTests.swift`（请求体含思考链关闭，且不嵌入密钥）。

## 未接线（按钮可点，只说明）

- 系统选档、security-scoped bookmark（引导页请选取 iCloud Drive「材料」）
- PDF 正文解析（合同.pdf、审计件不入库，也不在本轮解析）
- NSSavePanel / 写回文件夹

bundled 示例的 DOCX 已做 OOXML 正文提取。见 `Lushu/Services/PendingIntegrations.swift`。

## 示例案件：海天×阜外停车场费用材料

引导页「载入示例案件」读 `Lushu/Resources/SampleCase/haitian-parking/`：

- 5 份 `.xlsx`（2022–2026 阜外医院职工停车信息表）→ CasePack `structured/tables/` **真工作簿**（原件拷贝，不是碎行重写）
- 1 份 `.docx`（2026.9.16 停车场照明用电测算表）→ `raw/` + `structured/texts` 提取正文

**完整原件**在承办律师 iCloud Drive「材料」：

`/Users/lijia/Library/Mobile Documents/com~apple~CloudDocs/材料`

**不要提交**该目录里的大体积 PDF（`合同.pdf`、审计件）。本仓库只收可入库的 xlsx / docx 子集。

### 首页对话（豆包式用法，不是通用机器人）

首页就是短对话：贴要点 → 选材料 / 示例 → 短确认 → 生成并下载。长任务卡与报告正文在工作区。未挂案件时要点暂存在 inbox。可选 DeepSeek 只润色落稿，不往气泡里贴全文。

「载入示例案件」或 chip「海天乙方电费+停车费报告」写入 `example-brief.txt`。生成列出 2022–2026 真表，并写明缺 2018–2021 表、电价P、全场灯数N。不编法条、不估数。

起诉状 / 答辩状仍是侧栏占位，不另做第二套首页用法。

## 法条子集

随应用打包（Xcode 同步 `Lushu/Resources/LegalKnowledge/`）：

- `corpus_manifest.json`
- `laws_meta.json`
- `laws_chunks.json`（`id`, `law_id`, `law_title`, `category`, `article_num`, `heading`, `text`）
- `legal_practice_terms.json` / `repealed_laws.json`

父语料：法索 LiJiaKit LegalKnowledge `2026.09.0`。本包 `2026.09.0-lushu-subset`。文书生成不得引用包外条文。单元测试：`LushuTests/LegalCorpusTests.swift`（刑法/第一条、民法典总则/第一条与文件原文比对）；`LushuTests/BriefCardTests.swift`（示例要点 → 任务卡 → 缺口，不编造电价/法条）。Canvas 预览「语料探测」。

## 定位与案匣关系

| 产品 | 职责 |
|------|------|
| 案匣 Anxia | 律师的柜子。原件进格子，检索已索引正文。 |
| 律书 Lushu | 从案匣或导入材料生成文书。不代写法条。 |

## 扩展文书类型

`Lushu/Models/DocumentKind.swift`：`summary` / `customReport` 可用（后者按任务卡组章节）；`complaint` / `answer` 侧栏占位。新增类型只加枚举与模板，不另起应用。

## 如何打开 Xcode

1. Xcode 16+，打开 `Lushu.xcodeproj`。
2. Scheme **Lushu**，目标 My Mac。
3. Run。首页应干净：短气泡 + 材料列表。点「海天乙方电费+停车费报告」或「示例」，再点「生成文书」，对话只出现「已生成…点此下载」，不展开全文。核对缺口（电价P、全场灯数N、2018–2021 表）。

快捷键：⌘1 导入 · ⌘2 结构化 · ⌘3 文书 · ⌘4 溯源 · ⌘O 案匣文件夹 · ⌘E 导出。

## Entitlements / iCloud 占位

沙盒、用户自选读写、app-scoped bookmarks 已开。iCloud Documents 未启用（避免无团队无法编译）。接入时在 Signing & Capabilities 勾选并填写与案匣约定的容器 ID。

DeepSeek 密钥只进钥匙串，禁止入库。见上文「DeepSeek 自备密钥（BYOK）」。
