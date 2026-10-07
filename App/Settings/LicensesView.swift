import SwiftUI

/// A third-party package compiled into the app. Its license file is bundled from `App/Licenses/`,
/// copied verbatim from the version pinned in `Package.resolved`; NOTICES.md lists the same set.
struct ThirdPartyComponent: Identifiable {
    let name: String
    let purpose: String
    let source: URL
    /// Bundle resource name of the license file, without the `.txt` extension.
    let licenseResource: String

    var id: String { name }

    static let all: [ThirdPartyComponent] = [
        ThirdPartyComponent(
            name: "SelectedTextKit",
            purpose: "Selection capture",
            source: URL(string: "https://github.com/tisfeng/SelectedTextKit")!,
            licenseResource: "SelectedTextKit-LICENSE"
        ),
        ThirdPartyComponent(
            name: "AXSwift",
            purpose: "Accessibility API, via SelectedTextKit",
            source: URL(string: "https://github.com/tisfeng/AXSwift")!,
            licenseResource: "AXSwift-LICENSE"
        ),
        ThirdPartyComponent(
            name: "KeySender",
            purpose: "Synthetic key events, via SelectedTextKit",
            source: URL(string: "https://github.com/jordanbaird/KeySender")!,
            licenseResource: "KeySender-LICENSE"
        ),
        ThirdPartyComponent(
            name: "KeyboardShortcuts",
            purpose: "Global shortcuts and recorder",
            source: URL(string: "https://github.com/sindresorhus/KeyboardShortcuts")!,
            licenseResource: "KeyboardShortcuts-LICENSE"
        ),
    ]

    /// The bundled license text, or nil if the file is missing from the build. Some files hard-wrap
    /// at ~80 columns, so each paragraph's lines are joined to let it reflow to the sheet's width.
    var licenseText: String? {
        guard let url = Bundle.main.url(forResource: licenseResource, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n\n")
            .map { $0.split(separator: "\n").joined(separator: " ") }
            .joined(separator: "\n\n")
    }
}

/// Settings ▸ About ▸ Third-Party Licenses: every bundled package with its full license text.
struct LicensesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("SelectTTS is built with these open-source packages.")
                        .foregroundStyle(.secondary)
                    ForEach(ThirdPartyComponent.all) { component in
                        ComponentLicenseView(component: component)
                    }
                }
                .padding(20)
            }
            Divider()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 480, height: 460)
    }
}

private struct ComponentLicenseView: View {
    let component: ThirdPartyComponent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: component.name).font(.headline)
                Text(verbatim: component.purpose).font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Link("Source", destination: component.source).font(.footnote)
            }
            // Verbatim: a LocalizedStringKey would parse the text as Markdown.
            Text(verbatim: component.licenseText
                ?? "License text missing from this build; see \(component.source.absoluteString).")
                .font(.caption)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

#Preview {
    LicensesView()
}
