import CompanionKit
import CoreLocation
import HubCore
import SwiftUI

/// App settings: the bedtime reminder time and the places that switch mode.
struct SettingsView: View {
    @Binding var bedtime: BedtimeSchedule
    @Binding var places: PlaceSettings
    let monitor: PlaceMonitor
    @Environment(\.dismiss) private var dismiss
    @State private var placeError: String?
    @State private var locating: HubPlace.Kind?

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

            VStack(alignment: .leading, spacing: 10) {
                Text("地点")
                    .font(Toy.body(16, weight: .heavy))
                ForEach(HubPlace.Kind.allCases, id: \.self) { kind in
                    placeRow(kind)
                }
                Text("到拳馆直接切到拳击日，到公司切到上班，到家用来看你是不是窝在家。地点只存在这台 iPhone 上。定位权限选「始终」，App 关着时也能切。")
                    .font(Toy.body(12))
                    .foregroundStyle(Toy.muted)
                if let placeError {
                    Text(placeError)
                        .font(Toy.body(12))
                        .foregroundStyle(Toy.alert)
                }
            }
            .padding(16)
            .toyCard()

            Spacer()
        }
        .foregroundStyle(Toy.ink)
        .padding(20)
        .background(Toy.paper.ignoresSafeArea())
    }

    private func placeRow(_ kind: HubPlace.Kind) -> some View {
        HStack(spacing: 10) {
            Text(kind.title)
                .font(Toy.body(15, weight: .bold))
            Text(places[kind] == nil ? "没设" : "已设")
                .font(Toy.body(12))
                .foregroundStyle(Toy.muted)
            Spacer()
            if places[kind] != nil {
                Button("清除") { places[kind] = nil }
                    .font(Toy.body(13, weight: .heavy))
            }
            Button(locating == kind ? "定位中…" : "设为当前位置") {
                Task { await setHere(kind) }
            }
            .font(Toy.body(13, weight: .heavy))
            .disabled(locating != nil)
        }
    }

    private func setHere(_ kind: HubPlace.Kind) async {
        locating = kind
        defer { locating = nil }
        do {
            let location = try await monitor.currentLocation()
            let coordinate = location.coordinate
            places[kind] = HubPlace(kind: kind, latitude: coordinate.latitude, longitude: coordinate.longitude)
            placeError = nil
            monitor.requestAlways()
        } catch {
            placeError = "拿不到当前位置：\(error.localizedDescription)"
        }
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
