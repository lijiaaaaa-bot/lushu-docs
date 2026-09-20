# 律书架构增量：结构化材料 + 法索知识库

## 参考

- **剧本工厂**：工位工序 → 每步产出可落盘的结构化中间件；下游只吃上游锁定结果；AI 藏在工序里，不直接「自由写」最终物。
- **法索 / LiJiaKit.LegalKnowledge**：法条原文唯一真源；检索可返回，但**生成用到的条文不得编造**，必须能定位到 `lawID + articleNum`（及包内偏移）。
- **案匣 / MaterialKnowledge**：材料块带 `MaterialLocator`；当前 xlsx 只拆成「行文本」——律书要升级为**真表结构**。

## 原则

1. **非结构化 → 结构化**：PDF/扫描表、杂乱 Excel、Word 内嵌表，经「表结构化工位」产出真实 `.xlsx`（多 sheet、表头、行列对齐），禁止只切成碎文本当最终表。
2. **文书只吃结构化**：`DocumentKind` 生成管线的输入 = 结构化案件包（真 Excel + 已定位文本块 + 元数据），不直接拿原始 PDF 字节自由发挥。
3. **法律依据只来自法索语料**：包内先收 **民法（含民法典相关）· 刑法 · 及相关司法解释**；生成时引用必须绑定 `LegalCitation`；UI 默认可不展示脚注，但每条用词/依据在模型里可打开原文位置（隐式溯源）。

## 数据模型（草案）

```
CasePack/
  raw/                 # 原始导入（只读）
  structured/
    tables/*.xlsx      # 真 Excel 产出
    texts/*.jsonl      # 带 locator 的文本块
  citations/           # 本案件已引用的 LegalCitation 缓存
  drafts/              # 文书稿（材料总结 / 起诉状…）
```

`LegalCitation`：
- lawID, lawTitle, articleNum, articleTitle?
- quote（必须与语料原文一致或为其连续子串）
- sourceSpan（语料内起止或条内偏移）
- 展示策略：默认 hidden；需要时弹出法索式条文页

`TableJob`（表结构化工位）：
- input: PDF 页区域 / 原 xlsx / 图
- output: .xlsx URL + schema 推断（列名、类型）
- gate: 人工可改表头后再锁定，供文书工序使用

## 法条包范围

从法索 / LiJiaKit LegalKnowledge **2026.09.0** 抽出子集，随应用打包：`Lushu/Resources/LegalKnowledge/`（`2026.09.0-lushu-subset`，44 部、3788 条块）。

- 民法典各编（总则 / 物权 / 合同 / 人格权 / 婚姻家庭 / 继承 / 侵权责任 / 附则）及明确涉及民法典的司法解释
- 刑法及修正案，以及明确涉及刑法的司法解释
- `LegalCorpus` 按全文 `id`（如 `刑法/第一条`）与 `(law_id, article_num)` 建索引；`lookup` / `validate` 失败即报错，**不编造**
- **生成引用只能来自这些 JSON。** 完整法索包是后续事项，同一接口再扩诉讼法等

## 示例案件材料

`Lushu/Resources/SampleCase/haitian-parking/`（海天×阜外停车场费用材料）：xlsx 进 `structured/tables`，docx 进 `raw/` 并提取。完整原件在 iCloud Drive「材料」；`合同.pdf` 与审计 PDF **不入库**。

## 首页对话（HomeChatView）

**入口是左话题 + 右聊天两栏**（窄侧栏会话列表，右侧当前话题短对话 + 粘底输入）。不是单栏居中大标题，也不是把工作区三栏塞进首页。色板仍是案匣 paper / walnut / brass。禁止蓝气泡、禁止系统蓝列表。

- 未挂案件：要点暂存在 `homeInbox`；回执要求「选材料文件夹」或「载入示例案件」。
- 挂上 CasePack 后，inbox 并入该案。回执确认真表 / 已定位文本，并解析 `BriefCard`。
- 材料 + 任务卡齐全后，「生成文书」本地落稿。首页在奶油纸色上展开稿面预览（跳过材料清单、不贴真表单元格）+ 近全宽下载卡（`home.download`），并给出 2–3 条「相关问题」。**不**自动抢进三栏。
- `DocumentGenerator.generate(kind:inputs:brief:)` 只填结构化材料。乙方电费+停车费测算报告走函件体：读汇总页年度金额、测算表分区功率；参考电价P与灯数N仅在任务卡写明时计算，并标注「以双方确认为准」。缺年不编行金额。合同条号只转写任务卡已粘贴原文。金标准摘录见 `docs/fixtures/haitian-parking-gold-report.md`。
- 可选 DeepSeek（BYOK）：钥匙串有密钥时，回执/润色走 OpenAI 兼容 `chat/completions`（`deepseek-chat`，思考链关闭）。无密钥时本地解析与落稿仍可用，提示去设置，不造假回复。
- 不是通用闲聊：只服务材料总结 / 专项报告。起诉状 / 答辩状仍为禁用占位，本轮不发明第二套首页。

示例子集预置 `example-brief.txt`。空态 chip「海天乙方电费+停车费报告」一键挂材料并写入要点。

## UI 落点

- **首页**：`HomeChatView`（左话题列表，右对话流）。材料卡片挂在**用户消息上方**；助手确认与落稿在纸面展开，不用助手下方 chip 条。AX：`home.topicList` / `home.sample` / `home.haitianChip` / `home.generate` / `home.download`。
- **工作区**：三栏次级界面；任务卡详情、真表列、稿面全文
- 工位条：导入 → 结构化（表）→ 文书 → 溯源检查

## 实现分期

P0：架构文档 + CasePack 目录约定 + LegalCitation 模型 + 工位条  
P1：xlsx 真写（ZipWriter/OOXML）  
P2：文书生成强制读 structured/；引用必须经 bundled `LegalCorpus` 校验（子集已接入）  
P3：隐式溯源 UI（稿面默认 hidden；溯源工位打开语料原文）  
P4：案件绑定撰稿对话 + BriefCard + brief-driven 专项报告  
P5：首页改为豆包式对话入口（HomeChatView），三栏工作区留给生成后  
P6：DeepSeek BYOK（钥匙串 `APIKeyStore` + 设置粘贴/保存/清除 + 可选 `DeepSeekClient` 回执/润色；无密钥不造假）
