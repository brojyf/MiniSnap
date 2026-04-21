import Foundation

enum ExposureValue: String, CaseIterable, Identifiable {
    case lPlus = "L+"
    case l = "L"
    case n = "N"
    case d = "D"
    case dMinus = "D-"

    var id: String { rawValue }
}

enum FlashMode: String, CaseIterable, Identifiable {
    case fill = "Fill"
    case off = "Off"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .fill:
            "开"
        case .off:
            "关"
        }
    }
}

enum ShootingMode: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case indoor = "Indoor"
    case sports = "Sports"
    case doubleExposure = "Double Exposure"
    case bulb = "Bulb"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .normal:
            "普通"
        case .indoor:
            "室内"
        case .sports:
            "运动"
        case .doubleExposure:
            "双重曝光"
        case .bulb:
            "B 门"
        }
    }
}

enum Mini99FocusMode: String, CaseIterable, Identifiable {
    case macro = "Macro"
    case standard = "Standard"
    case landscape = "Landscape"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .macro:
            "近摄"
        case .standard:
            "标准"
        case .landscape:
            "远景"
        }
    }

    var rangeText: String {
        switch self {
        case .macro:
            "0.3-0.6m"
        case .standard:
            "0.6-3m"
        case .landscape:
            "3m 到无穷"
        }
    }

    static func recommended(for distance: Double) -> Mini99FocusMode {
        if distance < 0.6 {
            return .macro
        }

        if distance <= 3.0 {
            return .standard
        }

        return .landscape
    }
}

struct ExposureControl: Equatable {
    let shootingMode: ShootingMode
    let focusMode: Mini99FocusMode
    let ev: ExposureValue
    let flash: FlashMode
}

struct ExposureInput: Equatable {
    let faceLuma: Double
    let sceneLuma: Double
    let highlightRatio: Double
    let faceAreaRatio: Double
    let distance: Double
}

struct ExposureRecommendation: Equatable {
    let control: ExposureControl
    let confidence: Double
    let reasons: [String]
    let warnings: [String]
}

enum ExposureAdvisor {
    static func decide(_ input: ExposureInput) -> ExposureRecommendation {
        let faceSceneDelta = input.faceLuma - input.sceneLuma
        let lowLight = input.sceneLuma < 0.25
        let veryLowLight = input.sceneLuma < 0.12
        let backlit = faceSceneDelta < -0.12 && input.highlightRatio > 0.1
        let faceDark = input.faceLuma < 0.35
        let highContrast = input.highlightRatio > 0.2
        let focusMode = Mini99FocusMode.recommended(for: input.distance)

        let control: ExposureControl
        var reasons: [String] = []

        if backlit {
            reasons.append("检测到逆光")
            reasons.append("人脸亮度低于背景")
            reasons.append("开启补光闪光优于提高曝光")

            if input.sceneLuma > 0.6 {
                control = ExposureControl(shootingMode: .normal, focusMode: focusMode, ev: .dMinus, flash: .fill)
            } else {
                control = ExposureControl(shootingMode: .normal, focusMode: focusMode, ev: .d, flash: .fill)
            }
        } else if lowLight {
            reasons.append("环境亮度较低")

            if veryLowLight && input.distance > 2.7 {
                reasons.append("环境过暗且主体超过闪光有效距离")
                reasons.append("B 门比闪光更适合保留夜景背景")
                control = ExposureControl(shootingMode: .bulb, focusMode: focusMode, ev: .l, flash: .off)
            } else if input.distance <= 2.7 {
                reasons.append("主体在闪光有效距离内")
                reasons.append("室内模式可提亮暗处背景")
                control = ExposureControl(shootingMode: .indoor, focusMode: focusMode, ev: .l, flash: .fill)
            } else {
                reasons.append("距离较远，闪光效果有限")
                reasons.append("室内模式可提亮暗处背景")
                control = ExposureControl(shootingMode: .indoor, focusMode: focusMode, ev: .l, flash: .off)
            }
        } else if faceDark {
            reasons.append("人脸偏暗")
            reasons.append("优先提高人脸曝光")
            control = ExposureControl(shootingMode: .normal, focusMode: focusMode, ev: .l, flash: input.distance <= 2.7 ? .fill : .off)
        } else if input.sceneLuma > 0.7 && highContrast {
            reasons.append("环境高亮且对比强")
            reasons.append("降低曝光以保护背景高光")
            control = ExposureControl(shootingMode: .normal, focusMode: focusMode, ev: .dMinus, flash: .off)
        } else {
            reasons.append("人脸与背景亮度平衡")
            control = ExposureControl(shootingMode: .normal, focusMode: focusMode, ev: .n, flash: .off)
        }

        reasons.append("镜头环建议设为\(focusMode.localizedName)")

        return ExposureRecommendation(
            control: control,
            confidence: confidence(for: input, backlit: backlit, lowLight: lowLight, faceDark: faceDark, highContrast: highContrast),
            reasons: reasons,
            warnings: warnings(for: input)
        )
    }

    private static func confidence(
        for input: ExposureInput,
        backlit: Bool,
        lowLight: Bool,
        faceDark: Bool,
        highContrast: Bool
    ) -> Double {
        var score = 0.62

        if input.faceAreaRatio > 0.01 {
            score += 0.08
        }

        if backlit {
            score += 0.18
        } else if lowLight || faceDark || highContrast {
            score += 0.12
        } else {
            score += 0.06
        }

        if input.highlightRatio > 0.25 {
            score -= 0.04
        }

        if input.distance > 2.7 {
            score -= 0.08
        }

        return min(max(score, 0.45), 0.96)
    }

    private static func warnings(for input: ExposureInput) -> [String] {
        var warnings: [String] = []

        if input.faceLuma < 0.3 {
            warnings.append("人脸可能仍然偏暗")
        }

        if input.highlightRatio > 0.25 {
            warnings.append("背景高光有过曝风险")
        }

        if input.distance > 2.7 {
            warnings.append("超过 2.7 米，闪光可能无效")
        }

        if input.distance < 0.3 {
            warnings.append("低于 0.3 米，Mini 99 可能无法合焦")
        }

        if input.sceneLuma < 0.12 && input.distance > 2.7 {
            warnings.append("B 门需要桌面或三脚架稳定相机")
        }

        return warnings
    }
}
