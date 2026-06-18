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
    private let volumeChangeThreshold: Float = 0.01
    private let maxSliderLookupAttempts = 8
    private let audioSession = AVAudioSession.sharedInstance()
    private let volumeView = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    private weak var volumeSlider: UISlider?
    private var outputVolumeObservation: NSKeyValueObservation?
    private var lastObservedVolume: Float?
    private var isResettingVolume = false
    private var sliderLookupAttempts = 0

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

    override func didMoveToWindow() {
        super.didMoveToWindow()
        prepareVolumeSliderIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        volumeView.frame = bounds
        prepareVolumeSliderIfNeeded()
    }

    func start() {
        // .playback 让硬件音量键稳定控制媒体音量（outputVolume），KVO 才会触发；
        // .mixWithOthers 不打断他人音频。本 App 不播放音频，故忽略静音开关无实际影响。
        try? audioSession.setCategory(.playback, options: [.mixWithOthers])
        try? audioSession.setActive(true)

        lastObservedVolume = audioSession.outputVolume
        prepareVolumeSliderIfNeeded()

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

        guard abs(volume - previousVolume) > volumeChangeThreshold else {
            return
        }

        if isResettingVolume, abs(volume - targetVolume) <= volumeChangeThreshold {
            lastObservedVolume = volume
            isResettingVolume = false
            return
        }

        lastObservedVolume = volume

        if volume > previousVolume {
            onVolumeUp()
        } else {
            onVolumeDown()
        }

        resetSystemVolume()
    }

    private func prepareVolumeSliderIfNeeded() {
        guard volumeSlider == nil else {
            return
        }

        volumeSlider = volumeView.subviews.compactMap { $0 as? UISlider }.first

        if volumeSlider != nil {
            sliderLookupAttempts = 0
            resetSystemVolume()
            return
        }

        guard window != nil, sliderLookupAttempts < maxSliderLookupAttempts else {
            return
        }

        sliderLookupAttempts += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.prepareVolumeSliderIfNeeded()
        }
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
