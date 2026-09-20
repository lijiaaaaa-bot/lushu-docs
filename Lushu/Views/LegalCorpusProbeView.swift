import SwiftUI

/// Canvas 探测：从语料文件查找 刑法/第一条 与 总则/第一条，失败则显示错误，不编造。
struct LegalCorpusProbeView: View {
    private let criminal: Result<LegalChunk, Error>
    private let civilGeneral: Result<LegalChunk, Error>

    init(corpus: LegalCorpus = LegalCorpus.loadPreferred()) {
        criminal = Result { try corpus.lookup(lawID: "刑法", articleNum: "第一条") }
        civilGeneral = Result { try corpus.lookup(lawID: "总则", articleNum: "1") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("语料探测")
                .font(Theme.brandTitle(28))
                .foregroundStyle(Theme.ink)
            probeBlock(title: "刑法 / 第一条", result: criminal)
            probeBlock(title: "民法典总则 / 第一条", result: civilGeneral)
        }
        .padding(Theme.pagePad)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.paper)
    }

    @ViewBuilder
    private func probeBlock(title: String, result: Result<LegalChunk, Error>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.screenTitle(16))
                .foregroundStyle(Theme.walnut)
            switch result {
            case .success(let chunk):
                Text(chunk.text)
                    .font(Theme.serifBody(14))
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
            case .failure(let error):
                Text(error.localizedDescription)
                    .font(Theme.serifBody(14))
                    .foregroundStyle(Theme.mute)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard()
    }
}

#Preview("语料探测") {
    LegalCorpusProbeView()
        .frame(width: 640, height: 420)
}
