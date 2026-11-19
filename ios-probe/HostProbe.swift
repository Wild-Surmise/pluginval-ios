import AVFAudio
import AudioToolbox
import CoreAudioKit
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {}

@objc(PluginvalProbeSceneDelegate)
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let host = HostViewController()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = host
        self.window = window
        window.makeKeyAndVisible()
        host.run(arguments: Array(ProcessInfo.processInfo.arguments.dropFirst()))
    }
}

final class HostViewController: UIViewController {
    private var audioUnit: AVAudioUnit?
    private let status = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        status.numberOfLines = 0
        status.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(status)
        NSLayoutConstraint.activate([
            status.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            status.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            status.widthAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.9),
        ])
    }

    func run(arguments: [String]) {
        guard arguments.count == 3 else {
            report(error: "Pass the component type, subtype, and manufacturer as three FourCC values.")
            return
        }
        let codes = arguments.compactMap { value -> OSType? in
            let bytes = value.utf8
            guard bytes.count == 4, bytes.allSatisfy({ $0 < 128 }) else { return nil }
            return bytes.reduce(0) { ($0 << 8) | OSType($1) }
        }
        guard codes.count == 3 else {
            report(error: "Expected three ASCII FourCC values.")
            return
        }
        var description = AudioComponentDescription(
            componentType: codes[0], componentSubType: codes[1], componentManufacturer: codes[2],
            componentFlags: 0, componentFlagsMask: 0
        )
        guard AudioComponentFindNext(nil, &description) != nil else {
            report(error: "Component \(arguments.joined(separator: ", ")) is absent from the system registry.")
            return
        }
        status.text = "Opening \(arguments[1]) out of process…"
        AVAudioUnit.instantiate(with: description, options: .loadOutOfProcess) { [weak self] unit, error in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let unit else {
                    self.report(error: error?.localizedDescription ?? "AVAudioUnit instantiation returned nil.")
                    return
                }
                self.audioUnit = unit
                self.status.text = "Loaded \(unit.name) out of process. Requesting its editor…"
                unit.auAudioUnit.requestViewController { [weak self] editor in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        guard let editor else {
                            self.report(error: "\(unit.name) returned no editor view controller.")
                            return
                        }
                        self.addChild(editor)
                        editor.view.frame = self.view.bounds
                        editor.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                        self.view.addSubview(editor.view)
                        editor.didMove(toParent: self)
                        self.report(name: unit.name)
                    }
                }
            }
        }
    }

    private func report(name: String? = nil, error: String? = nil) {
        let report: [String: Any] = ["passed": error == nil, "name": name ?? "", "error": error ?? ""]
        do {
            let payload = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
            let documents = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                                        appropriateFor: nil, create: true)
            try payload.write(to: documents.appendingPathComponent("probe-result.json"), options: .atomic)
        } catch {
            status.text = error.localizedDescription
            return
        }
        if let error { status.text = error }
    }
}
