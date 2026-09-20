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

## 法条包范围（暂定）

从法索 / LiJiaKit LegalKnowledge 子集打包进律书：
- 民法典及相关司法解释（民事常用）
- 刑法及相关司法解释（刑事常用）
- 后续可扩：民事诉讼法、刑事诉讼法等（同一接口）

构建：依赖 `LiJiaKit` path 产品 `LegalKnowledge`；语料复制策略对齐 `fasuo-ios/scripts/gen_project.sh`（可先子集 manifest）。

## UI 落点（在现有三栏上）

- 中栏材料：区分「原始」与「已结构化」；表格行显示「打开 Excel」而非碎文本预览为主
- 右栏文书：引用角标可选显示；长按/旁路可打开隐式来源
- 新工位条（剧本工厂感）：导入 → 结构化（表）→ 选文书类型 → 生成 → 溯源检查

## 实现分期

P0：架构文档 + CasePack 目录约定 + LegalCitation 模型 + 空壳 TableJob/法条包接入点  
P1：xlsx 真写（ZipWriter/OOXML 或成熟库）+ PDF 表初识（可先人工框选）  
P2：文书生成强制读 structured/ + 引用必须经 LegalKnowledge 校验  
P3：隐式溯源 UI（不打断阅读，可一键跳原文）
