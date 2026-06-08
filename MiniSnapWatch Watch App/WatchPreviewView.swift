import SwiftUI

struct WatchPreviewView: View {
    @ObservedObject var receiver: WatchPreviewReceiver

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let previewImage = receiver.previewImage {
                Image(decorative: previewImage, scale: 1)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                Text(receiver.statusText)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
            }

            VStack {
                Spacer()
                Text(receiver.statusText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.45), in: Capsule())
                    .padding(.bottom, 4)
            }
        }
    }
}
