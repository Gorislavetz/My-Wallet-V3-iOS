//
//  BitPayTransactionEngine.swift
//  TransactionKit
//
//  Created by Alex McGregor on 4/7/21.
//  Copyright © 2021 Blockchain Luxembourg S.A. All rights reserved.
//

import DIKit
import PlatformKit
import RxSwift
import ToolKit

final class BitPayTransactionEngine: TransactionEngine {
    
    var sourceAccount: CryptoAccount!
    var askForRefreshConfirmation: (AskForRefreshConfirmation)!
    var transactionTarget: TransactionTarget!
    
    var fiatExchangeRatePairs: Observable<TransactionMoneyValuePairs> {
        onChainEngine
            .fiatExchangeRatePairs
    }
    
    var requireSecondPassword: Bool {
        onChainEngine.requireSecondPassword
    }
    
    // MARK: - Private Properties
    
    private let onChainEngine: OnChainTransactionEngine
    private let bitpayService: BitPayServiceAPI
    private let analyticsRecorder: AnalyticsEventRecorderAPI
    private var bitpayInvoice: BitPayInvoiceTarget {
        transactionTarget as! BitPayInvoiceTarget
    }
    private var bitpayClientEngine: BitPayClientEngine {
        onChainEngine as! BitPayClientEngine
    }
    private var timeRemainingSeconds: TimeInterval {
        bitpayInvoice
            .expirationTimeInSeconds
    }
    
    init(onChainEngine: OnChainTransactionEngine,
         bitpayService: BitPayServiceAPI = resolve(),
         analyticsRecorder: AnalyticsEventRecorderAPI = resolve()) {
        self.onChainEngine = onChainEngine
        self.bitpayService = bitpayService
        self.analyticsRecorder = analyticsRecorder
    }
    
    func start(sourceAccount: CryptoAccount,
               transactionTarget: TransactionTarget,
               askForRefreshConfirmation: @escaping (Bool) -> Completable) {
        self.sourceAccount = sourceAccount
        self.transactionTarget = transactionTarget
        self.askForRefreshConfirmation = askForRefreshConfirmation
        onChainEngine.start(sourceAccount: sourceAccount, transactionTarget: transactionTarget, askForRefreshConfirmation: askForRefreshConfirmation)
    }
    
    func assertInputsValid() {
        precondition(sourceAccount is CryptoNonCustodialAccount)
        precondition(sourceAccount.asset == .bitcoin)
        precondition(transactionTarget is BitPayInvoiceTarget)
        precondition(onChainEngine is BitPayClientEngine)
        onChainEngine.assertInputsValid()
    }
    
    func initializeTransaction() -> Single<PendingTransaction> {
        onChainEngine
            .initializeTransaction()
            .map(weak: self) { (self, pendingTransaction) in
                pendingTransaction
                    .update(availableFeeLevels: [.priority])
                    .update(selectedFeeLevel: .priority)
                    .update(amount: self.bitpayInvoice.amount.moneyValue)
            }
    }
    
    func doBuildConfirmations(pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        onChainEngine
            .update(
                amount: bitpayInvoice.amount.moneyValue,
                pendingTransaction: pendingTransaction
            )
            .flatMap(weak: self) { (self, pendingTransaction) in
                self.onChainEngine
                    .doBuildConfirmations(pendingTransaction: pendingTransaction)
            }
            .map(weak: self) { (self, pendingTransaction) in
                self.startTimeIfNotStarted(pendingTransaction)
            }
            .map(weak: self) { (self, pendingTransaction) in
                pendingTransaction
                    .insert(
                        confirmation: .bitpayCountdown(
                            .init(secondsRemaining: self.timeRemainingSeconds)
                        ),
                        prepend: true
                    )
            }
    }
    
    func doRefreshConfirmations(pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        .just(
            pendingTransaction
                .insert(
                    confirmation: .bitpayCountdown(
                        .init(secondsRemaining: timeRemainingSeconds)
                    ),
                    prepend: true
                )
        )
    }
    
    func update(amount: MoneyValue, pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        /// Don't set the amount here.
        /// It is fixed so we can do it in the confirmation building step
        .just(pendingTransaction)
    }
    
    func validateAmount(pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        onChainEngine
            .validateAmount(pendingTransaction: pendingTransaction)
    }
    
    func doValidateAll(pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        doValidateTimeout(pendingTransaction: pendingTransaction)
            .flatMap(weak: self) { (self, pendingTx) -> Single<PendingTransaction> in
                self.onChainEngine.doValidateAll(pendingTransaction: pendingTx)
            }
            .updateTxValiditySingle(pendingTransaction: pendingTransaction)
    }
    
    func execute(pendingTransaction: PendingTransaction, secondPassword: String) -> Single<TransactionResult> {
        bitpayClientEngine
            .doPrepareTransaction(pendingTransaction: pendingTransaction, secondPassword: secondPassword)
            .subscribeOn(MainScheduler.instance)
            .flatMap(weak: self) { (self, transaction) -> Single<String> in
                self.doExecuteTransaction(
                    invoiceId: self.bitpayInvoice.invoiceId,
                    transaction: transaction
                )
            }
            .do(onSuccess: { [weak self] _ in
                guard let self = self else { return }
                // TICKET: IOS-4492 - Analytics
                self.bitpayClientEngine.doOnTransactionSuccess(pendingTransaction: pendingTransaction)
            }, onError: { [weak self] error in
                guard let self = self else { return }
                // TICKET: IOS-4492 - Analytics
                self.bitpayClientEngine.doOnTransactionFailed(pendingTransaction: pendingTransaction, error: error)
            })
            .map { TransactionResult.hashed(txHash: $0, amount: pendingTransaction.amount) }
    }
    
    func doPostExecute(transactionResult: TransactionResult) -> Completable {
        transactionTarget.onTxCompleted(transactionResult)
    }
    
    func doUpdateFeeLevel(pendingTransaction: PendingTransaction, level: FeeLevel, customFeeAmount: MoneyValue) -> Single<PendingTransaction> {
        precondition(pendingTransaction.feeSelection.availableLevels.contains(level))
        return .just(pendingTransaction)
    }
    
    // MARK: - Private Functions
    
    private func doExecuteTransaction(invoiceId: String, transaction: EngineTransaction) -> Single<String> {
        bitpayService
            .verifySignedTransaction(
                invoiceID: invoiceId,
                currency: sourceAccount.asset,
                transactionHex: transaction.txHash,
                transactionSize: transaction.msgSize
            )
            .delay(.seconds(3), scheduler: MainScheduler.instance)
            .andThen(
                bitpayService
                        .submitBitPayPayment(
                            invoiceID: invoiceId,
                            currency: self.sourceAccount.asset,
                            transactionHex: transaction.txHash,
                            transactionSize: transaction.msgSize
                        )
            )
            .map(\.memo)
    }
    
    private func doValidateTimeout(pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        Single.just(pendingTransaction)
            .map(weak: self) { (self, pendingTx) in
                guard self.timeRemainingSeconds >= 0 else {
                    throw TransactionValidationFailure(state: .invoiceExpired)
                }
                return pendingTx
            }
    }
    
    private func startTimeIfNotStarted(_ pendingTransaction: PendingTransaction) -> PendingTransaction {
        guard pendingTransaction.bitpayTimer == nil else { return pendingTransaction }
        var transaction = pendingTransaction
        transaction.setCountdownTimer(timer: startCountdownTimer(timeRemaining: timeRemainingSeconds))
        return transaction
    }
    
    private func startCountdownTimer(timeRemaining: TimeInterval) -> Disposable {
        guard let remaining = Int(exactly: timeRemaining) else {
            fatalError("Expected an Int value: \(timeRemaining)")
        }
        return Observable<Int>.interval(.seconds(1), scheduler: MainScheduler.instance)
            .map { remaining - $0 }
            .do(onNext: { [weak self] _ in
                guard let self = self else { return }
                _ = self.askForRefreshConfirmation(true)
                    .subscribe()
            })
            .takeUntil(.inclusive, predicate: { $0 == 0 })
            .do(onCompleted: { [weak self] in
                guard let self = self else { return }
                Logger.shared.debug("BitPay Invoice Countdown expired")
                _ = self.askForRefreshConfirmation(true)
                    .subscribe()
            })
            .subscribe()
    }
}

extension PendingTransaction {
    fileprivate mutating func setCountdownTimer(timer: Disposable) {
        engineState[.bitpayTimer] = timer
    }
    var bitpayTimer: Disposable? {
        engineState[.bitpayTimer] as? Disposable
    }
}
