import CompanionKit
import CoreLocation
import HubCore
import SwiftUI

// No map: showing or searching a map would send the location to Apple's servers, and location
// never goes to a network API (CLAUDE.md, Privacy). Mike stands at the place and taps once.
/// Sets one place: its name and action for added places, its location and its radius.
struct PlaceEditor: View {
    let monitor: PlaceMonitor
    let persona: Persona
    let cards: ModeCards
    let onSave: (HubPlace) -> Void
    let onDelete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var place: HubPlace
    @State private var hasLocation: Bool
    @State private var locating = false
    @State private var failure: LocationFailure?

    /// - Parameters:
    ///   - place: the place to edit, or a new one with `hasLocation` false.
    ///   - persona: the character whose names the editor uses.
    ///   - cards: the user's cards, for the action names.
    ///   - onDelete: removes the place; `nil` hides the button.
    init(
        place: HubPlace,
        hasLocation: Bool,
        monitor: PlaceMonitor,
        persona: Persona,
        cards: ModeCards,
        onSave: @escaping (HubPlace) -> Void,
        onDelete: (() -> Void)?
    ) {
        self.monitor = monitor
        self.persona = persona
        self.cards = cards
        self.onSave = onSave
        self.onDelete = onDelete
        _place = State(initialValue: place)
        _hasLocation = State(initialValue: hasLocation)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(place.kind == .custom ? "地点" : place.title)
                        .font(Toy.display(24))
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Text("取消").tapTarget()
                    }
                    .font(Toy.body(15, weight: .heavy))
                }
                if place.kind == .custom {
                    nameCard
                }
                locationCard
                actionCard
                if let failure {
                    failureLine(failure)
                }
                Button {
                    onSave(place)
                    dismiss()
                } label: {
                    Text("保存")
                        .font(Toy.body(17, weight: .heavy))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(ToyButtonStyle(fill: Toy.pink, isSelected: canSave))
                .disabled(!canSave)
                if let onDelete {
                    Button(place.kind == .custom ? "删除这个地点" : "清除") {
                        onDelete()
                        dismiss()
                    }
                    .font(Toy.body(14, weight: .heavy))
                    .foregroundStyle(Toy.alert)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
        .foregroundStyle(Toy.ink)
        .background(Toy.paper.ignoresSafeArea())
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("名字")
                .font(Toy.body(16, weight: .heavy))
            TextField("比如：公园、工作室", text: name)
                .font(Toy.body(17, weight: .bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .toyCard(fill: Toy.paper, radius: 12, shadow: 3)
        }
        .padding(16)
        .toyCard()
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("位置")
                    .font(Toy.body(16, weight: .heavy))
                Text(hasLocation ? "已设" : "没设")
                    .font(Toy.body(12))
                    .foregroundStyle(Toy.muted)
                Spacer()
                Button {
                    Task { await setHere() }
                } label: {
                    (locating ? Text("定位中…") : Text("设为当前位置")).tapTarget()
                }
                .font(Toy.body(13, weight: .heavy))
                .disabled(locating)
            }
            Stepper(value: $place.radius, in: 50...500, step: 50) {
                Text("范围 \(Int(place.radius)) 米")
                    .font(Toy.body(15))
            }
            Text("人站在这个地点时点「设为当前位置」。范围是进出算到达和离开的距离。只存在这台 iPhone 上。")
                .font(Toy.body(12))
                .foregroundStyle(Toy.muted)
        }
        .padding(16)
        .toyCard()
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("到这里时")
                .font(Toy.body(16, weight: .heavy))
            if place.kind == .custom {
                Picker("到这里时", selection: $place.action) {
                    ForEach(HubPlace.Action.offered(with: cards), id: \.self) { action in
                        Text(action.title(for: persona, cards: cards)).tag(action)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } else {
                Text(place.kind.summary(for: persona, cards: cards))
                    .font(Toy.body(15))
            }
        }
        .padding(16)
        .toyCard()
    }

    private var name: Binding<String> {
        Binding {
            place.name ?? ""
        } set: { text in
            place.name = text
        }
    }

    private var canSave: Bool {
        let named = place.kind != .custom || !(place.name ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        return hasLocation && named && !locating
    }

    private func setHere() async {
        locating = true
        defer { locating = false }
        do {
            let coordinate = try await monitor.currentLocation().coordinate
            place.latitude = coordinate.latitude
            place.longitude = coordinate.longitude
            hasLocation = true
            failure = nil
            monitor.requestAlways()
        } catch {
            failure = LocationFailure(error)
        }
    }

    // Preview 5: each failure line is followed by the one step that can fix it.
    private func failureLine(_ failure: LocationFailure) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ErrorLine(text: failure.message, size: 13)
            Button {
                if failure.opensSettings {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } else {
                    Task { await setHere() }
                }
            } label: {
                Text(failure.opensSettings ? "去设置打开" : "再点一次")
                    .font(Toy.body(15, weight: .heavy))
                    .underline()
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(locating)
        }
    }
}

extension HubPlace.Kind {
    /// What arriving at the preset does, for Settings.
    func summary(for persona: Persona, cards: ModeCards) -> String {
        switch self {
        case .gym: "直接切到\(cards.title(for: .boxing, persona: persona))。"
        case .office: "切到\(cards.title(for: .work, persona: persona))。"
        case .home: "不切换，用来看你是不是窝在家。"
        case .fitness: "\(persona.title) 陪你举铁，待满 30 分钟算一次健身，得 \(Win.gym.cans) 个能量罐。"
        case .custom: action.title(for: persona, cards: cards)
        }
    }
}
