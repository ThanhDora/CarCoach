//
//  VisionSignScannerView.swift
//  CarCoach
//

import AVFoundation
import Foundation
import PhotosUI
import SwiftUI
import UIKit

enum VisionScannerSourceMode: String, CaseIterable, Identifiable {
    case camera
    case library
    case simulatorSamples

    var id: String { rawValue }

    var title: String {
        switch self {
        case .camera: return "Camera"
        case .library: return "Thư viện"
        case .simulatorSamples: return "Biển mẫu"
        }
    }

    var systemImage: String {
        switch self {
        case .camera: return "camera.viewfinder"
        case .library: return "photo.on.rectangle"
        case .simulatorSamples: return "square.grid.2x2"
        }
    }
}

nonisolated final class CameraSessionController: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.dora.carcoach.camera.session")
    private var isConfigured = false
    private var pendingContinuation: CheckedContinuation<Data?, Never>?

    var isHardwareAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
            || AVCaptureDevice.default(for: .video) != nil
    }

    func startIfAuthorized() {
        guard isHardwareAvailable else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
            if self.isConfigured && !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            if let continuation = self.pendingContinuation {
                self.pendingContinuation = nil
                continuation.resume(returning: nil)
            }
        }
    }

    func capturePhotoData() async -> Data? {
        guard isHardwareAvailable else { return nil }
        return await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }
                self.configureIfNeeded()
                guard self.isConfigured, self.session.isRunning else {
                    continuation.resume(returning: nil)
                    return
                }
                if let existing = self.pendingContinuation {
                    self.pendingContinuation = nil
                    existing.resume(returning: nil)
                }
                self.pendingContinuation = continuation
                let settings = AVCapturePhotoSettings()
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()
        isConfigured = true
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        let imageData: Data? = error == nil ? photo.fileDataRepresentation() : nil
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let continuation = self.pendingContinuation
            self.pendingContinuation = nil
            continuation?.resume(returning: imageData)
        }
    }
}

private final class CameraPreviewContainerView: UIView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewContainerView {
        let view = CameraPreviewContainerView()
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewContainerView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
        uiView.previewLayer.frame = uiView.bounds
    }
}

struct VisionSignScannerView: View {
    let repository: CarCoachRepository
    let storeManager: StoreKitManager
    let onPresentPaywall: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var recognizer = VisionSignRecognizer()
    @State private var cameraController = CameraSessionController()
    @State private var sourceMode: VisionScannerSourceMode
    @State private var cameraAuthStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var activeSampleCode: String?
    @State private var isCapturingPhoto = false

    init(
        repository: CarCoachRepository,
        storeManager: StoreKitManager,
        onPresentPaywall: @escaping () -> Void
    ) {
        self.repository = repository
        self.storeManager = storeManager
        self.onPresentPaywall = onPresentPaywall

        let hasCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
            || AVCaptureDevice.default(for: .video) != nil
        _sourceMode = State(initialValue: hasCamera ? .camera : .simulatorSamples)
    }

    private var curatedSampleSigns: [TrafficSign] {
        let preferredCodes = ["P.102", "P.127", "R.122", "P.123a", "W.201a", "W.208", "R.301a", "I.408"]
        var picked: [TrafficSign] = []
        for code in preferredCodes {
            if let sign = repository.signs.first(where: { $0.code.caseInsensitiveCompare(code) == .orderedSame }) {
                picked.append(sign)
            }
        }
        if picked.count < 6 {
            for category in TrafficSignCategory.allCases {
                if let candidate = repository.signs(in: category).first,
                   !picked.contains(where: { $0.id == candidate.id }) {
                    picked.append(candidate)
                }
            }
        }
        return Array(picked.prefix(8))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClaudeSpacing.lg) {
                headerSection
                sourcePickerBar
                inputSourceCard
                if let previewImage {
                    analyzedPreviewCard(image: previewImage)
                }
                if recognizer.isAnalyzing {
                    analyzingCard
                } else if let error = recognizer.errorMessage {
                    errorCard(message: error)
                } else if !recognizer.matches.isEmpty {
                    resultsSection
                }
                disclaimerFooter
            }
            .padding(.horizontal, ClaudeSpacing.md)
            .padding(.vertical, ClaudeSpacing.md)
        }
        .background(ClaudePalette.canvas.ignoresSafeArea())
        .navigationTitle("Nhận diện biển báo")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
            if sourceMode == .camera && cameraAuthStatus == .authorized {
                cameraController.startIfAuthorized()
            }
        }
        .onDisappear {
            cameraController.stop()
        }
        .onChange(of: sourceMode) { _, newMode in
            if newMode == .camera && cameraAuthStatus == .authorized {
                cameraController.startIfAuthorized()
            } else {
                cameraController.stop()
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await handlePickedPhoto(newItem)
            }
        }
    }

    private var headerSection: some View {
        ClaudeSectionHeader(
            eyebrow: "APPLE VISION • ON-DEVICE",
            title: "Quét biển báo giao thông",
            subtitle: "Phân tích hình khối, màu sắc HSV và ký tự tốc độ trực tiếp trên thiết bị, đối chiếu tức thì với kho QCVN 41:2019."
        )
    }

    private var sourcePickerBar: some View {
        HStack(spacing: ClaudeSpacing.xs) {
            ForEach(VisionScannerSourceMode.allCases) { mode in
                let isSelected = sourceMode == mode
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        sourceMode = mode
                    }
                } label: {
                    HStack(spacing: ClaudeSpacing.xxs) {
                        Image(systemName: mode.systemImage)
                            .font(.system(size: 13, weight: .medium))
                        Text(mode.title)
                            .font(ClaudeTypography.nav)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .foregroundStyle(isSelected ? ClaudePalette.canvas : ClaudePalette.inkPrimary)
                    .background(
                        RoundedRectangle(cornerRadius: ClaudeRadius.md)
                            .fill(isSelected ? ClaudePalette.ink : ClaudePalette.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ClaudeRadius.md)
                            .stroke(isSelected ? ClaudePalette.ink : ClaudePalette.hairline, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var inputSourceCard: some View {
        switch sourceMode {
        case .camera:
            cameraSourceCard
        case .library:
            photoLibrarySourceCard
        case .simulatorSamples:
            simulatorSampleSourceCard
        }
    }

    @ViewBuilder
    private var cameraSourceCard: some View {
        if !cameraController.isHardwareAvailable {
            VStack(alignment: .leading, spacing: ClaudeSpacing.md) {
                HStack(spacing: ClaudeSpacing.sm) {
                    Image(systemName: "camera.metering.unknown")
                        .font(.system(size: 22))
                        .foregroundStyle(ClaudePalette.inkPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Camera chưa khả dụng trên Simulator")
                            .font(ClaudeTypography.bodyMD.weight(.medium))
                            .foregroundStyle(ClaudePalette.ink)
                        Text("Thiết bị mô phỏng không có cảm biến camera vật lý. Hãy chọn ảnh từ thư viện hoặc dùng ảnh PNG biển báo mẫu bên dưới để kiểm thử Vision.")
                            .font(ClaudeTypography.bodySM)
                            .foregroundStyle(ClaudePalette.textMuted)
                    }
                }

                HStack(spacing: ClaudeSpacing.sm) {
                    Button("Thử biển mẫu ngay") {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            sourceMode = .simulatorSamples
                        }
                    }
                    .buttonStyle(ClaudePrimaryButtonStyle())

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Text("Chọn ảnh")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClaudeSecondaryButtonStyle())
                }
            }
            .claudeCompactCard(padding: ClaudeSpacing.lg)
        } else {
            switch cameraAuthStatus {
            case .authorized:
                VStack(spacing: ClaudeSpacing.md) {
                    ZStack {
                        CameraPreviewView(session: cameraController.session)
                            .frame(height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: ClaudeRadius.cardCompact))

                        RoundedRectangle(cornerRadius: ClaudeRadius.cardCompact)
                            .stroke(Color.white.opacity(0.65), style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                            .frame(width: 170, height: 170)

                        VStack {
                            Spacer()
                            Text("Đưa biển báo vào khung ngắm")
                                .font(ClaudeTypography.captionXS)
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, ClaudeSpacing.sm)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.black.opacity(0.6)))
                                .padding(.bottom, ClaudeSpacing.sm)
                        }
                    }

                    Button {
                        Task {
                            await captureAndAnalyzeFromCamera()
                        }
                    } label: {
                        HStack(spacing: ClaudeSpacing.xs) {
                            Image(systemName: isCapturingPhoto ? "hourglass" : "viewfinder")
                            Text(isCapturingPhoto ? "Đang chụp & nhận diện..." : "Chụp và phân tích biển báo")
                        }
                    }
                    .buttonStyle(ClaudePrimaryButtonStyle())
                    .disabled(isCapturingPhoto || recognizer.isAnalyzing)
                }
                .claudeCompactCard(padding: ClaudeSpacing.md)

            case .notDetermined:
                VStack(alignment: .leading, spacing: ClaudeSpacing.md) {
                    Text("Cấp quyền Camera")
                        .font(ClaudeTypography.headingSerifSM)
                        .foregroundStyle(ClaudePalette.ink)
                    Text("CarCoach xử lý hình ảnh hoàn toàn trên thiết bị bằng Apple Vision và không tải ảnh lên máy chủ.")
                        .font(ClaudeTypography.bodySM)
                        .foregroundStyle(ClaudePalette.textMuted)
                    Button("Cho phép sử dụng Camera") {
                        Task {
                            let granted = await AVCaptureDevice.requestAccess(for: .video)
                            cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
                            if granted {
                                cameraController.startIfAuthorized()
                            }
                        }
                    }
                    .buttonStyle(ClaudePrimaryButtonStyle())
                }
                .claudeCompactCard(padding: ClaudeSpacing.lg)

            case .denied, .restricted:
                VStack(alignment: .leading, spacing: ClaudeSpacing.md) {
                    Text("Quyền Camera đang bị tắt")
                        .font(ClaudeTypography.headingSerifSM)
                        .foregroundStyle(ClaudePalette.ink)
                    Text("Bạn có thể bật lại quyền Camera trong Cài đặt iOS, hoặc chuyển sang chọn ảnh từ Thư viện / Biển mẫu.")
                        .font(ClaudeTypography.bodySM)
                        .foregroundStyle(ClaudePalette.textMuted)
                    HStack(spacing: ClaudeSpacing.sm) {
                        Button("Mở Cài đặt") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(ClaudePrimaryButtonStyle())

                        Button("Dùng biển mẫu") {
                            sourceMode = .simulatorSamples
                        }
                        .buttonStyle(ClaudeSecondaryButtonStyle())
                    }
                }
                .claudeCompactCard(padding: ClaudeSpacing.lg)

            @unknown default:
                EmptyView()
            }
        }
    }

    private var photoLibrarySourceCard: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.md) {
            HStack(spacing: ClaudeSpacing.sm) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 22))
                    .foregroundStyle(ClaudePalette.inkPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chọn ảnh chụp biển báo")
                        .font(ClaudeTypography.bodyMD.weight(.medium))
                        .foregroundStyle(ClaudePalette.ink)
                    Text("Hỗ trợ ảnh chụp ngoài đường hoặc ảnh chụp màn hình biển báo rõ nét.")
                        .font(ClaudeTypography.bodySM)
                        .foregroundStyle(ClaudePalette.textMuted)
                }
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: ClaudeSpacing.xs) {
                    Image(systemName: "photo.badge.plus")
                    Text("Chọn ảnh từ Thư viện")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ClaudePrimaryButtonStyle())
        }
        .claudeCompactCard(padding: ClaudeSpacing.lg)
    }

    private var simulatorSampleSourceCard: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.md) {
            VStack(alignment: .leading, spacing: ClaudeSpacing.xxs) {
                Text("Thử nhanh biển báo mẫu")
                    .font(ClaudeTypography.headingSerifSM)
                    .foregroundStyle(ClaudePalette.ink)
                Text("Chạm vào một biển báo để xuất thành ảnh PNG thật và chạy qua pipeline Apple Vision (`VNRecognizeTextRequest` + `VNDetectRectanglesRequest` + HSV).")
                    .font(ClaudeTypography.bodySM)
                    .foregroundStyle(ClaudePalette.textMuted)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: ClaudeSpacing.sm),
                    GridItem(.flexible(), spacing: ClaudeSpacing.sm)
                ],
                spacing: ClaudeSpacing.sm
            ) {
                ForEach(curatedSampleSigns) { sign in
                    let isActive = activeSampleCode == sign.code
                    Button {
                        Task {
                            await runSampleSign(sign)
                        }
                    } label: {
                        HStack(spacing: ClaudeSpacing.sm) {
                            DiagramCanvasView(spec: sign.diagram, size: 48)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sign.code)
                                    .font(ClaudeTypography.captionXS.weight(.semibold))
                                    .foregroundStyle(ClaudePalette.textMuted)
                                Text(sign.name)
                                    .font(ClaudeTypography.bodyXS.weight(.medium))
                                    .foregroundStyle(ClaudePalette.ink)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                        .claudeSurfaceRow(isSelected: isActive)
                    }
                    .buttonStyle(.plain)
                    .disabled(recognizer.isAnalyzing)
                }
            }
        }
        .claudeCompactCard(padding: ClaudeSpacing.md)
    }

    private func analyzedPreviewCard(image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.md) {
            HStack(alignment: .top, spacing: ClaudeSpacing.md) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .background(ClaudePalette.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: ClaudeRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: ClaudeRadius.md)
                            .stroke(ClaudePalette.hairline, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: ClaudeSpacing.xs) {
                    Text("Ảnh đang phân tích")
                        .font(ClaudeTypography.bodyMD.weight(.medium))
                        .foregroundStyle(ClaudePalette.ink)

                    if let summary = recognizer.lastSummary {
                        HStack(spacing: ClaudeSpacing.xs) {
                            ClaudeBadge(
                                text: "\(summary.processingTimeMs) ms",
                                tone: .neutral
                            )
                            if let category = summary.inferredCategory {
                                ClaudeBadge(
                                    text: category.vietnameseTitle,
                                    tone: .dark
                                )
                            }
                        }

                        Text("Hình khối: \(summary.shapeLabel) • Màu: \(summary.dominantColorText)")
                            .font(ClaudeTypography.bodyXS)
                            .foregroundStyle(ClaudePalette.textMuted)

                        if !summary.recognizedTexts.isEmpty {
                            Text("Ký tự OCR: \(summary.recognizedTexts.joined(separator: ", "))")
                                .font(ClaudeTypography.bodyXS.weight(.medium))
                                .foregroundStyle(ClaudePalette.inkPrimary)
                        }
                    } else {
                        Text("Đang trích xuất đặc trưng...")
                            .font(ClaudeTypography.bodySM)
                            .foregroundStyle(ClaudePalette.textMuted)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .claudeCompactCard(padding: ClaudeSpacing.md)
    }

    private var analyzingCard: some View {
        HStack(spacing: ClaudeSpacing.md) {
            ProgressView()
                .tint(ClaudePalette.ink)
            VStack(alignment: .leading, spacing: 2) {
                Text("Đang nhận diện bằng Vision...")
                    .font(ClaudeTypography.bodyMD.weight(.medium))
                    .foregroundStyle(ClaudePalette.ink)
                Text("Chạy OCR ký tự, hình khối và phân tích phổ màu HSV.")
                    .font(ClaudeTypography.bodySM)
                    .foregroundStyle(ClaudePalette.textMuted)
            }
            Spacer()
        }
        .claudeCompactCard(padding: ClaudeSpacing.lg)
    }

    private func errorCard(message: String) -> some View {
        HStack(spacing: ClaudeSpacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(ClaudePalette.wrong)
            Text(message)
                .font(ClaudeTypography.bodySM)
                .foregroundStyle(ClaudePalette.inkPrimary)
            Spacer()
        }
        .claudeCompactCard(padding: ClaudeSpacing.md)
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            HStack {
                Text("KẾT QUẢ ĐỐI CHIẾU PHÙ HỢP NHẤT")
                    .font(ClaudeTypography.headingSM)
                    .foregroundStyle(ClaudePalette.textMuted)
                Spacer()
                if let top = recognizer.matches.first {
                    ClaudeBadge(
                        text: "Độ khớp \(top.confidencePercent)%",
                        tone: top.confidence >= 0.70 ? .correct : .neutral
                    )
                }
            }

            ForEach(Array(recognizer.matches.enumerated()), id: \.element.id) { index, match in
                NavigationLink {
                    TrafficSignDetailView(
                        sign: match.sign,
                        repository: repository,
                        storeManager: storeManager,
                        onPresentPaywall: onPresentPaywall
                    )
                } label: {
                    matchRow(match: match, isTopResult: index == 0)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func matchRow(match: VisionSignMatch, isTopResult: Bool) -> some View {
        VStack(alignment: .leading, spacing: ClaudeSpacing.sm) {
            HStack(alignment: .center, spacing: ClaudeSpacing.md) {
                DiagramCanvasView(spec: match.sign.diagram, size: isTopResult ? 72 : 56)

                VStack(alignment: .leading, spacing: ClaudeSpacing.xxs) {
                    HStack(spacing: ClaudeSpacing.xs) {
                        ClaudeBadge(
                            text: match.sign.code,
                            tone: isTopResult ? .dark : .neutral
                        )
                        Text(match.sign.category.vietnameseTitle)
                            .font(ClaudeTypography.captionXS)
                            .foregroundStyle(ClaudePalette.textMuted)
                        Spacer()
                        Text("\(match.confidencePercent)%")
                            .font(ClaudeTypography.bodyMD.weight(.semibold))
                            .foregroundStyle(isTopResult ? ClaudePalette.correct : ClaudePalette.inkPrimary)
                    }

                    Text(match.sign.name)
                        .font(isTopResult ? ClaudeTypography.headingSerifSM : ClaudeTypography.bodyMD.weight(.medium))
                        .foregroundStyle(ClaudePalette.ink)
                        .multilineTextAlignment(.leading)

                    Text(match.sign.summary)
                        .font(ClaudeTypography.bodySM)
                        .foregroundStyle(ClaudePalette.textMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ClaudePalette.textMuted)
            }

            if !match.matchReasons.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ClaudeSpacing.xs) {
                        ForEach(match.matchReasons, id: \.self) { reason in
                            Text(reason)
                                .font(ClaudeTypography.captionXS)
                                .foregroundStyle(ClaudePalette.textMuted)
                                .padding(.horizontal, ClaudeSpacing.xs)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: ClaudeRadius.xs)
                                        .fill(ClaudePalette.surfaceRaised)
                                )
                        }
                    }
                }
            }
        }
        .claudeSurfaceRow(isSelected: isTopResult)
    }

    private var disclaimerFooter: some View {
        Text("Xử lý hoàn toàn ngoại tuyến trên thiết bị bằng Apple Vision. Khi tham gia giao thông thực tế, luôn quan sát biển báo trực tiếp và tuân thủ hiệu lệnh của người điều khiển giao thông.")
            .font(ClaudeTypography.captionXS)
            .foregroundStyle(ClaudePalette.textMuted)
            .padding(.top, ClaudeSpacing.xs)
    }

    private func captureAndAnalyzeFromCamera() async {
        isCapturingPhoto = true
        let imageData = await cameraController.capturePhotoData()
        isCapturingPhoto = false

        guard let imageData, let image = UIImage(data: imageData) else {
            recognizer.errorMessage = "Không chụp được khung hình từ Camera. Vui lòng thử lại."
            return
        }
        activeSampleCode = nil
        previewImage = image
        await recognizer.analyze(image: image, against: repository.signs)
    }

    private func handlePickedPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                recognizer.errorMessage = "Không đọc được ảnh đã chọn."
                return
            }
            activeSampleCode = nil
            previewImage = image
            await recognizer.analyze(image: image, against: repository.signs)
        } catch {
            recognizer.errorMessage = "Không thể tải ảnh từ thư viện: \(error.localizedDescription)"
        }
    }

    private func runSampleSign(_ sign: TrafficSign) async {
        activeSampleCode = sign.code
        guard let rendered = DiagramCanvasView.renderSignUIImage(spec: sign.diagram, dimension: 360),
              let pngData = rendered.pngData(),
              let pngImage = UIImage(data: pngData) else {
            recognizer.errorMessage = "Không tạo được ảnh PNG mẫu cho biển \(sign.code)."
            return
        }
        previewImage = pngImage
        await recognizer.analyze(image: pngImage, against: repository.signs)
    }
}
