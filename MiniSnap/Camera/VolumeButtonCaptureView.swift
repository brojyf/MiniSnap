import AVFAudio
import MediaPlayer
import SwiftUI
import UIKit

struct VolumeButtonCaptureView: UIViewRepresentable {
    let onVolumeDown: () -> Void
    let onVolumeUp: () -> Void

    func makeUIView(context: Context) -> VolumeButtonCaptureUIView {
        let view = VolumeButtonCaptureUIView()
        view.onVolumeDown = onVolumeDown
        view.onVolumeUp = onVolumeUp
        view.start()
        return view
    }

    func updateUIView(_ uiView: VolumeButtonCaptureUIView, context: Context) {
        uiView.onVolumeDown = onVolumeDown
        uiView.onVolumeUp = onVolumeUp
    }

    static func dismantleUIView(_ uiView: VolumeButtonCaptureUIView, coordinator: ()) {
        uiView.stop()
    }
}

final class VolumeButtonCaptureUIView: UIView {
    private let targetVolume: Float = 0.5
    private let audioSession = AVAudioSession.sharedInstance()
    private let volumeView = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    private weak var volumeSlider: UISlider?
    private var outputVolumeObservation: NSKeyValueObservation?
    private var lastObservedVolume: Float?
    private var isResettingVolume = false

    var onVolumeDown: () -> Void = {}
    var onVolumeUp: () -> Void = {}

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        volumeView.alpha = 0.01
        addSubview(volumeView)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func start() {
        try? audioSession.setCategory(.ambient, options: [.mixWithOthers])
        try? audioSession.setActive(true)

        volumeSlider = volumeView.subviews.compactMap { $0 as? UISlider }.first
        lastObservedVolume = audioSession.outputVolume
        resetSystemVolume()

        outputVolumeObservation = audioSession.observe(\.outputVolume, options: [.new]) { [weak self] audioSession, _ in
            DispatchQueue.main.async {
                self?.handleVolumeChange(audioSession.outputVolume)
            }
        }
    }

    func stop() {
        outputVolumeObservation = nil
    }

    private func handleVolumeChange(_ volume: Float) {
        guard let previousVolume = lastObservedVolume else {
            lastObservedVolume = volume
            return
        }

        guard abs(volume - previousVolume) > 0.01 else {
            return
        }

        lastObservedVolume = volume

        guard !isResettingVolume else {
            return
        }

        if volume > previousVolume {
            onVolumeUp()
        } else {
            onVolumeDown()
        }

        resetSystemVolume()
    }

    private func resetSystemVolume() {
        guard let volumeSlider else {
            return
        }

        isResettingVolume = true
        volumeSlider.setValue(targetVolume, animated: false)
        volumeSlider.sendActions(for: .valueChanged)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            lastObservedVolume = audioSession.outputVolume
            isResettingVolume = false
        }
    }
}
