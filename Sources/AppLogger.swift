import SwiftUI
import Foundation
import UIKit
import StoreKit

// MARK: - Simple Universal Foreground Logger with App Review
class SimpleForegroundLogger: ObservableObject {

  // MARK: - Configuration
  struct Config {
    static let batchSize = 5
    static let enableDebugLogs = true
    static let reviewPromptInterval = 3 // Show review every 3rd launch
  }

  // MARK: - Properties
  @Published var isInForeground: Bool = true
  @Published var shouldShowReviewAlert: Bool = false
  private var pendingLogs: [LogEntry] = []
  private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
  private let appId: String  // New parameter
  private let serverURL: String

  // Launch counter
  private var launchNumber: Int = 0
  private var userId : String = ""
  private var uniqueInstallId : String = ""

  // Review tracking
  private var hasRequestedReviewForCurrentVersion: Bool = false
  private var lastReviewRequestLaunch: Int = 0

  // Device and system information
  private let languageCode = Locale.current.language.languageCode?.identifier ?? "unknown"
  private let os = UIDevice.current.systemName
  private let osVersion = UIDevice.current.systemVersion

  // MARK: - Singleton with Parameter Support
  private static var instance: SimpleForegroundLogger?

  static func initialize() -> SimpleForegroundLogger {
    if instance == nil {
      instance = SimpleForegroundLogger()
    }
    return instance!
  }

  // Fallback shared instance
  static var shared: SimpleForegroundLogger {
    return instance ?? SimpleForegroundLogger()
  }

  // MARK: - Log Entry Model (Updated)
  private struct LogEntry: Codable {
    let appId: String
    let uniqueIdentifier: String
    let userIdentifier: String
    let launchNumber: Int
    let os: String
    let osVersion: String
    let appVersion: String
  }

  // MARK: - Initialization
  private init() {
    self.appId = AppConstants.appId
    self.serverURL = "\(AppConstants.baseUrl)/analytics/log"
    // Load launch number from UserDefaults
    loadLaunchNumber()
    loadReviewData()

    setupSimpleDetection()

    debugLog("🚀 SimpleForegroundLogger initialized with app_id: \(appId)")
    debugLog("🔢 Launch number: \(launchNumber)")
  }

  // MARK: - Simple Detection Setup
  private func setupSimpleDetection() {
    debugLog("🔄 Setting up simple detection...")

    // System notifications (most reliable)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appWillEnterForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )

    // Scene notifications for iOS 13+
    if #available(iOS 13.0, *) {
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(sceneDidEnterBackground),
        name: UIScene.didEnterBackgroundNotification,
        object: nil
      )

      NotificationCenter.default.addObserver(
        self,
        selector: #selector(sceneWillEnterForeground),
        name: UIScene.willEnterForegroundNotification,
        object: nil
      )
    }

    debugLog("✅ Simple detection setup complete")
  }

  // MARK: - Event Handlers
  @objc private func appDidEnterBackground() {
    debugLog("🌙 App entered background")
    isInForeground = false
    //    logEvent("background")
    //    syncNow()
  }

  @objc private func appWillEnterForeground() {
    debugLog("📱 App entering foreground")
    isInForeground = true

    // Increment launch number
    launchNumber += 1
    saveLaunchNumber()

    debugLog("🔢 Launch number incremented to: \(launchNumber)")
    logEvent("foreground")

    // Check if we should show review prompt
    checkForReviewPrompt()
  }

  @objc private func appDidBecomeActive() {
    debugLog("✅ App became active")
    //    logEvent("active")
  }

  @available(iOS 13.0, *)
  @objc private func sceneDidEnterBackground() {
    debugLog("🌙 Scene entered background")
    isInForeground = false
    //    logEvent("scene_background")
    //    syncNow()
  }

  @available(iOS 13.0, *)
  @objc private func sceneWillEnterForeground() {
    debugLog("📱 Scene entering foreground")
    isInForeground = true
    //    logEvent("scene_foreground")
  }

  // MARK: - Review Logic
  private func checkForReviewPrompt() {
    debugLog("🎭 Checking review prompt conditions...")

    // Don't show on first launch
    if launchNumber <= 1 {
      debugLog("🎭 Skipping review: First launch")
      return
    }

    // Check if we've already requested for this version
    if hasRequestedReviewForCurrentVersion {
      debugLog("🎭 Skipping review: Already requested for version \(appVersion)")
      return
    }

    // Check if enough launches have passed since last request
    let launchesSinceLastRequest = launchNumber - lastReviewRequestLaunch
    if launchesSinceLastRequest < Config.reviewPromptInterval {
      debugLog("🎭 Skipping review: Only \(launchesSinceLastRequest) launches since last request")
      return
    }

    // Check if it's the right launch number (every 3rd launch)
    if launchNumber % Config.reviewPromptInterval == 0 {
      debugLog("🎭 ⭐ Triggering review prompt on launch \(launchNumber)")
      requestReview()
    } else {
      debugLog("🎭 Skipping review: Launch \(launchNumber) is not divisible by \(Config.reviewPromptInterval)")
    }
  }

  private func requestReview() {
    debugLog("⭐ Requesting app review...")

    // Update tracking data
    hasRequestedReviewForCurrentVersion = true
    lastReviewRequestLaunch = launchNumber
    saveReviewData()

    Task { @MainActor in
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            debugLog("⭐ No active window scene found")
            return
        }

        AppStore.requestReview(in: scene)
        debugLog("⭐ Review requested via AppStore.requestReview")
    }
}

  // MARK: - Public Review Methods
  func forceReviewPrompt() {
    debugLog("🎭 Force triggering review prompt")
    requestReview()
  }

  func resetReviewPrompt() {
    debugLog("🎭 Resetting review prompt data")
    hasRequestedReviewForCurrentVersion = false
    lastReviewRequestLaunch = 0
    saveReviewData()
  }

  // MARK: - Logging (Updated)
  private func logEvent(_ event: String) {
    let logEntry = LogEntry(
      appId: appId,
      uniqueIdentifier: uniqueInstallId,
      userIdentifier: userId,
      launchNumber: launchNumber,
      os: os,
      osVersion: osVersion,
      appVersion: appVersion
    )

    debugLog("📝 Logged: \(logEntry)")
    Task {
      await sendLog(logEntry)
    }
  }

  @MainActor
  private func sendLog(_ log: LogEntry) async {
    guard let url = URL(string: serverURL) else {
      debugLog("❌ Invalid server URL")
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type") // Changed to JSON
    request.timeoutInterval = 10.0

    // Prepare form data
    var formData: [String: Any] = [
      "app_id": appId,
      "uuid": uniqueInstallId,
      "launchnumber": launchNumber,
      "os": os,
      "osversion": osVersion,
      "appversion": appVersion
    ]

    if !userId.isEmpty {
      formData["uid"] = userId
    }

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: formData)

      let (_, response) = try await URLSession.shared.data(for: request)

      if let httpResponse = response as? HTTPURLResponse,
         httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
        debugLog("✅ Successfully sent log")
      } else {
        debugLog("❌ Server error")
      }
    } catch {
      debugLog("❌ Network error: \(error.localizedDescription)")
    }
  }

  // MARK: - Launch Number Persistence
  private func saveLaunchNumber() {
    UserDefaults.standard.set(launchNumber, forKey: "SimpleForegroundLogger.launchNumber")
  }

  private func loadLaunchNumber() {
    launchNumber = UserDefaults.standard.integer(forKey: "SimpleForegroundLogger.launchNumber")
    userId = UserDefaults.standard.string(forKey: "user_id") ?? ""
    uniqueInstallId = UserDefaults.standard.string(forKey: "SimpleForegroundLogger.installId") ?? ""
    if uniqueInstallId.isEmpty {
      uniqueInstallId = UUID().uuidString
      UserDefaults.standard.set(uniqueInstallId, forKey: "SimpleForegroundLogger.installId")
    }
    // If this is the first time, launchNumber will be 0
    if launchNumber == 0 {
      debugLog("📂 First launch detected")
    } else {
      debugLog("📂 Loaded launch number: \(launchNumber)")
    }
  }

  // MARK: - Review Data Persistence
  private func saveReviewData() {
    UserDefaults.standard.set(hasRequestedReviewForCurrentVersion, forKey: "SimpleForegroundLogger.reviewRequested.\(appVersion)")
    UserDefaults.standard.set(lastReviewRequestLaunch, forKey: "SimpleForegroundLogger.lastReviewLaunch")
  }

  private func loadReviewData() {
    hasRequestedReviewForCurrentVersion = UserDefaults.standard.bool(forKey: "SimpleForegroundLogger.reviewRequested.\(appVersion)")
    lastReviewRequestLaunch = UserDefaults.standard.integer(forKey: "SimpleForegroundLogger.lastReviewLaunch")

    debugLog("📂 Review data loaded - Requested for v\(appVersion): \(hasRequestedReviewForCurrentVersion), Last request: \(lastReviewRequestLaunch)")
  }

  // MARK: - Debug
  private func debugLog(_ message: String) {
    if Config.enableDebugLogs {
      print("[SimpleLogger] \(message)")
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}
// MARK: - Updated SwiftUI Integration
struct ForegroundLoggerView: View {
  @StateObject private var logger = SimpleForegroundLogger.initialize()

  var body: some View {
    EmptyView()
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
        // This ensures the logger is active
      }
  }
}

// MARK: - Updated View Extension
extension View {
  func withForegroundLogger() -> some View {
    self.onAppear {
      _ = SimpleForegroundLogger.initialize()
    }
    .background(ForegroundLoggerView())
  }
}

// MARK: - Updated AppDelegate Integration
extension NSObject {
  @objc func startForegroundLogger() {
    _ = SimpleForegroundLogger.initialize()
  }
}

