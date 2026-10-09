import AVFoundation
import SwiftUI
import UIKit

/// A scanned or typed bottle code, on its way to the bottle page.
struct BottleRoute: Hashable {
    let code: String
}

// The Scan page: point the camera at a bottle's QR code, or type the code in.
struct ScanView: View {
    private enum CameraState {
        case checking, ready, denied, unavailable
    }

    @Environment(Router.self) private var router
    /// true once a bottle page has been opened, so extra camera reads are ignored.
    @State private var hasOpened = false
    @State private var camera = CameraState.checking
    @State private var typedCode = ""
    @FocusState private var codeFieldFocused: Bool

    private let store = DataStore.shared
    private static var didPreview = false

    var body: some View {
        Group {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    cameraArea
                    manualEntry
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                hasOpened = false
                checkCamera()
                #if DEBUG
                // For testing: launch with "-previewBottle LW-MW-0001" to open a bottle page.
                if !Self.didPreview, let code = UserDefaults.standard.string(forKey: "previewBottle") {
                    Self.didPreview = true
                    open(store.bottleCode(fromScanned: code))
                }
                #endif
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scan a bottle")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .accessibilityAddTraits(.isHeader)
            Text("See the community and the ministry your bottle supported.")
                .font(.title3)
                .foregroundStyle(Theme.muted)
        }
    }

    // MARK: Camera

    private var cameraArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Theme.deep)

            switch camera {
            case .checking:
                ProgressView()
                    .tint(Theme.foreground)
            case .ready:
                QRScannerView { text in
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    open(store.bottleCode(fromScanned: text))
                }
                .accessibilityLabel("Camera. Point it at the QR code on your bottle.")
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.9), lineWidth: 3)
                    .padding(48)
                    .accessibilityHidden(true)
            case .denied:
                cameraMessage(
                    icon: "camera.fill",
                    title: "The camera is switched off",
                    body: "You can turn it on in Settings, or type the code from your bottle below.",
                    showSettings: true
                )
            case .unavailable:
                cameraMessage(
                    icon: "camera.fill",
                    title: "No camera here",
                    body: "This device doesn't have a camera. Type the code from your bottle below.",
                    showSettings: false
                )
            }
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.border))
    }

    private func cameraMessage(icon: String, title: String, body: String, showSettings: Bool) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.foreground)
            Text(body)
                .font(.body)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            if showSettings, let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings") {
                    UIApplication.shared.open(url)
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.brand)
                .frame(minHeight: 44)
            }
        }
        .padding(24)
    }

    /// Works out whether the camera can be used, asking permission the first time.
    private func checkCamera() {
        guard AVCaptureDevice.default(for: .video) != nil else {
            camera = .unavailable
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            camera = .ready
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    camera = granted ? .ready : .denied
                }
            }
        default:
            camera = .denied
        }
    }

    // MARK: Typing the code

    private var manualEntry: some View {
        Card {
            Text("Or type the code")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .accessibilityAddTraits(.isHeader)
            Text("It's printed on the label next to the QR code.")
                .font(.body)
                .foregroundStyle(Theme.muted)

            TextField(
                "Bottle code",
                text: $typedCode,
                prompt: Text("LW-MW-0001").foregroundStyle(Theme.muted.opacity(0.6))
            )
            .font(.title3.monospaced())
            .foregroundStyle(Theme.foreground)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .submitLabel(.go)
            .focused($codeFieldFocused)
            .onSubmit(submitTypedCode)
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(Theme.deep, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))

            Button("Find my bottle", action: submitTypedCode)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(typedCode.trimmingCharacters(in: .whitespaces).isEmpty)

            #if DEBUG
            // Only shown while building the app, so there is a code to test with.
            HStack {
                Text("Sample code to try: LW-MW-0001")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                Spacer()
                SampleBadge()
            }
            #endif
        }
    }

    private func submitTypedCode() {
        let code = store.bottleCode(fromScanned: typedCode)
        guard !code.isEmpty else { return }
        codeFieldFocused = false
        open(code)
    }

    private func open(_ code: String) {
        // Ignore extra reads while a bottle page is already showing.
        guard !hasOpened else { return }
        hasOpened = true
        router.path.append(BottleRoute(code: code))
    }
}

#Preview {
    ScanView()
        .environment(Router())
}
