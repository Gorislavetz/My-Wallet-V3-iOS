// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import AnalyticsKit
import ComposableArchitecture
import ComposableNavigation
import DIKit
import FeatureAuthenticationDomain
import Localization
import ToolKit

// MARK: - Type

public enum EmailLoginAction: Equatable, NavigationAction {

    // MARK: - Alert

    public enum AlertAction: Equatable {
        case show(title: String, message: String)
        case dismiss
    }

    case alert(AlertAction)

    // MARK: - Transitions and Navigations

    case onAppear
    case closeButtonTapped
    case route(RouteIntent<EmailLoginRoute>?)

    // MARK: - Email

    case didChangeEmailAddress(String)

    // MARK: - Device Verification

    case sendDeviceVerificationEmail
    case didSendDeviceVerificationEmail(Result<EmptyValue, DeviceVerificationServiceError>)
    case setupSessionToken

    // MARK: - Local Actions

    case verifyDevice(VerifyDeviceAction)

    // MARK: - Utils

    case none
}

private typealias EmailLoginLocalization = LocalizationConstants.FeatureAuthentication.EmailLogin

// MARK: - Properties

public struct EmailLoginState: Equatable, NavigationState {

    // MARK: - Navigation State

    public var route: RouteIntent<EmailLoginRoute>?

    // MARK: - Alert State

    var alert: AlertState<EmailLoginAction>?

    // MARK: - Email

    var emailAddress: String
    var isEmailValid: Bool

    // MARK: - Loading State

    var isLoading: Bool

    // MARK: - Local States

    var verifyDeviceState: VerifyDeviceState?

    init() {
        route = nil
        emailAddress = ""
        isEmailValid = false
        isLoading = false
        verifyDeviceState = nil
    }
}

struct EmailLoginEnvironment {
    let mainQueue: AnySchedulerOf<DispatchQueue>
    let sessionTokenService: SessionTokenServiceAPI
    let deviceVerificationService: DeviceVerificationServiceAPI
    let appFeatureConfigurator: FeatureConfiguratorAPI
    let errorRecorder: ErrorRecording
    let analyticsRecorder: AnalyticsEventRecorderAPI
    let validateEmail: (String) -> Bool

    init(
        mainQueue: AnySchedulerOf<DispatchQueue>,
        sessionTokenService: SessionTokenServiceAPI,
        deviceVerificationService: DeviceVerificationServiceAPI,
        appFeatureConfigurator: FeatureConfiguratorAPI,
        errorRecorder: ErrorRecording,
        analyticsRecorder: AnalyticsEventRecorderAPI,
        validateEmail: @escaping (String) -> Bool = { $0.isEmail }
    ) {
        self.mainQueue = mainQueue
        self.sessionTokenService = sessionTokenService
        self.deviceVerificationService = deviceVerificationService
        self.appFeatureConfigurator = appFeatureConfigurator
        self.errorRecorder = errorRecorder
        self.analyticsRecorder = analyticsRecorder
        self.validateEmail = validateEmail
    }
}

let emailLoginReducer = Reducer.combine(
    verifyDeviceReducer
        .optional()
        .pullback(
            state: \.verifyDeviceState,
            action: /EmailLoginAction.verifyDevice,
            environment: {
                VerifyDeviceEnvironment(
                    mainQueue: $0.mainQueue,
                    deviceVerificationService: $0.deviceVerificationService,
                    appFeatureConfigurator: $0.appFeatureConfigurator,
                    errorRecorder: $0.errorRecorder,
                    analyticsRecorder: $0.analyticsRecorder
                )
            }
        ),
    Reducer<
        EmailLoginState,
        EmailLoginAction,
        EmailLoginEnvironment
            // swiftlint:disable closure_body_length
    > { state, action, environment in
        switch action {

        // MARK: - Alert

        case .alert(.show(let title, let message)):
            state.alert = AlertState(
                title: TextState(verbatim: title),
                message: TextState(verbatim: message),
                dismissButton: .default(
                    TextState(LocalizationConstants.continueString),
                    action: .send(.alert(.dismiss))
                )
            )
            return .none

        case .alert(.dismiss):
            state.alert = nil
            return .none

        // MARK: - Transitions and Navigations

        case .onAppear:
            environment.analyticsRecorder.record(
                event: .loginViewed
            )
            return Effect(value: .setupSessionToken)

        case .closeButtonTapped:
            // handled in welcome reducer
            return .none

        case .route(let route):
            if let routeValue = route?.route {
                state.verifyDeviceState = .init(emailAddress: state.emailAddress)
            } else {
                state.verifyDeviceState = nil
            }
            state.route = route
            return .none

        // MARK: - Email

        case .didChangeEmailAddress(let emailAddress):
            state.emailAddress = emailAddress
            state.isEmailValid = environment.validateEmail(emailAddress)
            return .none

        // MARK: - Device Verification

        case .sendDeviceVerificationEmail,
             .verifyDevice(.sendDeviceVerificationEmail):
            guard state.isEmailValid else {
                return .none
            }
            state.isLoading = true
            state.verifyDeviceState?.sendEmailButtonIsLoading = true
            return environment
                .deviceVerificationService
                .sendDeviceVerificationEmail(to: state.emailAddress)
                .receive(on: environment.mainQueue)
                .catchToEffect()
                .map { result -> EmailLoginAction in
                    switch result {
                    case .success:
                        return .didSendDeviceVerificationEmail(.success(.noValue))
                    case .failure(let error):
                        return .didSendDeviceVerificationEmail(.failure(error))
                    }
                }

        case .didSendDeviceVerificationEmail(let response):
            state.isLoading = false
            state.verifyDeviceState?.sendEmailButtonIsLoading = false
            if case .failure(let error) = response {
                switch error {
                case .recaptchaError,
                     .missingSessionToken:
                    return Effect(
                        value: .alert(
                            .show(
                                title: EmailLoginLocalization.Alerts.SignInError.title,
                                message: EmailLoginLocalization.Alerts.SignInError.message
                            )
                        )
                    )
                case .networkError,
                     .expiredEmailCode:
                    // still go to verify device screen if there is network error
                    break
                }
            }
            return Effect(value: .navigate(to: .verifyDevice))

        case .setupSessionToken:
            return environment
                .sessionTokenService
                .setupSessionToken()
                .receive(on: environment.mainQueue)
                .catchToEffect()
                .map { result -> EmailLoginAction in
                    if case .failure(let error) = result {
                        environment.errorRecorder.error(error)
                        return .alert(
                            .show(
                                title: EmailLoginLocalization.Alerts.GenericNetworkError.title,
                                message: EmailLoginLocalization.Alerts.GenericNetworkError.message
                            )
                        )
                    }
                    return .none
                }

        // MARK: - Local Reducers

        case .verifyDevice:
            // handled in verify device reducer
            return .none

        // MARK: - Utils

        case .none:
            return .none
        }
    }
)
.analytics()

// MARK: - Private

extension Reducer where
    Action == EmailLoginAction,
    State == EmailLoginState,
    Environment == EmailLoginEnvironment
{
    /// Helper reducer for analytics tracking
    fileprivate func analytics() -> Self {
        combined(
            with: Reducer<
                EmailLoginState,
                EmailLoginAction,
                EmailLoginEnvironment
            > { _, action, environment in
                switch action {
                case .sendDeviceVerificationEmail:
                    environment.analyticsRecorder.record(
                        event: .loginClicked(
                            origin: .navigation
                        )
                    )
                    return .none
                default:
                    return .none
                }
            }
        )
    }
}
