import CompanionKit
import CoreLocation
import FamilyControls
import HubCore
import SwiftUI

/// App settings: the bedtime reminder time, the places that switch mode and the Screen Time watch.
struct SettingsView: View {
    @Binding var bedtime: BedtimeSchedule
    @Binding var places: PlaceSettings
    let monitor: PlaceMonitor
    @Environment(\.dismiss) private var dismiss
    @State private var placeError: String?
    @State private var locating: HubPlace.Kind?
    @State private var scrollApps = ScrollWatch.selection
    @State private var pickingApps = false
    @State private var screenTimeError: String?

    var body: some View {
        ScrollView {
            content
        }
        .foregroundStyle(Toy.ink)
        .background(Toy.paper.ignoresSafeArea())
    }

    private var content: some View {
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
                Text("到拳馆直接切到拳击日，到公司切到上班。地点只存在这台 iPhone 上。定位权限选「始终」，App 关着时也能切。")
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

            // Debug only until Apple approves Family Controls for distribution; STG and PROD have no
            // entitlement, so the button could only fail. Remove with the CI-CD.md Screen Time step.
            #if DEBUG
            scrollCard
            #endif
        }
        .padding(20)
    }

    private var scrollCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("刷手机")
                    .font(Toy.body(16, weight: .heavy))
                Text(pickedLabel)
                    .font(Toy.body(12))
                    .foregroundStyle(Toy.muted)
                Spacer()
                Button("选 App") {
                    Task { await pickApps() }
                }
                .font(Toy.body(13, weight: .heavy))
            }
            Text("选 B 站和小红书。一天合计刷满 \(ScrollWatch.minutes) 分钟，RUNNER 也瘫在沙发上。App 只知道到没到，看不到你用了多久。")
                .font(Toy.body(12))
                .foregroundStyle(Toy.muted)
            if let screenTimeError {
                Text(screenTimeError)
                    .font(Toy.body(12))
                    .foregroundStyle(Toy.alert)
            }
        }
        .padding(16)
        .toyCard()
        .familyActivityPicker(isPresented: $pickingApps, selection: $scrollApps)
        .onChange(of: scrollApps) { watchScrolling() }
    }

    private var pickedLabel: String {
        let apps = scrollApps.applicationTokens.count + scrollApps.categoryTokens.count
        let count = apps + scrollApps.webDomainTokens.count
        return count == 0 ? "没选" : "已选 \(count) 项"
    }

    // Screen Time asks once; after that the picker opens straight away.
    private func pickApps() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            screenTimeError = nil
            pickingApps = true
        } catch {
            screenTimeError = "Screen Time 没打开：\(error.localizedDescription)"
        }
    }

    private func watchScrolling() {
        ScrollWatch.selection = scrollApps
        do {
            try ScrollWatch.start(scrollApps)
            screenTimeError = nil
        } catch {
            screenTimeError = "Screen Time 监测没启动：\(error.localizedDescription)"
        }
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
