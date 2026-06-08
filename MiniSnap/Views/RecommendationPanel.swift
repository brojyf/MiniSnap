import AVFoundation
import SwiftUI

struct RecommendationPanel: View {
    let recommendation: ExposureRecommendation?
    let subjectDetection: SubjectDetection
    let authorizationStatus: AVAuthorizationStatus
    let statusText: String
    let requestAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch authorizationStatus {
            case .authorized:
                if let recommendation {
                    ControlSummary(recommendation: recommendation, subjectDetection: subjectDetection)
                } else {
                    WaitingForFaceView(statusText: statusText)
                }
            case .notDetermined:
                PermissionContent(
                    title: "打开相机开始测光",
                    message: "需要相机画面来检测人脸并计算亮度。",
                    buttonTitle: "允许相机",
                    action: requestAccess
                )
            default:
                PermissionContent(
                    title: "相机权限未开启",
                    message: "请在系统设置中允许 MiniSnap 使用相机。",
                    buttonTitle: "重新检查",
                    action: requestAccess
                )
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .frame(height: InstaxMiniLayout.bottomPanelHeight, alignment: .center)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: InstaxMiniLayout.bottomPanelCornerRadius, style: .continuous)
        )
    }
}

private struct PermissionContent: View {
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(action: action) {
                Label(buttonTitle, systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct WaitingForFaceView: View {
    let statusText: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "face.dashed")
                .font(.title2)
            Text("对准人脸")
                .font(.headline.weight(.semibold))
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
