import Testing
import SwiftData
@testable import WoofitCore

// MARK: - 나누기·합치기 (F-1, D11)

@Test("여러 부위는 슬래시로 나뉜다")
func categorySplitsOnSlash() {
    #expect(CategoryLabel.parts(of: "가슴 / 어깨 / 삼두") == ["가슴", "어깨", "삼두"])
}

@Test("구분자 좌우에 공백이 없어도 나뉜다")
func categorySplitsWithoutSpaces() {
    // 손으로 고칠 때 공백을 빠뜨리기 쉽다. 관대하게 읽는다(F-7 과 같은 방침).
    #expect(CategoryLabel.parts(of: "가슴/어깨") == ["가슴", "어깨"])
}

@Test("빈 조각은 버려진다")
func categoryDropsEmptyParts() {
    // `가슴 / ` 는 손으로 고치는 중에 흔히 나오는 값이다. 그대로 두면 빈 칩이 켜진다.
    #expect(CategoryLabel.parts(of: "가슴 /  / 어깨") == ["가슴", "어깨"])
    #expect(CategoryLabel.parts(of: "가슴 / ") == ["가슴"])
    #expect(CategoryLabel.parts(of: "") == [])
}

@Test("부위 하나짜리 카테고리는 그대로다")
func categoryWithSinglePart() {
    #expect(CategoryLabel.parts(of: "하체") == ["하체"])
    #expect(CategoryLabel.joined(["하체"]) == "하체")
}

// MARK: - 토글

@Test("없는 부위를 토글하면 뒤에 붙는다")
func togglingAppendsToEnd() {
    #expect(CategoryLabel.toggling("삼두", in: "가슴 / 어깨") == "가슴 / 어깨 / 삼두")
}

@Test("있는 부위를 토글하면 빠진다")
func togglingRemovesExisting() {
    #expect(CategoryLabel.toggling("어깨", in: "가슴 / 어깨 / 삼두") == "가슴 / 삼두")
}

@Test("가운데 부위를 빼도 나머지 순서가 유지된다")
func togglingPreservesOrder() {
    // `가슴 / 어깨 / 삼두` 와 `삼두 / 가슴` 은 사용자에게 다른 이름이고
    // 마크다운으로 나가 노트에 그대로 남는다.
    let once = CategoryLabel.toggling("어깨", in: "가슴 / 어깨 / 삼두")
    #expect(CategoryLabel.toggling("어깨", in: once) == "가슴 / 삼두 / 어깨")
}

@Test("빈 카테고리에 토글하면 그 부위만 남는다")
func togglingIntoEmpty() {
    #expect(CategoryLabel.toggling("가슴", in: "") == "가슴")
}

@Test("전부 빼면 빈 문자열이 된다")
func togglingEverythingOff() {
    let label = CategoryLabel.toggling("하체", in: "하체")
    #expect(label.isEmpty)
}

@Test("포함 여부는 조각 단위로 판단한다")
func containsChecksWholePart() {
    #expect(CategoryLabel.contains("가슴 / 어깨", "어깨"))
    // 부분 문자열이 아니라 조각이 같아야 한다 — 안 그러면 `삼두` 가 `이두` 를 켠다.
    #expect(CategoryLabel.contains("가슴 / 삼두", "이두") == false)
}

// MARK: - 제안

@MainActor
@Test("제안은 여러 부위를 한 칸씩 쪼개서 센다")
func suggesterCountsEachPart() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    context.insert(Routine(name: "화", category: "가슴 / 어깨 / 삼두"))
    context.insert(Routine(name: "목", category: "등 / 이두"))
    context.insert(Routine(name: "수", category: "하체"))

    let suggestions = try CategorySuggester.suggest(in: context)
    #expect(Set(suggestions) == ["가슴", "어깨", "삼두", "등", "이두", "하체"])
}

@MainActor
@Test("제안은 자주 쓴 부위가 먼저 온다")
func suggesterSortsByFrequency() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    context.insert(Routine(name: "화", category: "가슴 / 어깨"))
    context.insert(Routine(name: "금", category: "가슴"))
    context.insert(Routine(name: "수", category: "하체"))

    let suggestions = try CategorySuggester.suggest(in: context)
    #expect(suggestions.first == "가슴")
}

@MainActor
@Test("기록이 없으면 제안이 비어 있다")
func suggesterEmptyWithoutHistory() throws {
    // 화면은 이때만 기본 목록으로 넘어간다(계획 19).
    let container = try WoofitModelContainer.makeInMemoryContainer()
    #expect(try CategorySuggester.suggest(in: container.mainContext).isEmpty)
}
