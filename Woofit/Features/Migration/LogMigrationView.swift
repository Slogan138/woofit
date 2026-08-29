import SwiftUI
import SwiftData
import UIKit
import WoofitCore

/// P9 · 과거 운동일지 가져오기(F-13). 붙여넣기 → 미리보기 → 적용.
///
/// 일회성 기능이라 설정(P7) 안에서만 진입한다 — 평소 눈에 띄지 않아야 한다.
/// 파싱은 `LegacyLogParser.parse` 순수 함수가 맡고, 이 화면은 결과를 보여주고
/// 사용자가 확인한 뒤 `LegacyLogImporter.apply` 로 SwiftData 에 반영한다.
struct LogMigrationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var result = LegacyLogParseResult(sessions: [], issues: [])
    @State private var isConfirmingApply = false
    @State private var summary: LegacyLogImporter.Summary?

    private var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("마크다운 붙여넣기") {
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                Button {
                    text = UIPasteboard.general.string ?? text
                } label: {
                    Label("클립보드에서 붙여넣기", systemImage: "doc.on.clipboard")
                }
            }

            if hasContent {
                previewSection
                if !result.issues.isEmpty {
                    issuesSection
                }
            }
        }
        .navigationTitle("과거 운동일지 가져오기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("적용") { isConfirmingApply = true }
                    .disabled(result.sessions.isEmpty)
            }
        }
        .onChange(of: text) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            result = trimmed.isEmpty
                ? LegacyLogParseResult(sessions: [], issues: [])
                : LegacyLogParser.parse(newValue)
        }
        .confirmationDialog(
            "\(result.sessions.count)개 세션을 한 번에 반영합니다. 되돌리려면 기록 목록에서 하나씩 지워야 합니다.",
            isPresented: $isConfirmingApply,
            titleVisibility: .visible
        ) {
            Button("적용", action: apply)
            Button("취소", role: .cancel) {}
        }
        .alert(
            "가져오기 완료",
            isPresented: Binding(get: { summary != nil }, set: { if !$0 { summary = nil } })
        ) {
            Button("확인") { dismiss() }
        } message: {
            if let summary {
                Text(summaryMessage(summary))
            }
        }
    }

    // MARK: - 미리보기

    private var previewSection: some View {
        Section("미리보기 (\(result.sessions.count)개 세션)") {
            ForEach(Array(result.sessions.enumerated()), id: \.offset) { _, session in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.date, format: .dateTime.year().month().day())
                        Text(session.category)
                            .font(Typography.secondary)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(session.entries.count)종목")
                        .font(Typography.secondary)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var issuesSection: some View {
        Section("건너뛴 줄 (\(result.issues.count))") {
            ForEach(Array(result.issues.enumerated()), id: \.offset) { _, issue in
                VStack(alignment: .leading, spacing: 2) {
                    Text(issue.line.isEmpty ? "(빈 줄)" : issue.line)
                        .font(.system(.caption, design: .monospaced))
                    Text(issue.reason)
                        .font(Typography.secondary)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - 적용

    private func apply() {
        summary = try? LegacyLogImporter.apply(result.sessions, in: modelContext)
    }

    private func summaryMessage(_ summary: LegacyLogImporter.Summary) -> String {
        summary.skippedDates.isEmpty
            ? "\(summary.addedSessionCount)개 세션을 새로 가져왔습니다."
            : "\(summary.addedSessionCount)개 세션을 새로 가져왔습니다. 이미 있는 날짜 \(summary.skippedDates.count)개는 건너뛰었습니다."
    }
}

#Preview {
    NavigationStack {
        LogMigrationView()
    }
    .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
