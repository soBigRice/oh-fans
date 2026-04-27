import SwiftUI
import WidgetKit

private enum iFansWidgetConstants {
    static let appGroupIdentifier = "group.com.sobigrice.ohFans"
    static let snapshotKey = "widget.snapshot.v1"
    static let widgetKind = "iFansStatusWidget"
}

private struct WidgetSnapshotPayload: Codable {
    let modeTitle: String
    let statusText: String
    let hottestTemperature: Double?
    let fanSummary: String
    let updatedAt: Date
}

private struct iFansWidgetEntry: TimelineEntry {
    let date: Date
    let payload: WidgetSnapshotPayload
}

private struct Provider: TimelineProvider {
    private var fallbackPayload: WidgetSnapshotPayload {
        WidgetSnapshotPayload(
            modeTitle: "系统自动",
            statusText: "打开 oh fans 后会显示实时数据",
            hottestTemperature: 56,
            fanSummary: "2 个风扇在线",
            updatedAt: .now
        )
    }

    func placeholder(in context: Context) -> iFansWidgetEntry {
        iFansWidgetEntry(date: .now, payload: fallbackPayload)
    }

    func getSnapshot(in context: Context, completion: @escaping (iFansWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<iFansWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let refresh = Calendar.current.date(byAdding: .minute, value: 1, to: .now) ?? .now.addingTimeInterval(60)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func makeEntry() -> iFansWidgetEntry {
        iFansWidgetEntry(date: .now, payload: readPayload())
    }

    private func readPayload() -> WidgetSnapshotPayload {
        let defaults = UserDefaults(suiteName: iFansWidgetConstants.appGroupIdentifier) ?? .standard
        guard let data = defaults.data(forKey: iFansWidgetConstants.snapshotKey) else {
            return fallbackPayload
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(WidgetSnapshotPayload.self, from: data)) ?? fallbackPayload
    }
}

private struct iFansStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: iFansWidgetEntry

    var body: some View {
        ZStack {
            background

            if family == .systemMedium {
                mediumLayout
            } else {
                smallLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.15, blue: 0.22),
                    Color(red: 0.16, green: 0.20, blue: 0.29)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            header


            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(temperatureText)
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("°C")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
            }

            Text(entry.payload.modeTitle)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)

            Spacer(minLength: 0)

            footer
        }
        .padding(8)
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            HStack(alignment: .bottom, spacing: 18) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(temperatureText)
                        .font(.system(size: 62, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("°C")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.82))
                }

                VStack(alignment: .leading, spacing: 6) {
                    metricRow(title: "模式", value: entry.payload.modeTitle)
                    metricRow(title: "风扇", value: entry.payload.fanSummary)
                }
                .padding(.leading, 16)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.14))
                        .frame(width: 1.5)
                }
            }

            Text(entry.payload.statusText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)

            footer
        }
        .padding(9)
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
        }
    }

    private var header: some View {
        HStack {
            if family == .systemSmall {
                Image(systemName: "fanblades.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                Label("OH FANS", systemImage: "fanblades.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer(minLength: 8)

            Text(modeBadge)
                .font(.caption2.weight(.bold))
                .foregroundStyle(modeTint)
                .frame(width: family == .systemSmall ? 52 : 56)
                .padding(.vertical, 4)
                .background(.white.opacity(0.12), in: Capsule())
                .overlay {
                    Capsule().stroke(.white.opacity(0.16), lineWidth: 1)
                }
        }
    }

    private var footer: some View {
        HStack {
            Text(entry.payload.updatedAt, style: .time)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
                .monospacedDigit()

            if family != .systemSmall {
                Spacer(minLength: 6)

                Text(entry.payload.modeTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                modeTint.opacity(0.12),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var temperatureText: String {
        guard let hottestTemperature = entry.payload.hottestTemperature else {
            return "--"
        }
        return String(Int(hottestTemperature.rounded()))
    }

    private var modeBadge: String {
        let mode = entry.payload.modeTitle
        if mode.contains("性能") { return "PERF" }
        if mode.contains("均衡") { return "BAL" }
        if mode.contains("安静") { return "QUIET" }
        return "AUTO"
    }

    private var modeTint: Color {
        let mode = entry.payload.modeTitle
        if mode.contains("性能") {
            return Color(red: 0.98, green: 0.43, blue: 0.31)
        }
        if mode.contains("均衡") {
            return Color(red: 0.98, green: 0.78, blue: 0.33)
        }
        if mode.contains("安静") {
            return Color(red: 0.48, green: 0.79, blue: 0.98)
        }
        return Color(red: 0.49, green: 0.89, blue: 0.70)
    }
}

struct i_Fans_Widgets: Widget {
    let kind = iFansWidgetConstants.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            iFansStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("oh fans 温度")
        .description("在桌面上查看最高温度和当前风扇模式。")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    i_Fans_Widgets()
} timeline: {
    iFansWidgetEntry(
        date: .now,
        payload: WidgetSnapshotPayload(
            modeTitle: "均衡",
            statusText: "已验证风扇控制通道",
            hottestTemperature: 63,
            fanSummary: "2 个风扇在线",
            updatedAt: .now
        )
    )
}
