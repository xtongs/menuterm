import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            section(title: "Window") {
                sliderRow(
                    title: "Window Width",
                    valueText: "\(Int(settings.windowWidth)) pt",
                    value: $settings.windowWidth,
                    range: AppSettings.minimumWindowWidth...AppSettings.maximumWindowWidth,
                    step: 10
                )

                sliderRow(
                    title: "Window Height",
                    valueText: "\(Int(settings.windowHeight)) pt",
                    value: $settings.windowHeight,
                    range: AppSettings.minimumWindowHeight...AppSettings.maximumWindowHeight,
                    step: 10
                )
            }

            section(title: "Terminal") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Font")
                        .font(.subheadline.weight(.semibold))

                    Picker("Font", selection: $settings.fontIdentifier) {
                        ForEach(settings.availableFontOptions) { option in
                            Text(option.displayName).tag(option.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                sliderRow(
                    title: "Font Size",
                    valueText: "\(Int(settings.fontSize)) pt",
                    value: $settings.fontSize,
                    range: AppSettings.minimumFontSize...AppSettings.maximumFontSize,
                    step: 1
                )
            }

            section(title: "General") {
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { settings.launchAtLoginEnabled },
                        set: { settings.setLaunchAtLogin($0) }
                    )
                )
                .toggleStyle(.switch)

                if let errorMessage = settings.launchAtLoginErrorMessage, errorMessage.isEmpty == false {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(20)
        .frame(width: 520, alignment: .topLeading)
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private func sliderRow(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(valueText)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: value, in: range, step: step)
        }
    }
}
