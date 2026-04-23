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
            304
        case .menuBar:
            272
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
            EdgeInsets(top: 4, leading: 12, bottom: 10, trailing: 12)
        case .menuBar:
            EdgeInsets(top: 4, leading: 9, bottom: 9, trailing: 9)
        }
    }

    var sectionSpacing: CGFloat {
        switch self {
        case .window:
            6
        case .menuBar:
            5
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
            44
        case .menuBar:
            40
        }
    }

    var summaryListHeight: CGFloat {
        switch self {
        case .window:
            72
        case .menuBar:
            72
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
            34
        case .menuBar:
            32
        }
    }

    var temperatureValueFont: Font {
        switch self {
        case .window:
            .system(size: 20, weight: .bold, design: .rounded)
        case .menuBar:
            .system(size: 18, weight: .bold, design: .rounded)
        }
    }

    var modeSymbolFont: Font {
        switch self {
        case .window:
            .system(size: 10.5, weight: .semibold)
        case .menuBar:
            .system(size: 9.5, weight: .semibold)
        }
    }

    var modeTitleFont: Font {
        switch self {
        case .window:
            .system(size: 9, weight: .semibold, design: .rounded)
        case .menuBar:
            .system(size: 8.5, weight: .semibold, design: .rounded)
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
            1
        case .menuBar:
            1
        }
    }

    var usesColoredIcons: Bool {
        true
    }

    var coloredIconOpacity: Double {
        switch self {
        case .window:
            0.82
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
            7
        case .menuBar:
            0
        }
    }

    var titlebarDragRegionHeight: CGFloat {
        switch self {
        case .window:
            20
        case .menuBar:
            0
        }
    }

    var trafficLightsClearance: CGFloat {
        switch self {
        case .window:
            58
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
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var modeSelectionNamespace
    @State private var liquidDragStartDate: Date?
    @State private var liquidSelectionMode: FanMode?
    @State private var isLiquidDragging = false
    @State private var liquidIndicatorCenterX: CGFloat?
    @State private var liquidLastSampleX: CGFloat?
    @State private var liquidLastSampleTime: Date?
    @State private var liquidStretchX: CGFloat = 1
    @State private var liquidStretchY: CGFloat = 1
    @State private var liquidTiltDegrees: Double = 0

    private let modeBarHorizontalPadding: CGFloat = 3
    private let modeBarItemSpacing: CGFloat = 4

    var body: some View {
        ZStack(alignment: .topLeading) {
            CompactPanelShell(
                density: density,
                accent: stateTint,
                appearanceStyle: model.appearanceStyle
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
            .animation(.snappy(duration: 0.28, extraBounce: 0.06), value: model.selectedMode)
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
        let content = HStack(alignment: .top, spacing: 9) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppBrand.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(model.selectedMode.title)
                    .font(.system(size: density == .window ? 17 : 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.opacity)
                    .accessibilityIdentifier("summary.current-mode")

                Text(headerDetailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(density.headerDetailLineLimit)
            }

            Spacer(minLength: 6)

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
            Label {
                Text("最高温度")
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "thermometer.medium")
                    .foregroundStyle(temperatureBadgeIconColor)
            }
                .font(.caption2.weight(.semibold))

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
        .padding(.horizontal, density == .window ? 8 : 7)
        .padding(.vertical, density == .window ? 6 : 5)
        .background {
            CompactSurfaceBackground(
                cornerRadius: density.badgeCornerRadius,
                style: .badge(temperatureTint),
                density: density,
                appearanceStyle: model.appearanceStyle
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("最高温度 \(hottestTemperatureText)")
        .accessibilityIdentifier("summary.hottest-temp")
    }

    private var modeBarSection: some View {
        GeometryReader { proxy in
            let visualSelectedMode = liquidSelectionMode ?? model.selectedMode
            let metrics = modeBarMetrics(totalWidth: proxy.size.width)

            GlassEffectContainer(spacing: density == .window ? 20 : 16) {
                HStack(spacing: modeBarItemSpacing) {
                    ForEach(FanMode.allCases) { mode in
                        CompactModeButton(
                            mode: mode,
                            isSelected: visualSelectedMode == mode,
                            showsSelectionBackground: !isLiquidDragging,
                            isEnabled: model.canControl || mode == .systemAuto,
                            isInteractionLocked: isLiquidDragging,
                            tint: tint(for: mode),
                            density: density,
                            appearanceStyle: model.appearanceStyle,
                            selectionNamespace: modeSelectionNamespace
                        ) {
                            Task { await model.setMode(mode) }
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(modeBarLiquidGesture(totalWidth: proxy.size.width))
            .animation(.snappy(duration: 0.22, extraBounce: 0.08), value: liquidSelectionMode)
            .scaleEffect(isLiquidDragging ? 1.01 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: isLiquidDragging)
            .padding(modeBarHorizontalPadding)
            .frame(maxWidth: .infinity, minHeight: density.modeBarHeight, maxHeight: density.modeBarHeight)
            .background {
                CompactSurfaceBackground(
                    cornerRadius: density.sectionCornerRadius,
                    style: .segmentBar(segmentBarTint),
                    density: density,
                    appearanceStyle: model.appearanceStyle
                )
            }
            .overlay(alignment: .leading) {
                if isLiquidDragging, let liquidIndicatorCenterX {
                    let indicatorWidth = metrics.segmentWidth + 2
                    CompactSurfaceBackground(
                        cornerRadius: density.segmentCornerRadius,
                        style: .liquidDrag(tint(for: visualSelectedMode)),
                        density: density,
                        appearanceStyle: model.appearanceStyle
                    )
                    .frame(width: indicatorWidth, height: density.segmentHeight)
                    .scaleEffect(x: liquidStretchX, y: liquidStretchY)
                    .rotationEffect(.degrees(liquidTiltDegrees))
                    .offset(x: liquidIndicatorCenterX - (indicatorWidth / 2))
                    .shadow(color: tint(for: visualSelectedMode).opacity(0.3), radius: 8, y: 1.5)
                    .allowsHitTesting(false)
                    .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.82), value: liquidIndicatorCenterX)
                    .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.68), value: liquidStretchX)
                    .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.68), value: liquidStretchY)
                    .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.7), value: liquidTiltDegrees)
                }
            }
        }
        .frame(height: density.modeBarHeight)
        .animation(.snappy(duration: 0.28, extraBounce: 0.06), value: model.selectedMode)
    }

    private var monitoringSection: some View {
        VStack(alignment: .leading, spacing: density.sectionSpacing) {
            summarySection
            contentDivider
            fanSection
        }
    }

    private var summarySection: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(summaryTemperatureMetrics) { metric in
                    CompactInlineMetricRow(metric: metric, density: density)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: density.summaryListHeight)
        .padding(.vertical, 0)
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
            .padding(.bottom, 4)

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
            HStack(alignment: .center, spacing: 6) {
            Text(footerStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(density.footerLineLimit)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("status.current")

            Button(action: primaryAction.action) {
                CompactPrimaryActionLabel(
                    title: primaryAction.title,
                    systemImage: primaryAction.systemImage
                )
            }
            .tint(primaryActionTint)
            .buttonStyle(.glassProminent)
            .disabled(!primaryAction.isEnabled)
            .accessibilityIdentifier(primaryAction.accessibilityIdentifier ?? "")
        }
        .padding(.top, 2)
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
            .padding(.top, 2)
            .padding(.horizontal, 4)
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

    private var summaryTemperatureMetrics: [CompactTemperatureMetric] {
        guard let snapshot = model.latestSnapshot, !snapshot.sensors.isEmpty else {
            return [
                CompactTemperatureMetric(
                    id: "sensor-placeholder-1",
                    title: "硬件温度",
                    value: "--°C",
                    symbol: "thermometer.medium",
                    accent: Color(red: 0.47, green: 0.55, blue: 0.62)
                ),
                CompactTemperatureMetric(
                    id: "sensor-placeholder-2",
                    title: "其他传感器",
                    value: "--°C",
                    symbol: "cpu",
                    accent: Color(red: 0.47, green: 0.55, blue: 0.62)
                )
            ]
        }

        let descriptorsByID = Dictionary(uniqueKeysWithValues: (model.inventory?.sensors ?? []).map { ($0.id, $0) })
        let candidates = snapshot.sensors.map { reading in
            SummarySensorCandidate(reading: reading, descriptor: descriptorsByID[reading.id])
        }

        let orderedCandidates = candidates.sorted { lhs, rhs in
            let lhsPriority = sensorSelectionPriority(lhs.descriptor?.kind)
            let rhsPriority = sensorSelectionPriority(rhs.descriptor?.kind)
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.reading.celsius > rhs.reading.celsius
        }

        let metrics = orderedCandidates
            .enumerated()
            .map { offset, candidate in
                let title = candidate.descriptor?.name ?? sensorTitle(for: candidate.descriptor?.kind, fallbackIndex: offset + 1)
                let symbol = sensorSymbol(for: candidate.descriptor?.kind)
                return CompactTemperatureMetric(
                    id: candidate.reading.id,
                    title: title,
                    value: candidate.reading.celsius.temperatureText,
                    symbol: symbol,
                    accent: temperatureAccent(for: candidate.reading.celsius)
                )
            }
        return metrics
    }

    private func sensorSelectionPriority(_ kind: SensorKind?) -> Int {
        switch kind {
        case .performanceCPU:
            return 0
        case .efficiencyCPU:
            return 1
        case .memory:
            return 2
        case .storage:
            return 3
        case .wireless:
            return 4
        case .battery:
            return 5
        case .gpu:
            return 6
        case .ambient:
            return 7
        case .raw:
            return 8
        case nil:
            return 9
        }
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

    private func sensorTitle(for kind: SensorKind?, fallbackIndex: Int) -> String {
        switch kind {
        case .performanceCPU:
            return "性能核"
        case .efficiencyCPU:
            return "效率核"
        case .gpu:
            return "GPU"
        case .battery:
            return "电池"
        case .memory:
            return "内存"
        case .storage:
            return "SSD"
        case .wireless:
            return "Wi-Fi"
        case .ambient:
            return "环境"
        case .raw:
            return "传感器\(fallbackIndex)"
        case nil:
            return "传感器\(fallbackIndex)"
        }
    }

    private func sensorSymbol(for kind: SensorKind?) -> String {
        switch kind {
        case .performanceCPU, .efficiencyCPU:
            return "cpu"
        case .gpu:
            return "cpu.fill"
        case .battery:
            return "battery.75"
        case .memory:
            return "memorychip"
        case .storage:
            return "internaldrive"
        case .wireless:
            return "wifi"
        case .ambient:
            return "thermometer.medium"
        case .raw:
            return "dot.scope"
        case nil:
            return "thermometer.medium"
        }
    }

    private func temperatureAccent(for celsius: Double) -> Color {
        switch celsius {
        case 90...:
            return .red
        case 80...:
            return .orange
        default:
            return .blue
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

    private var segmentBarTint: Color {
        .white
    }

    private func modeBarLiquidGesture(totalWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                handleModeBarDragChanged(value, totalWidth: totalWidth)
            }
            .onEnded { _ in
                handleModeBarDragEnded()
            }
    }

    private func handleModeBarDragChanged(_ value: DragGesture.Value, totalWidth: CGFloat) {
        let now = Date()
        if liquidDragStartDate == nil {
            liquidDragStartDate = now
            liquidSelectionMode = model.selectedMode
            liquidLastSampleTime = now
        }

        guard let startDate = liquidDragStartDate else {
            return
        }

        if !isLiquidDragging {
            let elapsed = now.timeIntervalSince(startDate)
            guard elapsed >= 0.2 else {
                return
            }
            isLiquidDragging = true
        }

        let clampedX = clampedModeBarX(for: value.location.x, totalWidth: totalWidth)
        liquidIndicatorCenterX = clampedX
        updateLiquidDynamics(currentX: clampedX, now: now)

        guard let hoveredMode = mode(at: value.location.x, totalWidth: totalWidth),
              canSelectMode(hoveredMode) else {
            return
        }

        if liquidSelectionMode != hoveredMode {
            withAnimation(.snappy(duration: 0.12, extraBounce: 0.04)) {
                liquidSelectionMode = hoveredMode
            }
        }
    }

    private func handleModeBarDragEnded() {
        defer {
            liquidDragStartDate = nil
            withAnimation(.snappy(duration: 0.16, extraBounce: 0.04)) {
                isLiquidDragging = false
                liquidSelectionMode = nil
                liquidIndicatorCenterX = nil
                liquidLastSampleX = nil
                liquidLastSampleTime = nil
                liquidStretchX = 1
                liquidStretchY = 1
                liquidTiltDegrees = 0
            }
        }

        guard isLiquidDragging,
              let targetMode = liquidSelectionMode,
              targetMode != model.selectedMode,
              canSelectMode(targetMode) else {
            return
        }

        Task { await model.setMode(targetMode) }
    }

    private func mode(at xPosition: CGFloat, totalWidth: CGFloat) -> FanMode? {
        let modes = FanMode.allCases
        guard !modes.isEmpty else {
            return nil
        }

        let metrics = modeBarMetrics(totalWidth: totalWidth)
        let innerWidth = metrics.innerWidth
        let segmentWidth = metrics.segmentWidth
        guard segmentWidth > 0 else {
            return nil
        }

        let clampedX = min(max(0, xPosition - modeBarHorizontalPadding), innerWidth)

        for index in modes.indices {
            let start = CGFloat(index) * (segmentWidth + modeBarItemSpacing)
            let end = start + segmentWidth
            if clampedX >= start && clampedX <= end {
                return modes[index]
            }
        }

        let slotWidth = segmentWidth + modeBarItemSpacing
        let nearestIndex = Int(round(clampedX / slotWidth))
        let boundedIndex = min(max(0, nearestIndex), modes.count - 1)
        return modes[boundedIndex]
    }

    private func modeBarMetrics(totalWidth: CGFloat) -> (innerWidth: CGFloat, segmentWidth: CGFloat) {
        let count = CGFloat(FanMode.allCases.count)
        let innerWidth = max(1, totalWidth - (modeBarHorizontalPadding * 2))
        let spacingTotal = modeBarItemSpacing * max(0, count - 1)
        let segmentWidth = max(1, (innerWidth - spacingTotal) / max(1, count))
        return (innerWidth, segmentWidth)
    }

    private func clampedModeBarX(for xPosition: CGFloat, totalWidth: CGFloat) -> CGFloat {
        let metrics = modeBarMetrics(totalWidth: totalWidth)
        let minX = modeBarHorizontalPadding + (metrics.segmentWidth / 2)
        let maxX = totalWidth - modeBarHorizontalPadding - (metrics.segmentWidth / 2)
        return min(max(xPosition, minX), maxX)
    }

    private func updateLiquidDynamics(currentX: CGFloat, now: Date) {
        defer {
            liquidLastSampleX = currentX
            liquidLastSampleTime = now
        }

        guard let previousX = liquidLastSampleX,
              let previousTime = liquidLastSampleTime else {
            return
        }

        let deltaTime = max(0.001, now.timeIntervalSince(previousTime))
        let deltaX = currentX - previousX
        let speed = abs(deltaX) / deltaTime
        let normalized = min(1, speed / 900)

        liquidStretchX = 1 + (normalized * 0.42)
        liquidStretchY = 1 - (normalized * 0.22)
        liquidTiltDegrees = Double(max(-10, min(10, (deltaX / 18) * 3.2)))
    }

    private func canSelectMode(_ mode: FanMode) -> Bool {
        model.canControl || mode == .systemAuto
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

    private var temperatureBadgeIconColor: Color {
        density.usesColoredIcons
            ? temperatureTint.opacity(density.coloredIconOpacity)
            : .secondary
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
        colorScheme == .dark
            ? Color.white.opacity(density == .window ? 0.18 : 0.15)
            : Color.black.opacity(density == .window ? 0.18 : 0.16)
    }
}

private enum CompactSurfaceStyle {
    case segmentBar(Color)
    case badge(Color)
    case activeSegment(Color)
    case liquidDrag(Color)
    case pressedSegment
}

private struct CompactPanelShell: View {
    let density: CompactGlassPanelDensity
    let accent: Color
    let appearanceStyle: AppAppearanceStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: density.shellCornerRadius, style: .continuous)

        Color.clear
            .glassEffect(shellGlass, in: shape)
            .overlay {
                shape.fill(shellOverlayColor)
            }
            .overlay {
                shape.strokeBorder(shellBorderColor, lineWidth: 0.8)
            }
            .padding(density.chromeInsets)
            .allowsHitTesting(false)
    }

    private var shellGlass: Glass {
        switch appearanceStyle {
        case .highTransparency:
            let tint: Color = colorScheme == .dark
                ? .white.opacity(density == .window ? 0.02 : 0.016)
                : accent.opacity(density == .window ? 0.018 : 0.014)
            return Glass.clear.tint(tint).interactive(true)
        case .normal:
            let tint: Color = colorScheme == .dark
                ? .white.opacity(density == .window ? 0.055 : 0.05)
                : .black.opacity(density == .window ? 0.075 : 0.068)
            return Glass.regular.tint(tint).interactive(true)
        }
    }

    private var shellOverlayColor: Color {
        switch appearanceStyle {
        case .highTransparency:
            if colorScheme == .dark {
                return Color.white.opacity(density == .window ? 0.022 : 0.018)
            }
            return Color.white.opacity(density == .window ? 0.07 : 0.06)
        case .normal:
            if colorScheme == .dark {
                return Color.white.opacity(density == .window ? 0.07 : 0.06)
            }
            return Color.white.opacity(density == .window ? 0.16 : 0.14)
        }
    }

    private var shellBorderColor: Color {
        switch appearanceStyle {
        case .highTransparency:
            if colorScheme == .dark {
                return Color.white.opacity(density == .window ? 0.11 : 0.095)
            }
            return Color.white.opacity(density == .window ? 0.5 : 0.42)
        case .normal:
            if colorScheme == .dark {
                return Color.white.opacity(density == .window ? 0.2 : 0.175)
            }
            return Color.black.opacity(density == .window ? 0.14 : 0.12)
        }
    }
}

private struct CompactSurfaceBackground: View {
    let cornerRadius: CGFloat
    let style: CompactSurfaceStyle
    let density: CompactGlassPanelDensity
    let appearanceStyle: AppAppearanceStyle
    @Environment(\.colorScheme) private var colorScheme

    private var isNormalAppearance: Bool {
        appearanceStyle == .normal
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if case .activeSegment = style {
            shape
                .fill(activeSegmentBase)
                .overlay {
                    shape.fill(activeSegmentOverlay)
                }
                .overlay {
                    shape.strokeBorder(borderColor, lineWidth: density == .window ? 1.05 : 0.95)
                }
        } else if case .liquidDrag = style {
            Color.clear
                .glassEffect(liquidDragGlass, in: shape)
                .overlay {
                    shape.fill(liquidDragOverlay)
                }
                .overlay {
                    shape.strokeBorder(liquidDragBorder, lineWidth: density == .window ? 1 : 0.9)
                }
        } else {
            Color.clear
                .glassEffect(surfaceGlass, in: shape)
                .overlay {
                    shape.fill(highlightColor)
                }
                .overlay {
                    shape.fill(surfaceTint)
                }
                .overlay {
                    shape.strokeBorder(borderColor, lineWidth: density == .window ? 0.85 : 0.75)
                }
        }
    }

    private var surfaceGlass: Glass {
        switch style {
        case let .segmentBar(color):
            if isNormalAppearance {
                return Glass.regular.tint(colorScheme == .dark
                    ? .white.opacity(density == .window ? 0.055 : 0.05)
                    : .black.opacity(density == .window ? 0.075 : 0.068))
                    .interactive(true)
            }
            return Glass.clear.tint(colorScheme == .dark
                ? color.opacity(density == .window ? 0.018 : 0.014)
                : color.opacity(density == .window ? 0.095 : 0.08))
                .interactive(true)
        case let .badge(color):
            return Glass.regular.tint(color.opacity(density == .window ? 0.03 : 0.026))
        case .activeSegment:
            return Glass.regular.tint(activeTint.opacity(density == .window
                ? (isNormalAppearance ? 0.055 : 0.068)
                : (isNormalAppearance ? 0.048 : 0.06)))
                .interactive(true)
        case .liquidDrag:
            return Glass.clear.tint(activeTint.opacity(density == .window
                ? (isNormalAppearance ? 0.014 : 0.022)
                : (isNormalAppearance ? 0.012 : 0.018)))
                .interactive(true)
        case .pressedSegment:
            return Glass.clear.tint(colorScheme == .dark
                ? .white.opacity(density == .window ? 0.012 : 0.01)
                : .white.opacity(density == .window ? 0.08 : 0.07))
                .interactive(true)
        }
    }

    private var activeGlass: Glass {
        Glass.regular.tint(activeTint.opacity(density == .window ? 0.062 : 0.055))
            .interactive(true)
    }

    private var liquidDragGlass: Glass {
        Glass.clear
            .tint(activeTint.opacity(density == .window ? 0.016 : 0.013))
            .interactive(true)
    }

    private var activeSegmentBase: Color {
        colorScheme == .dark
            ? Color.white.opacity(density == .window ? 0.12 : 0.1)
            : Color.white.opacity(density == .window ? 0.72 : 0.66)
    }

    private var activeSegmentOverlay: Color {
        colorScheme == .dark
            ? activeTint.opacity(density == .window ? 0.05 : 0.042)
            : activeTint.opacity(density == .window ? 0.1 : 0.086)
    }

    private var liquidDragOverlay: Color {
        colorScheme == .dark
            ? Color.white.opacity(density == .window ? 0.018 : 0.015)
            : Color.white.opacity(density == .window ? 0.06 : 0.05)
    }

    private var liquidDragBorder: Color {
        colorScheme == .dark
            ? Color.white.opacity(density == .window ? 0.3 : 0.26)
            : Color.white.opacity(density == .window ? 0.9 : 0.82)
    }

    private var material: Material {
        switch style {
        case .segmentBar:
            .ultraThinMaterial
        case .badge, .activeSegment, .liquidDrag:
            .thinMaterial
        case .pressedSegment:
            .ultraThinMaterial
        }
    }

    private var highlightOpacity: Double {
        switch style {
        case .segmentBar:
            if isNormalAppearance {
                return density == .window ? 0.016 : 0.014
            }
            return density == .window ? 0.008 : 0.006
        case .badge:
            return density == .window ? 0.014 : 0.012
        case .activeSegment:
            return 0
        case .liquidDrag:
            return 0
        case .pressedSegment:
            return density == .window ? 0.012 : 0.01
        }
    }

    private var highlightColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(highlightOpacity)
        }
        if case .segmentBar = style {
            return Color.white.opacity(highlightOpacity * 7)
        }
        return Color.white.opacity(highlightOpacity * 2)
    }

    private var surfaceTint: Color {
        switch style {
        case let .segmentBar(color):
            if isNormalAppearance {
                return colorScheme == .dark
                    ? .white.opacity(density == .window ? 0.06 : 0.052)
                    : .black.opacity(density == .window ? 0.095 : 0.085)
            }
            return color.opacity(density == .window ? 0.022 : 0.018)
        case let .badge(color):
            return color.opacity(density == .window ? 0.032 : 0.028)
        case .activeSegment:
            return colorScheme == .dark
                ? Color.white.opacity(density == .window ? 0.015 : 0.012)
                : Color.white.opacity(density == .window ? 0.065 : 0.055)
        case .liquidDrag:
            return .clear
        case .pressedSegment:
            return colorScheme == .dark
                ? Color.white.opacity(density == .window ? 0.022 : 0.018)
                : Color.white.opacity(density == .window ? 0.085 : 0.074)
        }
    }

    private var borderColor: Color {
        switch style {
        case .activeSegment:
            return colorScheme == .dark
                ? Color.white.opacity(density == .window ? 0.16 : 0.14)
                : Color.black.opacity(density == .window ? 0.22 : 0.19)
        case .liquidDrag:
            return colorScheme == .dark
                ? Color.white.opacity(density == .window ? 0.2 : 0.17)
                : Color.white.opacity(density == .window ? 0.75 : 0.66)
        case let .badge(color):
            return color.opacity(density == .window ? 0.07 : 0.064)
        case .segmentBar:
            if isNormalAppearance {
                return colorScheme == .dark
                    ? Color.white.opacity(density == .window ? 0.18 : 0.16)
                    : Color.black.opacity(density == .window ? 0.13 : 0.115)
            }
            return colorScheme == .dark
                ? Color.white.opacity(density == .window ? 0.12 : 0.105)
                : Color.white.opacity(density == .window ? 0.45 : 0.39)
        case .pressedSegment:
            return colorScheme == .dark
                ? Color.white.opacity(density == .window ? 0.09 : 0.08)
                : Color.white.opacity(density == .window ? 0.52 : 0.45)
        }
    }

    private var selectedSegmentFill: Color {
        colorScheme == .dark ? .black : .white
    }

    private var activeTint: Color {
        if case let .activeSegment(color) = style {
            return color
        }
        return .blue
    }
}

private struct CompactModeButton: View {
    let mode: FanMode
    let isSelected: Bool
    let showsSelectionBackground: Bool
    let isEnabled: Bool
    let isInteractionLocked: Bool
    let tint: Color
    let density: CompactGlassPanelDensity
    let appearanceStyle: AppAppearanceStyle
    let selectionNamespace: Namespace.ID
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: density == .window ? 3 : 2) {
                Image(systemName: mode.symbol)
                    .font(density.modeSymbolFont)
                    .foregroundStyle(symbolColor)
                    .scaleEffect(symbolScale)
                    .offset(y: symbolOffset)

                Text(mode.title)
                    .font(density.modeTitleFont)
                    .fontWeight(isSelected ? .bold : .semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(textColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: density.segmentHeight)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .animation(.snappy(duration: 0.16), value: isSelected)
            .animation(.snappy(duration: 0.16), value: isHovering)
        }
        .buttonStyle(
            CompactModeButtonStyle(
                density: density,
                isSelected: isSelected,
                showsSelectionBackground: showsSelectionBackground,
                tint: tint,
                appearanceStyle: appearanceStyle,
                selectionNamespace: selectionNamespace
            )
        )
        .disabled(!isEnabled || isInteractionLocked)
        .onHover { isHovering in
            self.isHovering = isHovering
        }
        .accessibilityIdentifier("mode." + mode.rawValue)
    }

    private var textColor: Color {
        if !isEnabled {
            return Color.secondary.opacity(0.55)
        }

        if isSelected {
            return colorScheme == .dark
                ? Color.white.opacity(0.95)
                : Color.black.opacity(0.9)
        }

        return .secondary
    }

    private var symbolColor: Color {
        guard density.usesColoredIcons else {
            return textColor
        }

        if !isEnabled {
            return Color.secondary.opacity(0.55)
        }

        return isSelected
            ? tint.opacity(1)
            : tint.opacity(density.coloredIconOpacity * 0.86)
    }

    private var symbolScale: CGFloat {
        guard isEnabled else {
            return 1
        }

        if isSelected {
            return density == .window ? 1.06 : 1.08
        }

        return isHovering ? 1.04 : 1
    }

    private var symbolOffset: CGFloat {
        guard isEnabled, isSelected || isHovering else {
            return 0
        }

        return density == .window ? -0.8 : -1
    }
}

private struct CompactModeButtonStyle: ButtonStyle {
    let density: CompactGlassPanelDensity
    let isSelected: Bool
    let showsSelectionBackground: Bool
    let tint: Color
    let appearanceStyle: AppAppearanceStyle
    let selectionNamespace: Namespace.ID

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if isSelected, showsSelectionBackground {
                    CompactSurfaceBackground(
                        cornerRadius: density.segmentCornerRadius,
                        style: .activeSegment(tint),
                        density: density,
                        appearanceStyle: appearanceStyle
                    )
                    .matchedGeometryEffect(id: "mode-selection-pill", in: selectionNamespace)
                } else if configuration.isPressed {
                    CompactSurfaceBackground(
                        cornerRadius: density.segmentCornerRadius,
                        style: .pressedSegment,
                        density: density,
                        appearanceStyle: appearanceStyle
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

private struct CompactTemperatureMetric: Identifiable {
    let id: String
    let title: String
    let value: String
    let symbol: String
    let accent: Color
}

private struct SummarySensorCandidate {
    let reading: SensorReading
    let descriptor: SensorDescriptor?
}

private struct CompactInlineMetricRow: View {
    let metric: CompactTemperatureMetric
    let density: CompactGlassPanelDensity

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: metric.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(metric.accent.opacity(density.coloredIconOpacity))
                .frame(width: 12)

            Text(metric.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 6)

            Text(metric.value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.vertical, density == .window ? 2 : 1)
    }
}

private struct CompactInlineMetricChip: View {
    let metric: CompactTemperatureMetric
    let density: CompactGlassPanelDensity
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        HStack(spacing: 7) {
            Image(systemName: metric.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(metric.accent.opacity(density.coloredIconOpacity))
                .frame(width: 12)

            VStack(alignment: .leading, spacing: 1) {
                Text(metric.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(metric.value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Color.clear
                .glassEffect(chipGlass, in: shape)
                .overlay {
                    shape.fill(chipOverlayColor)
                }
                .overlay {
                    shape.strokeBorder(chipBorderColor, lineWidth: 0.7)
                }
        }
    }

    private var chipGlass: Glass {
        Glass.regular.tint(metric.accent.opacity(density == .window ? 0.055 : 0.048))
    }

    private var chipOverlayColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(density == .window ? 0.012 : 0.01)
        }
        return Color.black.opacity(density == .window ? 0.06 : 0.052)
    }

    private var chipBorderColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(density == .window ? 0.09 : 0.08)
        }
        return Color.black.opacity(density == .window ? 0.13 : 0.115)
    }
}

private struct CompactPrimaryActionLabel: View {
    let title: String
    let systemImage: String

    @State private var isHovering = false

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .scaleEffect(isHovering ? 1.08 : 1)
                .offset(x: isHovering ? 1 : 0)
        }
        .font(.caption.weight(.semibold))
        .labelStyle(.titleAndIcon)
        .animation(.snappy(duration: 0.16), value: isHovering)
        .onHover { isHovering in
            self.isHovering = isHovering
        }
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
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 12)

                Text(row.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 6)

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
        .padding(.vertical, density == .window ? 6 : 5)
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

    private var iconColor: Color {
        guard density.usesColoredIcons else {
            return titleColor
        }

        switch row.style {
        case .reading:
            return Color(red: 0.22, green: 0.62, blue: 0.98).opacity(density.coloredIconOpacity)
        case .summary:
            return Color(red: 0.56, green: 0.64, blue: 0.73).opacity(density.coloredIconOpacity)
        case .placeholder:
            return Color(red: 0.47, green: 0.55, blue: 0.62).opacity(density.coloredIconOpacity)
        }
    }
}
