import SwiftUI

struct DistanceToolbar: View {
    @Binding var selectedPreset: SubjectDistancePreset
    let automaticDistanceAvailable: Bool
    let automaticDistance: Double?

    var body: some View {
        HStack(spacing: 10) {
            Label("距离", systemImage: "scope")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)

            if automaticDistanceAvailable, let automaticDistance {
                Text(String(format: "自动 %.1fm", automaticDistance))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.34), in: Capsule())
            } else {
                Picker("距离", selection: $selectedPreset) {
                    ForEach(SubjectDistancePreset.allCases) { preset in
                        Text(preset.localizedName).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 170)
            }

            Spacer()
        }
    }
}
