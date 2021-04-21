//
//  TargetSelectionPageInteractor.swift
//  TransactionUIKit
//
//  Created by Dimitrios Chatzieleftheriou on 01/02/2021.
//  Copyright © 2021 Blockchain Luxembourg S.A. All rights reserved.
//

import DIKit
import Localization
import PlatformKit
import PlatformUIKit
import RIBs
import RxCocoa
import RxSwift
import ToolKit

protocol TargetSelectionPageRouting: ViewableRouting {
    func presentQRScanner(for currency: CryptoCurrency,
                          sourceAccount: CryptoAccount,
                          model: TargetSelectionPageModel)
}

protocol TargetSelectionPageListener: AnyObject {
    func didSelect(target: TransactionTarget)
    func didTapBack()
    func didTapClose()
}

final class TargetSelectionPageInteractor: PresentableInteractor<TargetSelectionPagePresentable>,
                                           TargetSelectionPageInteractable {

    weak var router: TargetSelectionPageRouting?

    // MARK: - Private Properties
    
    private let accountProvider: SourceAndTargetAccountProviding
    private let targetSelectionPageModel: TargetSelectionPageModel
    private let action: AssetAction
    private let messageRecorder: MessageRecording
    private let didSelect: AccountPickerDidSelect?
    private let backButtonInterceptor: BackButtonInterceptor
    weak var listener: TargetSelectionPageListener?

    // MARK: - Init

    init(targetSelectionPageModel: TargetSelectionPageModel,
         presenter: TargetSelectionPagePresentable,
         accountProvider: SourceAndTargetAccountProviding,
         listener: TargetSelectionListenerBridge,
         action: AssetAction,
         backButtonInterceptor: @escaping BackButtonInterceptor,
         messageRecorder: MessageRecording = resolve()) {
        self.action = action
        self.targetSelectionPageModel = targetSelectionPageModel
        self.accountProvider = accountProvider
        self.messageRecorder = messageRecorder
        self.backButtonInterceptor = backButtonInterceptor
        switch listener {
        case .simple(let didSelect):
            self.didSelect = didSelect
            self.listener = nil
        case .listener(let listener):
            self.didSelect = nil
            self.listener = listener
        }
        super.init(presenter: presenter)
    }

    override func didBecomeActive() {
        super.didBecomeActive()

        let cryptoAddressViewModel = CryptoAddressTextFieldViewModel(
            validator: CryptoAddressValidator(model: targetSelectionPageModel),
            messageRecorder: messageRecorder
        )

        // This returns an observable from the TransactionModel and its state.
        // Since the TargetSelection has it's own model/state/actions we need to intercept when the back button
        // of the TransactionFlow occurs and update the TargetSelection state
        backButtonInterceptor()
            .subscribe(onNext: { [weak self] state in
                let hasCorrectBackStack = state.backStack.isEmpty || state.backStack.contains(.selectTarget)
                let hasCorrectStep = state.step == .enterAmount || state.step == .selectTarget
                if hasCorrectStep && hasCorrectBackStack && state.isGoingBack {
                    self?.targetSelectionPageModel.process(action: .returnToPreviousStep)
                }
            })
            .disposeOnDeactivate(interactor: self)
        
        /// Fetch the source account provided.
        let sourceAccount = accountProvider.sourceAccount
            .map { account -> CryptoAccount in
                guard let crypto = account else {
                    fatalError("Expected a source account")
                }
                return crypto
            }
            .asObservable()
            .share(replay: 1, scope: .whileConnected)

        /// Any text coming from the `State` we want to bind
        /// to the `cryptoAddressViewModel` textRelay.
        targetSelectionPageModel
            .state
            .map(\.inputValidated)
            .map(\.text)
            .bind(to: cryptoAddressViewModel.originalTextRelay)
            .disposeOnDeactivate(interactor: self)
        
        targetSelectionPageModel
            .state
            .map(\.inputValidated)
            /// Only the QR scanner requires validation. The textfield
            /// validates itself so long as it's in focus.
            .filter(\.requiresValidation)
            /// We get the text from the `State` and not the textField.
            /// This is **only** for the QR scanner. This is to prevent
            /// conflating text entry with QR scanning or deep linking.
            .map(\.text)
            .distinctUntilChanged()
            .withLatestFrom(sourceAccount) { ($0, $1) }
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] text, account in
                self?.targetSelectionPageModel.process(action: .validateAddress(text, account))
            })
            .disposeOnDeactivate(interactor: self)
        
        /// The text the user has entered into the textField
        let text = cryptoAddressViewModel
            .text
            .distinctUntilChanged()
        
        /// Whether or not the textField is in focus
        let isFocused = cryptoAddressViewModel
            .focusRelay
            /// We only want to update the `State` with a text entry value
            /// when the text field is not in focus.
            .map { $0 == .on }

        text
            .withLatestFrom(isFocused) { ($0, $1) }
            .filter { $0.1 }
            .map(\.0)
            .withLatestFrom(sourceAccount) { ($0, $1) }
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] text, account in
                self?.targetSelectionPageModel.process(action: .validateAddress(text, account))
            })
            .disposeOnDeactivate(interactor: self)
        
        /// Launch the QR scanner should the button be tapped
        cryptoAddressViewModel
            .tapRelay
            .bindAndCatch(weak: self) { (self) in
                self.targetSelectionPageModel.process(action: .qrScannerButtonTapped)
            }
            .disposeOnDeactivate(interactor: self)

        /// Listens to the `step` which
        /// triggers routing to a new screen or ending the flow
        targetSelectionPageModel
            .state
            .distinctUntilChanged(\.step)
            .withLatestFrom(sourceAccount) { ($0, $1) }
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { (state, source) in
                self.handleStateChange(newState: state, sourceAccount: source)
            })
            .disposeOnDeactivate(interactor: self)
            
        sourceAccount
            .map { (account) -> NSAttributedString in
                NSAttributedString(
                    string: String(format: LocalizationConstants.TextField.Title.cryptoAddress, account.currencyType.name),
                    attributes: [
                        .foregroundColor: UIColor.textFieldPlaceholder,
                        .font: UIFont.main(.medium, 16)
                    ]
                )
            }
            .bind(to: cryptoAddressViewModel.placeholderRelay)
            .disposeOnDeactivate(interactor: self)

        sourceAccount
            .subscribe(onNext: { [weak self] account in
                guard let self = self else { return }
                self.targetSelectionPageModel.process(action: .sourceAccountSelected(account, self.action))
            })
            .disposeOnDeactivate(interactor: self)
        
        let interactorState = targetSelectionPageModel
            .state
            .observeOn(MainScheduler.instance)
            .scan(.empty) { [weak self] (state, updater) -> TargetSelectionPageInteractor.State in
                guard let self = self else {
                    return state
                }
                guard updater.sourceAccount != nil else {
                    /// We cannot procede to the calcuation step without a `sourceAccount`
                    Logger.shared.debug("No sourceAccount: \(updater)")
                    return state
                }
                return self.calculateNextState(
                    with: state,
                    updater: updater,
                    cryptoAddressViewModel: cryptoAddressViewModel
                )
            }
            .asDriverCatchError()

        presenter.connect(state: interactorState)
            .drive(onNext: handle(effects:))
            .disposeOnDeactivate(interactor: self)
    }

    // MARK: - Private methods
    private func calculateNextState(
        with state: State,
        updater: TargetSelectionPageState,
        cryptoAddressViewModel: CryptoAddressTextFieldViewModel
    ) -> State {
        guard let sourceAccount = updater.sourceAccount as? SingleAccount else {
            fatalError("You should have a source account.")
        }
        var state = state
        let targets = updater.availableTargets
            .compactMap { $0 as? SingleAccount }

        if state.sourceInteractor?.account.id != sourceAccount.id {
            state = state
                    .update(keyPath: \.sourceInteractor,
                            value: .singleAccount(sourceAccount, AccountAssetBalanceViewInteractor(account: sourceAccount)))
        }

        let destinations: [TargetSelectionPageCellItem.Interactor] = targets.map { account in
            guard account.id == (updater.destination as? SingleAccount)?.id else {
                return .singleAccountAvailableTarget(account, false)
            }
            return .singleAccountAvailableTarget(account, true)
        }
        .sorted { $0.account.label < $1.account.label }

        if sourceAccount is NonCustodialAccount {
            if state.inputFieldInteractor == nil {
                state = state
                    .update(keyPath: \.inputFieldInteractor, value: .walletInputField(sourceAccount, cryptoAddressViewModel))
            }
        } else {
            state = state
                .update(keyPath: \.inputFieldInteractor, value: nil)
        }

        return state
            /// Update the `Interactors` for the cells.
            .update(keyPath: \.destinationInteractors, value: destinations)
            /// Update the enabled state of the `Next` button.
            .update(keyPath: \.actionButtonEnabled, value: updater.nextEnabled)
    }

    private func handle(effects: Effects) {
        switch effects {
        case .select(let account):
            targetSelectionPageModel.process(action: .destinationSelected(account))
        case .back,
             .closed:
            targetSelectionPageModel.process(action: .resetFlow)
        case .next:
            targetSelectionPageModel.process(action: .destinationConfirmed)
        case .none:
            break
        }
    }
    
    private var initialStep: Bool = true
    private func handleStateChange(newState: TargetSelectionPageState, sourceAccount: CryptoAccount) {
        if !initialStep, newState.step == TargetSelectionPageStep.initial {
            // no-op
        } else {
            initialStep = false
            showFlowStep(newState: newState, sourceAccount: sourceAccount)
        }
    }

    private func finishFlow() {
        targetSelectionPageModel.process(action: .resetFlow)
    }
    
    private func showFlowStep(newState: TargetSelectionPageState, sourceAccount: CryptoAccount) {
        guard !newState.isGoingBack else {
            listener?.didTapBack()
            return
        }
        switch newState.step {
        case .initial:
            break
        case .closed:
            targetSelectionPageModel.destroy()
            listener?.didTapClose()
        case .complete:
            guard let account = newState.destination else {
                fatalError("Expected a destination acount.")
            }
            didSelect?(account as! BlockchainAccount)
            listener?.didSelect(target: account)
        case .qrScanner:
            guard let source = newState.sourceAccount else {
                fatalError("Expected a sourceAccount: \(newState)")
            }
            guard let crypto = source as? CryptoAccount else {
                fatalError("Expected a CryptoAccount: \(source)")
            }
            router?.presentQRScanner(
                for: crypto.asset,
                sourceAccount: sourceAccount,
                model: targetSelectionPageModel
            )
        }
    }
    
    private func initialState() -> TargetSelectionPageState {
        TargetSelectionPageState(nextEnabled: false, destination: nil)
    }
}

extension TargetSelectionPageInteractor {
    struct State: StateType {
        static let empty = State(actionButtonEnabled: false)
        var sourceInteractor: TargetSelectionPageCellItem.Interactor?
        var inputFieldInteractor: TargetSelectionPageCellItem.Interactor?
        var destinationInteractors: [TargetSelectionPageCellItem.Interactor]

        var actionButtonEnabled: Bool
        
        private init(actionButtonEnabled: Bool) {
            self.actionButtonEnabled = actionButtonEnabled
            self.sourceInteractor = nil
            self.inputFieldInteractor = nil
            self.destinationInteractors = []
        }
    }

    enum Effects {
        case select(BlockchainAccount)
        case next
        case back
        case closed
        case none
    }
}
