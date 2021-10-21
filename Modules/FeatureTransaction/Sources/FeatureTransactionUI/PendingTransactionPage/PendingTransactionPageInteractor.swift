// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
import DIKit
import FeatureTransactionDomain
import Localization
import PlatformKit
import PlatformUIKit
import RIBs
import RxCocoa
import RxSwift

protocol PendingTransactionPageRouting: Routing {}

protocol PendingTransactionPageListener: AnyObject {
    func closeFlow()
    func showKYCUpgradePrompt()
}

protocol PendingTransactionPagePresentable: Presentable, PendingTransactionPageViewControllable {
    func connect(state: Driver<PendingTransactionPageState>) -> Driver<PendingTransactionPageState.Effect>
}

final class PendingTransactionPageInteractor: PresentableInteractor<PendingTransactionPagePresentable>, PendingTransactionPageInteractable {

    weak var router: PendingTransactionPageRouting?
    weak var listener: PendingTransactionPageListener?

    private let pendingTransationStateProvider: PendingTransactionStateProviding
    private let transactionModel: TransactionModel
    private let analyticsHook: TransactionAnalyticsHook
    private let sendEmailNotificationService: SendEmailNotificationServiceAPI

    private var cancellables = Set<AnyCancellable>()
    private var disposeBag = DisposeBag()

    init(
        transactionModel: TransactionModel,
        presenter: PendingTransactionPagePresentable,
        action: AssetAction,
        analyticsHook: TransactionAnalyticsHook = resolve(),
        sendEmailNotificationService: SendEmailNotificationServiceAPI = resolve()
    ) {
        pendingTransationStateProvider = PendingTransctionStateProviderFactory.pendingTransactionStateProvider(action: action)
        self.transactionModel = transactionModel
        self.analyticsHook = analyticsHook
        self.sendEmailNotificationService = sendEmailNotificationService
        super.init(presenter: presenter)
    }

    override func didBecomeActive() {
        super.didBecomeActive()

        let transactionState = transactionModel
            .state
            .share(replay: 1)

        let state: Driver<PendingTransactionPageState> = pendingTransationStateProvider
            .connect(state: transactionState)
            .asDriver(onErrorJustReturn: .empty)

        presenter
            .connect(state: state)
            .drive(onNext: handle(effect:))
            .disposeOnDeactivate(interactor: self)

        let executionStatus = transactionState.map(\.executionStatus)

        executionStatus
            .asObservable()
            .withLatestFrom(transactionState) { ($0, $1) }
            .subscribe(onNext: { [weak self] executionStatus, transactionState in
                guard let self = self else { return }
                switch executionStatus {
                case .inProgress, .notStarted, .pending:
                    break
                case .error:
                    self.analyticsHook.onTransactionFailure(with: transactionState)
                case .completed:
                    self.analyticsHook.onTransactionSuccess(with: transactionState)
                    self.triggerSendEmailNotification(transactionState)
                }
            })
            .disposed(by: disposeBag)

        let completion = executionStatus
            .map(\.isComplete)
            .filter { $0 == true }
            .delay(.milliseconds(500), scheduler: MainScheduler.asyncInstance)
            .asDriverCatchError()

        completion
            .drive(weak: self) { (self, _) in
                self.requestReview()
            }
            .disposeOnDeactivate(interactor: self)
    }

    // MARK: - Private methods

    private func requestReview() {
        StoreReviewController.requestReview()
    }

    private func handle(effect: PendingTransactionPageState.Effect) {
        switch effect {
        case .close:
            listener?.closeFlow()
        case .upgradeKYCTier:
            listener?.showKYCUpgradePrompt()
        case .none:
            break
        }
    }

    private func triggerSendEmailNotification(_ transactionState: TransactionState) {
        if transactionState.action == .send, transactionState.source is NonCustodialAccount {
            sendEmailNotificationService
                .postSendEmailNotificationTrigger(transactionState.amount)
                .subscribe()
                .store(in: &cancellables)
        }
    }

    override func willResignActive() {
        super.willResignActive()
    }
}
