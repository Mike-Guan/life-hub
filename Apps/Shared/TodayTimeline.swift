import CompanionKit
import HubCore
import SwiftUI

/// Today's mode log: when each mode started and how long it lasted.
struct TodayTimeline: View {
    let segments: [ModeSegment]
    var persona = Persona.haku

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TODAY")
                .font(Toy.display(15))
                .foregroundStyle(Toy.ink)

            if segments.isEmpty {
                Text("今天还没切过 mode。")
                    .font(Toy.body(14))
                    .foregroundStyle(Toy.muted)
            } else {
                ForEach(segments.reversed()) { segment in
                    Row(segment: segment, persona: persona)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .toyCard()
    }

    private struct Row: View {
        let segment: ModeSegment
        let persona: Persona

        var body: some View {
            HStack(spacing: 12) {
                Text(segment.start, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                    .font(Toy.body(13, weight: .bold).monospacedDigit())
                    .foregroundStyle(Toy.muted)
                    .frame(width: 48, alignment: .leading)

                RoundedRectangle(cornerRadius: 4)
                    .fill(segment.mode.color)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Toy.ink, lineWidth: 2))
                    .frame(width: 16, height: 16)

                Text(segment.mode.title(for: persona))
                    .font(Toy.body(15, weight: .heavy))
                    .foregroundStyle(Toy.ink)

                if !segment.source.isManual {
                    // Evidence level: anything not switched by hand is labelled.
                    Text("自动")
                        .font(Toy.body(10, weight: .heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(Capsule().stroke(Toy.ink, lineWidth: 1.5))
                        .foregroundStyle(Toy.ink)
                }

                Spacer()

                Text(durationText)
                    .font(Toy.body(13, weight: .bold).monospacedDigit())
                    .foregroundStyle(segment.isOngoing ? Toy.ink : Toy.muted)
            }
        }

        private var durationText: String {
            let minutes = Int(segment.duration / 60)
            let text = minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
            return segment.isOngoing ? "\(text) · 进行中" : text
        }
    }
}
