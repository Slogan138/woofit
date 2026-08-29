import SwiftUI
import WoofitCore

/// 반복 요일 다중 선택. 배타 배정(A1)은 저장 시점에 `RoutineScheduler.assign` 이 처리한다.
struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases) { weekday in
                let isSelected = selection.contains(weekday)
                Button {
                    if isSelected {
                        selection.remove(weekday)
                    } else {
                        selection.insert(weekday)
                    }
                } label: {
                    Text(weekday.shortName)
                        .font(Typography.itemName)
                        .frame(width: 32, height: 32)
                        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    @Previewable @State var selection: Set<Weekday> = [.monday, .thursday]
    return WeekdayPicker(selection: $selection)
        .padding()
}
