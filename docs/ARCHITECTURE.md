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

## 撰稿对话（CaseBriefChat）

文书工位内的**案件绑定**对话，不是豆包式全局聊天。

- 会话键 = 当前 `CaseSource.id` / CasePack。没有选中案件则没有对话。
- 用户长要点解析为 `BriefCard`：立场（甲方/乙方/中立）、文书目的、章节、计算口径（仅用户已写）、年份/范围、额外约束、缺口。
- `DocumentGenerator.generate(kind:inputs:brief:)` 按任务卡组章节，**只填** `StructuredCaseInputs`（真表清单 + 已定位文本）。缺 电价P、全场灯数N、某年停车表 → 写入缺口，不估数。
- 不得编造法条；引用仍须 `LegalCorpus.validate`。润色若接线，只改已落稿措辞。
- 对比豆包：有案件边界、有结构化真源、有任务卡、禁止自由 invent。

示例子集预置 `example-brief.txt`（海天乙方 · 2018–2026 停车费+电费报告要点）。「载入示例案件」后到文书工位即可：对话 → 任务卡 chips → 生成文书。

## UI 落点（在现有三栏上）

- 中栏材料：区分「原始」与「已结构化」；表格行显示「打开 Excel」而非碎文本预览为主
- 右栏文书：任务卡 chips 在稿面上方；文书工位右侧为撰稿对话（消息列表 + 多行输入；主操作「生成文书」「更新任务卡」）
- 工位条：导入 → 结构化（表）→ 文书（含对话）→ 溯源检查

## 实现分期

P0：架构文档 + CasePack 目录约定 + LegalCitation 模型 + 工位条  
P1：xlsx 真写（ZipWriter/OOXML）  
P2：文书生成强制读 structured/；引用必须经 bundled `LegalCorpus` 校验（子集已接入）  
P3：隐式溯源 UI（稿面默认 hidden；溯源工位打开语料原文）  
P4：案件绑定撰稿对话 + BriefCard + brief-driven 专项报告（确定性组装）
