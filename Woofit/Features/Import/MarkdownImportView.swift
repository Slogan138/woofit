import SwiftUI
import SwiftData
import UIKit
import WoofitCore

/// 붙여넣기 → 미리보기 → 적용(F-7). 새 루틴 생성 또는 기존 루틴 덮어쓰기를 고른다.
///
/// 파싱은 `RoutineMarkdownImporter.parse` 순수 함수가 맡고, 이 화면은 결과를 보여주고
/// 사용자가 확인한 뒤 `ParsedRoutine.makeRoutine()` / `apply(to:)` 로 SwiftData 에 반영한다.
struct MarkdownImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Routine.updatedAt, order: .reverse) private var existingRoutines: [Routine]

    private enum Target: Hashable {
        case create
        case overwrite(UUID)
    }

    @State private var text = ""
    @State private var parseResult = ParseResult(
        routine: ParsedRoutine(title: "", category: "", weekdayMask: 0, exercises: []),
        issues: []
    )
    @State private var target: Target = .create
    @State private var isConfirmingOverwrite = false

    private var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("마크다운 붙여넣기") {
                    TextEditor(text: $text)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 160)
                    Button {
                        text = UIPasteboard.general.string ?? text
                    } label: {
                        Label("클립보드에서 붙여넣기", systemImage: "doc.on.clipboard")
                    }
                }

                if hasContent {
                    previewSection
                    if !parseResult.issues.isEmpty {
                        issuesSection
                    }
                    if !parseResult.routine.exercises.isEmpty {
                        targetSection
                    }
                }
            }
            .navigationTitle("가져오기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("적용", action: apply)
                        .disabled(parseResult.routine.exercises.isEmpty)
                }
            }
            .onChange(of: text) { _, newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                parseResult = trimmed.isEmpty
                    ? ParseResult(routine: ParsedRoutine(title: "", category: "", weekdayMask: 0, exercises: []), issues: [])
                    : RoutineMarkdownImporter.parse(newValue)
            }
            .confirmationDialog(
                "기존 루틴의 종목·세트를 전부 바꿉니다. 되돌릴 수 없습니다.",
                isPresented: $isConfirmingOverwrite,
                titleVisibility: .visible
            ) {
                Button("덮어쓰기", role: .destructive, action: performApply)
                Button("취소", role: .cancel) {}
            }
        }
    }

    // MARK: - 미리보기

    private var previewSection: some View {
        Section("미리보기") {
            TextField("루틴 이름", text: $parseResult.routine.title)
            TextField("부위 (비어 있으면 지정하세요)", text: $parseResult.routine.category)
            ForEach(Array(parseResult.routine.exercises.enumerated()), id: \.offset) { _, exercise in
                HStack {
                    Text(exercise.name)
                    Spacer()
                    Text(summary(for: exercise))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
    }

    private func summary(for exercise: ParsedExercise) -> String {
        guard let first = exercise.sets.first else { return "0세트" }
        return "\(exercise.sets.count)세트 · \(WeightFormatter.target(weight: first.targetWeight, reps: first.targetReps))"
    }

    private var issuesSection: some View {
        Section("건너뛴 줄 (\(parseResult.issues.count))") {
            ForEach(Array(parseResult.issues.enumerated()), id: \.offset) { _, issue in
                VStack(alignment: .leading, spacing: 2) {
                    Text(issue.line.isEmpty ? "(빈 줄)" : issue.line)
                        .font(.system(.caption, design: .monospaced))
                    Text(issue.reason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - 적용 대상

    private var targetSection: some View {
        Section("적용 대상") {
            Picker("적용 대상", selection: $target) {
                Text("새 루틴 생성").tag(Target.create)
                ForEach(existingRoutines) { routine in
                    Text("덮어쓰기 · \(routine.resolvedTitle)").tag(Target.overwrite(routine.id))
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }

    private func apply() {
        switch target {
        case .create:
            performApply()
        case .overwrite:
            isConfirmingOverwrite = true
        }
    }

    private func performApply() {
        switch target {
        case .create:
            modelContext.insert(parseResult.routine.makeRoutine())
        case .overwrite(let id):
            guard let existing = existingRoutines.first(where: { $0.id == id }) else { return }
            parseResult.routine.apply(to: existing)
        }
        dismiss()
    }
}

#Preview {
    MarkdownImportView()
        .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
