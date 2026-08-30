import Foundation

/// 종목명 정규화. 직전 기록 조회(F-9)의 매칭 키를 만든다.
///
/// 종목명이 자유 입력이라 표기 차이로 히스토리가 갈라지면 F-9 가 조용히 망가진다.
/// 직전 기록이 오류가 아니라 "첫 수행"처럼 빈 칸으로 보이기 때문에 눈치채기도 어렵다.
/// 그래서 **공백을 전부 제거**한다. 축약이 아니라 제거여야
/// "벤치프레스" 와 "벤치 프레스" 가 같은 종목으로 묶인다.
public enum ExerciseName {

    public static func normalize(_ raw: String) -> String {
        raw.unicodeScalars
            .filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
            .reduce(into: "") { $0.unicodeScalars.append($1) }
            .lowercased()
    }

    /// 보조 기구 종목 표시. 가져오기(F-13)가 `65kg 보조` 를 만나면 이름에 이걸 붙인다.
    ///
    /// 보조 중량은 **줄수록** 향상이라 무게·볼륨의 해석 방향이 뒤집힌다.
    /// 표시가 이름 안에 있어야 추이(F-10)가 그 종목을 알아보고 그리지 않을 수 있다.
    public static let assistedMarker = "(보조)"

    public static func isAssisted(_ name: String) -> Bool {
        name.contains(assistedMarker)
    }

    /// 표시용 정리. 앞뒤 공백만 털어낸다. 사용자가 적은 표기를 그대로 존중한다.
    public static func display(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
