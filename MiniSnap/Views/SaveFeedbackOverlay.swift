import SwiftUI

struct SaveFeedbackOverlay: View {
    let saveStatusText: String?
    let isSavingPhoto: Bool

    var body: some View {
        VStack(spacing: 10) {
            if isSavingPhoto {
                ProgressView()
                    .tint(.white)
            } else {
                Image(systemName: saveStatusText?.hasPrefix("保存失败") == true ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(saveStatusText?.hasPrefix("保存失败") == true ? .orange : .green)
                    .symbolEffect(.bounce, value: saveStatusText)
            }

            Text(saveStatusText ?? "正在保存")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
    }
}
