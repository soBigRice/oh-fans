import AppKit
import SwiftUI

enum CompactGlassPanelDensity: Equatable {
    case window
    case menuBar

    var panelAccessibilityIdentifier: String {
        switch self {
        case .window:
            "panel.compact.window"
        case .menuBar:
            "panel.compact.menu"
        }
    }

    var shellWidth: CGFloat {
        switch self {
        case .window:
            332
        case .menuBar:
            296
        }
    }

    var shellCornerRadius: CGFloat {
        switch self {
        case .window:
            22
        case .menuBar:
            20
        }
    }

    var chromeInsets: EdgeInsets {
        EdgeInsets()
    }

    var contentInsets: EdgeInsets {
        switch self {
        case .window:
            EdgeInsets(top: 12, leading: 16, bottom: 14, trailing: 16)
        case .menuBar:
            EdgeInsets(top: 10, leading: 12, bottom: 12, trailing: 12)
        }
    }

    var sectionSpacing: CGFloat {
        switch self {
        case .window:
            10
        case .menuBar:
            8
        }
    }

    var sectionCornerRadius: CGFloat {
        switch self {
        case .window:
            22
        case .menuBar:
            20
        }
    }

    var badgeCornerRadius: CGFloat {
        switch self {
        case .window:
            20
        case .menuBar:
            18
        }
    }

    var modeBarHeight: CGFloat {
        switch self {
        case .window:
            54
        case .menuBar:
            48
        }
    }

    var segmentCornerRadius: CGFloat {
        switch self {
        case .window:
            16
        case .menuBar:
            14
        }
    }

    var segmentHeight: CGFloat {
        switch self {
        case .window:
            42
        case .menuBar:
            38
        }
    }

    var temperatureValueFont: Font {
        switch self {
        case .window:
            .system(size: 24, weight: .bold, design: .rounded)
        case .menuBar:
            .system(size: 22, weight: .bold, design: .rounded)
        }
    }

    var modeSymbolFont: Font {
        switch self {
        case .window:
            .system(size: 11.5, weight: .semibold)
        case .menuBar:
            .system(size: 10.5, weight: .semibold)
        }
    }

    var modeTitleFont: Font {
        switch self {
        case .window:
            .system(size: 9.5, weight: .semibold, design: .rounded)
        case .menuBar:
            .system(size: 9, weight: .semibold, design: .rounded)
        }
    }

    var showsMonitoringSection: Bool {
        self == .window
    }

    var headerDetailLineLimit: Int {
        switch self {
        case .window:
            2
        case .menuBar:
            1
        }
    }

    var footerLineLimit: Int {
        switch self {
        case .window:
            2
        case .menuBar:
            1
        }
    }

    var primaryButtonControlSize: ControlSize {
        switch self {
        case .window:
            .regular
        case .menuBar:
            .small
        }
    }

    var titlebarClearance: CGFloat {
        switch self {
        case .window:
            18
        case .menuBar:
            0
        }
    }

    var titlebarDragRegionHeight: CGFloat {
        switch self {
        case .window:
            34
        case .menuBar:
            0
        }
    }

    var trafficLightsClearance: CGFloat {
        switch self {
        case .window:
            74
        case .menuBar:
            0
        }
    }
}

struct CompactPanelAction {
    let title: String
    let systemImage: String
    var accessibilityIdentifier: String?
    var isEnabled = true
    let action: () -> Void
}

struct CompactGlassPanelView: View {
    let model: AppModel
    let density: CompactGlassPanelDensity
    let primaryAction: CompactPanelAction

    var body: some View {
        ZStack(alignment: .topLeading) {
            CompactPanelShell(
                density: density,
                accent: stateTint
            )
            .ignoresSafeArea()

            WindowInteractionBackdrop(
                density: density
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: density.sectionSpacing) {
                headerSection
                modeBarSection

                if density.showsMonitoringSection {
                    contentDivider
                    monitoringSection
                }

                contentDivider
                footerSection
            }
            .padding(density.contentInsets)
            .padding(.top, density.titlebarClearance)
        }
        .frame(width: density.shellWidth, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .topLeading) {
            titlebarDragRegion
                .ignoresSafeArea()
        }
        .overlay(alignment: .topLeading) {
            accessibilityAnchor(identifier: density.panelAccessibilityIdentifier)
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        let content = HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppBrand.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(model.selectedMode.title)
                    .font(.system(size: density == .window ? 19 : 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("summary.current-mode")

                Text(headerDetailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(density.headerDetailLineLimit)
            }

            Spacer(minLength: 8)

            temperatureBadge
        }

        if density == .window {
            content
                .contentShape(Rectangle())
                .gesture(WindowDragGesture())
                .allowsWindowActivationEvents(true)
        } else {
            content
        }
    }

    private var temperatureBadge: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Label("最高温度", systemImage: "thermometer.medium")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(hottestTemperatureValue)
                    .font(density.temperatureValueFont)
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                Text("°C")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            CompactSurfaceBackground(
                cornerRadius: density.badgeCornerRadius,
                style: .badge(temperatureTint),
                density: density
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("最高温度 \(hottestTemperatureText)")
        .accessibilityIdentifier("summary.hottest-temp")
    }

    private var modeBarSection: some View {
        HStack(spacing: 4) {
            ForEach(FanMode.allCases) { mode in
                CompactModeButton(
                    mode: mode,
                    isSelected: model.selectedMode == mode,
                    isEnabled: model.canControl || mode == .systemAuto,
                    tint: tint(for: mode),
                    density: density
                ) {
                    Task { await model.setMode(mode) }
                }
            }
        }
        .padding(5)
        .frame(maxWidth: .infinity, minHeight: density.modeBarHeight)
        .background {
            CompactSurfaceBackground(
                cornerRadius: density.sectionCornerRadius,
                style: .segmentBar,
                density: density
            )
        }
    }

    private var monitoringSection: some View {
        VStack(alignment: .leading, spacing: density.sectionSpacing) {
            summarySection
            contentDivider
            fanSection
        }
    }

    private var summarySection: some View {
        HStack(spacing: 0) {
            CompactMetricTile(
                title: "控制状态",
                value: controlStateTitle,
                symbol: capabilitySymbol,
                accent: stateTint
            )

            Divider()
                .overlay(borderColor.opacity(0.52))
                .padding(.vertical, 6)

            CompactMetricTile(
                title: "控制通道",
                value: controlChannelTitle,
                symbol: "point.3.connected.trianglepath.dotted",
                accent: Color(red: 0.42, green: 0.49, blue: 0.57)
            )
        }
        .padding(.vertical, 2)
    }

    private var fanSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("风扇转速")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 6)

                Text(fanSummaryText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(Array(displayFanRows.enumerated()), id: \.element.id) { index, row in
                    CompactFanRowView(row: row, density: density)

                    if index < displayFanRows.count - 1 {
                        Divider()
                            .overlay(borderColor.opacity(0.48))
                            .padding(.leading, 22)
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                accessibilityAnchor(identifier: fanMonitoringIdentifier)
            }
        }
    }

    private var footerSection: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(footerStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(density.footerLineLimit)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("status.current")

            Button(action: primaryAction.action) {
                Label(primaryAction.title, systemImage: primaryAction.systemImage)
                    .font(.caption.weight(.semibold))
                    .labelStyle(.titleAndIcon)
            }
            .tint(primaryActionTint)
            .buttonStyle(.glassProminent)
            .disabled(!primaryAction.isEnabled)
            .accessibilityIdentifier(primaryAction.accessibilityIdentifier ?? "")
        }
    }

    @ViewBuilder
    private var titlebarDragRegion: some View {
        if density == .window {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: density.trafficLightsClearance, height: density.titlebarDragRegionHeight)
                    .allowsHitTesting(false)

                WindowDragHandle()
                    .frame(maxWidth: .infinity, minHeight: density.titlebarDragRegionHeight, maxHeight: density.titlebarDragRegionHeight)
            }
            .padding(.top, 6)
            .padding(.horizontal, 8)
            .accessibilityHidden(true)
        }
    }

    private var contentDivider: some View {
        Divider()
            .overlay(borderColor.opacity(0.45))
            .accessibilityHidden(true)
    }

    private func accessibilityAnchor(identifier: String) -> some View {
        Color.clear
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityIdentifier(identifier)
    }

    private var headerDetailText: String {
        if let statusMessage = model.statusMessage {
            return statusMessage
        }

        switch model.inventory?.capability {
        case .controllable:
            return model.selectedMode.detail
        case let .readOnly(reason):
            if PrivilegedHelperServiceDefinition.isCompatibilityReinstallMessage(reason) {
                return reason
            }
            return "当前为监控模式，仅显示温度和风扇读数。"
        case .unsupported:
            return "当前构建不可直接控制风扇。"
        case nil:
            return "正在探测风扇能力。"
        }
    }

    private var hottestTemperatureValue: String {
        guard let hottest = model.latestSnapshot?.hottestTemp else {
            return "--"
        }
        return String(format: "%.1f", hottest)
    }

    private var hottestTemperatureText: String {
        model.latestSnapshot?.hottestTemp?.temperatureText ?? "--°C"
    }

    private var controlStateTitle: String {
        if model.isInstallingHelper {
            return "修复中"
        }

        if model.statusMessage != nil {
            return "异常"
        }

        switch model.inventory?.capability {
        case .controllable:
            return "可控"
        case .readOnly:
            return "只读"
        case .unsupported:
            return "不可用"
        case nil:
            return "探测中"
        }
    }

    private var controlChannelTitle: String {
        let description = model.controlChannelDescription
        return description == "未建立" ? "未建立" : description
    }

    private var footerStatusText: String {
        if let statusMessage = model.statusMessage {
            return statusMessage
        }

        switch model.inventory?.capability {
        case .controllable:
            return model.selectedMode == .systemAuto
                ? "系统热管理正在接管风扇，仍会持续监控温度与 RPM。"
                : "当前模式：\(model.selectedMode.detail)"
        case let .readOnly(reason), let .unsupported(reason):
            return reason
        case nil:
            return "正在探测风扇能力。"
        }
    }

    private var displayFanRows: [CompactFanRow] {
        guard let inventory = model.inventory else {
            return [.placeholder("无读数")]
        }

        guard !inventory.fans.isEmpty else {
            return [.placeholder("无风扇")]
        }

        let rows = inventory.fans.map { fan in
            let reading = model.latestSnapshot?.fans.first(where: { $0.id == fan.id })
            return CompactFanRow(
                id: fan.id,
                title: fan.name,
                value: reading?.currentRPM.rpmText ?? "-- RPM",
                detail: reading?.targetRPM.map { "目标 \($0.rpmText)" },
                style: .reading
            )
        }

        if rows.count <= 3 {
            return rows
        }

        return Array(rows.prefix(2)) + [
            CompactFanRow(
                id: "fan-summary",
                title: "其余 \(rows.count - 2) 个风扇",
                value: "已折叠",
                detail: nil,
                style: .summary
            )
        ]
    }

    private var fanSummaryText: String {
        switch displayFanRows.filter({ $0.style == .reading }).count {
        case 0:
            return "暂无有效读数"
        case 1:
            return "1 个风扇"
        default:
            return "\(displayFanRows.filter { $0.style == .reading }.count) 个风扇"
        }
    }

    private var fanMonitoringIdentifier: String {
        displayFanRows.contains(where: { $0.style == .reading })
            ? "monitoring.fans.available"
            : "monitoring.fans.empty"
    }

    private var capabilitySymbol: String {
        switch model.inventory?.capability {
        case .controllable:
            return "checkmark.shield"
        case .readOnly:
            return "eye"
        case .unsupported:
            return "xmark.octagon"
        case nil:
            return "clock"
        }
    }

    private var stateTint: Color {
        if model.isInstallingHelper {
            return .yellow
        }

        if model.statusMessage != nil {
            return .orange
        }

        switch model.inventory?.capability {
        case .controllable:
            return tint(for: model.selectedMode)
        case .readOnly:
            return .yellow
        case .unsupported:
            return .orange
        case nil:
            return .gray
        }
    }

    private var temperatureTint: Color {
        guard let hottest = model.latestSnapshot?.hottestTemp else {
            return Color(red: 0.47, green: 0.55, blue: 0.62)
        }

        switch hottest {
        case 90...:
            return .red
        case 80...:
            return .orange
        default:
            return .blue
        }
    }

    private func tint(for mode: FanMode) -> Color {
        switch mode {
        case .systemAuto:
            return Color(red: 0.47, green: 0.53, blue: 0.59)
        case .quiet:
            return .mint
        case .balanced:
            return .blue
        case .performance:
            return .orange
        }
    }

    private var primaryActionTint: Color {
        if primaryAction.accessibilityIdentifier == "helper.install.panel" {
            return .orange
        }

        return .blue
    }

    private var borderColor: Color {
        Color.white.opacity(density == .window ? 0.18 : 0.15)
    }
}

private enum CompactSurfaceStyle {
    case segmentBar
    case badge(Color)
    case activeSegment(Color)
    case pressedSegment
}

private struct CompactPanelShell: View {
    let density: CompactGlassPanelDensity
    let accent: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: density.shellCornerRadius, style: .continuous)

        Color.clear
            .glassEffect(shellGlass, in: shape)
            .overlay {
                shape.fill(Color.white.opacity(density == .window ? 0.008 : 0.007))
            }
            .overlay {
                shape.strokeBorder(Color.white.opacity(density == .window ? 0.06 : 0.055), lineWidth: 0.8)
            }
            .padding(density.chromeInsets)
            .allowsHitTesting(false)
    }

    private var shellGlass: Glass {
        Glass.regular.tint(accent.opacity(density == .window ? 0.01 : 0.008))
    }
}

private struct CompactSurfaceBackground: View {
    let cornerRadius: CGFloat
    let style: CompactSurfaceStyle
    let density: CompactGlassPanelDensity

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        shape
            .fill(material)
            .overlay {
                shape.fill(Color.white.opacity(highlightOpacity))
            }
            .overlay {
                shape.fill(surfaceTint)
            }
            .overlay {
                shape.strokeBorder(borderColor, lineWidth: density == .window ? 0.8 : 0.7)
            }
    }

    private var material: Material {
        switch style {
        case .segmentBar:
            .ultraThinMaterial
        case .badge, .activeSegment:
            .thinMaterial
        case .pressedSegment:
            .ultraThinMaterial
        }
    }

    private var highlightOpacity: Double {
        switch style {
        case .segmentBar:
            density == .window ? 0.01 : 0.008
        case .badge:
            density == .window ? 0.018 : 0.014
        case .activeSegment:
            density == .window ? 0.016 : 0.013
        case .pressedSegment:
            density == .window ? 0.014 : 0.012
        }
    }

    private var surfaceTint: Color {
        switch style {
        case .segmentBar:
            Color.white.opacity(density == .window ? 0.01 : 0.008)
        case let .badge(color):
            color.opacity(density == .window ? 0.055 : 0.05)
        case let .activeSegment(color):
            color.opacity(density == .window ? 0.075 : 0.065)
        case .pressedSegment:
            Color.white.opacity(density == .window ? 0.018 : 0.015)
        }
    }

    private var borderColor: Color {
        switch style {
        case let .activeSegment(color):
            return color.opacity(density == .window ? 0.14 : 0.12)
        case let .badge(color):
            return color.opacity(density == .window ? 0.09 : 0.08)
        case .segmentBar:
            return Color.white.opacity(density == .window ? 0.07 : 0.06)
        case .pressedSegment:
            return Color.white.opacity(density == .window ? 0.09 : 0.08)
        }
    }
}

private struct CompactModeButton: View {
    let mode: FanMode
    let isSelected: Bool
    let isEnabled: Bool
    let tint: Color
    let density: CompactGlassPanelDensity
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: density == .window ? 3 : 2) {
                Image(systemName: mode.symbol)
                    .font(density.modeSymbolFont)

                Text(mode.title)
                    .font(density.modeTitleFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: density.segmentHeight)
            .padding(.horizontal, 4)
            .foregroundStyle(textColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(CompactModeButtonStyle(density: density, isSelected: isSelected, tint: tint))
        .disabled(!isEnabled)
        .accessibilityIdentifier("mode." + mode.rawValue)
    }

    private var textColor: Color {
        if !isEnabled {
            return Color.secondary.opacity(0.55)
        }

        return isSelected ? .primary : .secondary
    }
}

private struct CompactModeButtonStyle: ButtonStyle {
    let density: CompactGlassPanelDensity
    let isSelected: Bool
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if isSelected {
                    CompactSurfaceBackground(
                        cornerRadius: density.segmentCornerRadius,
                        style: .activeSegment(tint),
                        density: density
                    )
                } else if configuration.isPressed {
                    CompactSurfaceBackground(
                        cornerRadius: density.segmentCornerRadius,
                        style: .pressedSegment,
                        density: density
                    )
                }
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }
}

private struct WindowInteractionBackdrop: View {
    let density: CompactGlassPanelDensity

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: density.shellCornerRadius, style: .continuous)

        shape
            .fill(Color.black.opacity(0.001))
            .contentShape(shape)
            .onTapGesture {}
    }
}

private struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragHandleView {
        DragHandleView(frame: .zero)
    }

    func updateNSView(_ nsView: DragHandleView, context: Context) {}

    final class DragHandleView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            true
        }
    }
}

private struct CompactMetricTile: View {
    let title: String
    let value: String
    let symbol: String
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CompactFanRow: Identifiable {
    enum Style {
        case reading
        case summary
        case placeholder
    }

    let id: String
    let title: String
    let value: String
    let detail: String?
    let style: Style

    static func placeholder(_ title: String) -> CompactFanRow {
        CompactFanRow(id: "fan-placeholder", title: title, value: "--", detail: nil, style: .placeholder)
    }
}

private struct CompactFanRowView: View {
    let row: CompactFanRow
    let density: CompactGlassPanelDensity

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Label(row.title, systemImage: iconName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(titleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(row.value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                if let detail = row.detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, density == .window ? 8 : 7)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var iconName: String {
        switch row.style {
        case .reading:
            return "fanblades"
        case .summary:
            return "ellipsis"
        case .placeholder:
            return "fan"
        }
    }

    private var titleColor: Color {
        switch row.style {
        case .reading:
            return .secondary
        case .summary:
            return Color.secondary.opacity(0.82)
        case .placeholder:
            return Color.secondary.opacity(0.72)
        }
    }
}
