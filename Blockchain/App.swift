// Copyright © Blockchain Luxembourg S.A. All rights reserved.
// swiftformat:disable redundantSelf

import AnalyticsKit
import Combine
import ComposableArchitecture
import DelegatedSelfCustodyData
@_exported import DIKit
import ERC20DataKit
import EthereumDataKit
import FeatureActivityData
import FeatureAddressSearchData
import FeatureAddressSearchDomain
import FeatureAddressSearchUI
import FeatureAppDomain
import FeatureAppUI
import FeatureCardIssuingData
import FeatureCardIssuingDomain
import FeatureCardPaymentData
import FeatureCardPaymentUI
import FeatureDebugUI
import FeatureInterestData
import FeatureNotificationPreferencesDomain
import FeatureSettingsData
import FeatureSettingsDomain
import FeatureTransactionData
import FeatureWalletConnectData
import FeatureWalletConnectUI
import FeatureWithdrawalLocksData
import FeatureWithdrawalLocksDomain
import FirebaseCore
import FirebaseCrashlytics
import MetadataDataKit
import MetadataKit
import PlatformDataKit
import ToolKit
import UIKit
import UIKitExtensions
import WalletPayloadDataKit

@UIApplicationMain
final class AppDelegate: NSObject, UIApplicationDelegate {
    @LazyInject(tag: DebugScreenContext.tag) var debugCoordinator: DebugCoordinating

    var window: UIWindow?
    /// The main model passed to the view store that powers the app
    private let store: Store<AppState, AppAction>

    /// Responsible view store to send actions to the store
    lazy var viewStore = ViewStore(
        self.store.scope(state: { $0 }),
        removeDuplicates: ==
    )

    override init() {
        bootstrap()
        store = Store(
            initialState: AppState(),
            reducer: appReducer,
            environment: .live
        )
        super.init()
    }

    // MARK: - App entry point

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let window = windowProvider(screen: .main)
        self.window = window
        window.makeKeyAndVisible()
        eraseWalletForUITestsIfNeeded()
        if shouldStopProcessOnDebugAndTestingMode() {
            // set an empty root view controller to window to avoid app nitpicking
            window.setRootViewController(UIViewController())
            return true
        }

        #if INTERNAL_BUILD
        debugCoordinator.enableDebugMenu(for: window)
        #endif

        let hostingController = AppHostingController(
            store: store.scope(
                state: \.coreState,
                action: AppAction.core
            )
        )
        window.setRootViewController(hostingController)
        let context = AppDelegateContext(
            embraceAppId: ObservabilityConfiguration.appId
        )
        viewStore.send(.appDelegate(.didFinishLaunching(window: window, context: context)))
        return true
    }
}

// MARK: - Functions

/// Registers the dependencies from each module in the `DependencyContainer` of `DIKit`
func defineDependencies() {
    DependencyContainer.defined(by: modules {
        DependencyContainer.toolKit
        DependencyContainer.networkKit
        DependencyContainer.walletPayloadKit
        DependencyContainer.walletPayloadDataKit
        DependencyContainer.metadataKit
        DependencyContainer.metadataDataKit
        DependencyContainer.moneyKit
        DependencyContainer.platformKit
        DependencyContainer.platformDataKit
        DependencyContainer.interestKit
        DependencyContainer.interestDataKit
        DependencyContainer.platformUIKit
        DependencyContainer.ethereumKit
        DependencyContainer.ethereumDataKit
        DependencyContainer.erc20Kit
        DependencyContainer.erc20DataKit
        DependencyContainer.bitcoinChainKit
        DependencyContainer.bitcoinKit
        DependencyContainer.bitcoinCashKit
        DependencyContainer.stellarKit
        DependencyContainer.featureTransactionData
        DependencyContainer.featureTransactionDomain
        DependencyContainer.featureActivityDataKit
        DependencyContainer.featureTransactionUI
        DependencyContainer.buySellKit
        DependencyContainer.featureActivityDomain
        DependencyContainer.featureActivityUI
        DependencyContainer.featureAddressSearchDomain
        DependencyContainer.featureAddressSearchData
        DependencyContainer.featureAddressSearchUI
        DependencyContainer.featureKYCDomain
        DependencyContainer.featureKYCUI
        DependencyContainer.blockchain
        DependencyContainer.featureSettingsData
        DependencyContainer.featureSettingsDomain
        DependencyContainer.featureSettingsUI
        DependencyContainer.remoteNotificationsKit
        DependencyContainer.featureAuthenticationData
        DependencyContainer.featureAuthenticationDomain
        DependencyContainer.featureWalletConnectData
        DependencyContainer.featureWalletConnectDomain
        DependencyContainer.featureWalletConnectUI
        DependencyContainer.featureAppUI
        DependencyContainer.featureAppDomain
        DependencyContainer.withdrawalLocksData
        DependencyContainer.withdrawalLocksDomain
        DependencyContainer.featureCardPaymentDomain
        DependencyContainer.featureCardIssuingDomain
        DependencyContainer.featureCardIssuingData
        DependencyContainer.featureCardIssuingUI
        DependencyContainer.featureCardPaymentUI
        DependencyContainer.featureCardPaymentData
        DependencyContainer.delegatedSelfCustodyData
        DependencyContainer.blockchainActivity
        DependencyContainer.blockchainDelegatedSelfCustody
        DependencyContainer.uiKitExtensions
        #if INTERNAL_BUILD
        DependencyContainer.featureDebugUI
        #endif
    })
}

// MARK: - Private functions

/// Initial configuration for the app.
/// Takes cares of configuring Firebase and
/// defines the dependencies required by the app
private func bootstrap() {
    BuildFlag.isInternal = {
        #if INTERNAL_BUILD
        true
        #else
        false
        #endif
    }()
    BuildFlag.isAlpha = {
        #if ALPHA_BUILD
        true
        #else
        false
        #endif
    }()

    FirebaseConfiguration.shared.setLoggerLevel(.min)
    FirebaseApp.configure()
    defineDependencies()

    SystemEventAnalytics.start(
        recordingOn: resolve(),
        didCrashOnPreviousExecution: FirebaseCrashlytics.Crashlytics.crashlytics().didCrashDuringPreviousExecution
    )

    app.bootstrap()
}

private func eraseWalletForUITestsIfNeeded() {
    if ProcessInfo.processInfo.environmentBoolean(for: .eraseWallet) == true {
        // If ProcessInfo environment contains "automation_erase_data": true, erase wallet and settings.
        // This behaviour happens even on non-debug builds, this is necessary because our UI tests
        // run on real devices with 'release-staging' builds.
        WalletManager.shared.forgetWallet()
        UserDefaults.standard.removePersistentDomain(
            forName: MainBundleProvider.mainBundle.bundleIdentifier!
        )
    }
}

private func shouldStopProcessOnDebugAndTestingMode() -> Bool {
    #if DEBUG
    return ProcessInfo.processInfo.isUnitTesting
    #else
    return false
    #endif
}

/// Creates a UIWindow
/// - Parameter screen: The `UIScreen` to be used as a reference for the frame of the window
/// - Returns: A `UIWindow` instance
private func windowProvider(screen: UIScreen) -> UIWindow {
    UIWindow(frame: screen.bounds)
}

/// Determines if the app has the `DEBUG` flag
var isDebug: Bool {
    #if DEBUG
    return true
    #else
    return false
    #endif
}
