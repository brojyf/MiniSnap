import SwiftUI

struct ControlSummary: View {
    let recommendation: ExposureRecommendation
    let subjectDetection: SubjectDetection
    let rotationAngle: Angle

    var body: some View {
        let bgOverexposed = recommendation.warnings.contains { $0.contains("背景高光") }
        VStack(alignment: .center, spacing: 4) {
            if bgOverexposed {
                Label("背景可能过曝", systemImage: "sun.max.trianglebadge.exclamationmark")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 8) {
                SummaryTile(
                    title: "距离",
                    value: recommendation.control.focusMode.rangeText,
                    systemImage: "scope",
                    rotationAngle: rotationAngle
                )
                SummaryTile(
                    title: "曝光",
                    value: recommendation.control.ev.rawValue,
                    systemImage: "plusminus",
                    rotationAngle: rotationAngle
                )
                SummaryTile(
                    title: "闪光",
                    value: recommendation.control.flash.localizedName,
                    systemImage: "bolt.fill",
                    rotationAngle: rotationAngle
                )
                SummaryTile(
                    title: "主体",
                    value: subjectDetection.localizedName,
                    systemImage: subjectDetection.systemImage,
                    rotationAngle: rotationAngle
                )
            }
        }
        .padding(bgOverexposed ? 8 : 0)
        .background(bgOverexposed ? Color.yellow.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct SummaryTile: View {
    let title: String
    let value: String
    var detail: String? = nil
    let systemImage: String
    let rotationAngle: Angle

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.55)
                .lineLimit(1)
            if let detail {
                Text(detail)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 66, maxHeight: 66, alignment: .leading)
        .padding(8)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .rotationEffect(rotationAngle)
        .animation(.easeInOut(duration: 0.34), value: rotationAngle)
    }
}
