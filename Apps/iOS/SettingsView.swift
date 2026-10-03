import CompanionKit
import HubCore
import SwiftUI

/// App settings. For now: the bedtime reminder time.
struct SettingsView: View {
    @Binding var bedtime: BedtimeSchedule
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("设置")
                    .font(Toy.display(24))
                Spacer()
                Button("好了") { dismiss() }
                    .font(Toy.body(15, weight: .heavy))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("睡觉提醒")
                    .font(Toy.body(16, weight: .heavy))
                DatePicker("每天", selection: reminderTime, displayedComponents: .hourAndMinute)
                    .font(Toy.body(15))
                Text("到点发一条通知，RUNNER 变困，一直到早上 5 点。只提醒一次。")
                    .font(Toy.body(12))
                    .foregroundStyle(Toy.muted)
            }
            .padding(16)
            .toyCard()

            Spacer()
        }
        .foregroundStyle(Toy.ink)
        .padding(20)
        .background(Toy.paper.ignoresSafeArea())
    }

    // The picker edits a Date; only its hour and minute are kept.
    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(from: bedtime.startComponents) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            bedtime.startMinute = (parts.hour ?? 23) * 60 + (parts.minute ?? 30)
        }
    }
}
