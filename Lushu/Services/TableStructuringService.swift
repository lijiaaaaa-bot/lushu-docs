import Foundation

/// 表结构化工位：输入原件区域，输出真实 .xlsx + 列模式，再人工锁定。
struct TableStructuringService {
    var store: CasePackStore

    func run(_ job: TableStructuringJob, pack: CasePack) throws -> TableStructuringResult {
        var next = job
        let inferred = Self.inferSchema(from: job)
        let sheet = XLSXSheet(
            name: inferred.sheetName,
            headers: inferred.columns.map(\.name),
            rows: [["（待从原件回填）"] + Array(repeating: "", count: max(0, inferred.columns.count - 1))]
        )
        let filename = job.suggestedFilename.hasSuffix(".xlsx")
            ? job.suggestedFilename
            : job.suggestedFilename + ".xlsx"
        let dest = store.tableURL(pack, filename: filename)
        try XLSXWorkbookWriter.write(sheets: [sheet], to: dest)

        next.status = .awaitingHeaderLock
        next.outputRelativePath = "\(CasePackLayout.structuredTables)/\(filename)"
        next.schema = inferred
        next.locked = false
        next.message = "已写出真表 \(filename)。表头可改后再锁定。禁止把碎行文本当作最终表。"
        return TableStructuringResult(job: next, workbookURL: dest, schema: inferred)
    }

    func lock(_ result: TableStructuringResult, columns: [TableColumn]? = nil) -> TableStructuringResult {
        var job = result.job
        var schema = result.schema
        if let columns {
            schema.columns = columns
        }
        job.schema = schema
        job.locked = true
        job.status = .locked
        job.message = "表头已锁定，可供文书工序使用。"
        return TableStructuringResult(job: job, workbookURL: result.workbookURL, schema: schema)
    }

    private static func inferSchema(from job: TableStructuringJob) -> TableSchema {
        let name = job.suggestedFilename
        if name.contains("工资") {
            return TableSchema(
                sheetName: "工资流水",
                columns: [
                    TableColumn(name: "发放月份", typeHint: "month"),
                    TableColumn(name: "应发", typeHint: "number"),
                    TableColumn(name: "实发", typeHint: "number"),
                    TableColumn(name: "备注", typeHint: "string")
                ]
            )
        }
        if name.contains("付款") || name.contains("流水") {
            return TableSchema(
                sheetName: "款项",
                columns: [
                    TableColumn(name: "日期", typeHint: "date"),
                    TableColumn(name: "摘要", typeHint: "string"),
                    TableColumn(name: "金额", typeHint: "number")
                ]
            )
        }
        return TableSchema(
            sheetName: "表1",
            columns: [
                TableColumn(name: "列A", typeHint: "string"),
                TableColumn(name: "列B", typeHint: "string")
            ]
        )
    }
}
