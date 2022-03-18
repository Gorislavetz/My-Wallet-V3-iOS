// Copyright © Blockchain Luxembourg S.A. All rights reserved.

// swiftlint:disable file_length

import FeatureTransactionDomain
import Localization
import MoneyKit
import NabuNetworkError
import PlatformKit
import ToolKit
import UIComponentsKit

extension TransactionErrorState {

    private typealias Localization = LocalizationConstants.Transaction.Error

    var recoveryWarningHint: String {
        let text: String
        switch self {
        case .none:
            text = "" // no error
        case .insufficientFunds(_, _, let sourceCurrency, _):
            text = String.localizedStringWithFormat(
                Localization.insufficientFundsRecoveryHint,
                sourceCurrency.displayCode
            )
        case .belowFees(let fees, _):
            text = String.localizedStringWithFormat(
                Localization.insufficientFundsRecoveryHint,
                fees.displayCode
            )
        case .belowMinimumLimit(let minimum):
            text = String.localizedStringWithFormat(
                Localization.belowMinimumLimitRecoveryHint,
                minimum.shortDisplayString
            )
        case .overMaximumSourceLimit(let maximum, _, _):
            text = String.localizedStringWithFormat(
                Localization.overMaximumSourceLimitRecoveryHint,
                maximum.shortDisplayString
            )
        case .overMaximumPersonalLimit:
            text = Localization.overMaximumPersonalLimitRecoveryHint

        // MARK: Unchecked

        case .addressIsContract:
            text = Localization.addressIsContractShort
        case .invalidAddress:
            text = Localization.invalidAddressShort
        case .invalidPassword:
            text = Localization.invalidPasswordShort
        case .optionInvalid:
            text = Localization.optionInvalidShort
        case .pendingOrdersLimitReached:
            text = Localization.pendingOrdersLimitReachedShort
        case .transactionInFlight:
            text = Localization.transactionInFlightShort
        case .unknownError:
            text = Localization.unknownErrorShort
        case .fatalError:
            text = Localization.fatalErrorShort
        case .nabuError:
            text = Localization.nextworkErrorShort
        }
        return text
    }

    // swiftlint:disable cyclomatic_complexity
    func recoveryWarningTitle(for action: AssetAction) -> String {
        let text: String
        switch self {
        case .fatalError(let fatalError):
            switch fatalError {
            case .generic(let error):
                if
                    let error = error as? OrderConfirmationServiceError,
                    case .nabu(.nabuError(let networkError)) = error
                {
                    return transactionErrorTitle(
                        for: networkError.code,
                        action: action
                    ) ?? Localization.nextworkErrorShort
                } else if
                    let error = error as? NabuNetworkError,
                    case .nabuError(let networkError) = error
                {
                    return transactionErrorTitle(
                        for: networkError.code,
                        action: action
                    ) ?? Localization.nextworkErrorShort
                } else {
                    fallthrough
                }
            default:
                return Localization.fatalErrorShort
            }
        case .nabuError(let error):
            text = transactionErrorTitle(for: error.code, action: action) ?? Localization.nextworkErrorShort
        case .insufficientFunds(let balance, _, _, _) where action == .swap:
            text = String.localizedStringWithFormat(
                Localization.insufficientFundsRecoveryTitle_swap,
                balance.displayString
            )
        case .insufficientFunds(_, _, let sourceCurrency, _):
            text = String.localizedStringWithFormat(
                Localization.insufficientFundsRecoveryTitle,
                sourceCurrency.code
            )
        case .belowFees(let fees, let balance):
            text = String.localizedStringWithFormat(
                Localization.belowMinimumLimitRecoveryTitle,
                fees.shortDisplayString,
                balance.shortDisplayString
            )
        case .belowMinimumLimit(let minimum):
            text = String.localizedStringWithFormat(
                Localization.belowMinimumLimitRecoveryTitle,
                minimum.shortDisplayString
            )
        case .overMaximumSourceLimit(let availableAmount, _, _) where action == .send:
            text = String.localizedStringWithFormat(
                Localization.insufficientFundsRecoveryTitle,
                availableAmount.currencyType.displayCode
            )
        case .overMaximumSourceLimit(let maximum, _, _):
            text = String.localizedStringWithFormat(
                Localization.overMaximumSourceLimitRecoveryTitle,
                maximum.shortDisplayString
            )
        case .overMaximumPersonalLimit:
            text = Localization.overMaximumPersonalLimitRecoveryTitle
        case .none:
            if BuildFlag.isInternal {
                Logger.shared.error("Unsupported API error thrown or an internal error thrown")
            }
            text = Localization.unknownError
        case .addressIsContract:
            text = Localization.addressIsContract
        case .invalidAddress:
            text = Localization.invalidAddress
        case .invalidPassword:
            text = Localization.invalidPassword
        case .optionInvalid:
            text = Localization.optionInvalid
        case .pendingOrdersLimitReached:
            text = Localization.pendingOrderLimitReached
        case .transactionInFlight:
            text = Localization.transactionInFlight
        case .unknownError:
            text = Localization.unknownError
        }
        return text
    }

    func recoveryWarningMessage(for action: AssetAction) -> String {
        let text: String
        switch self {
        case .belowFees(let fee, let balance):
            text = String.localizedStringWithFormat(
                Localization.insuffientFundsToPayForFeesMessage,
                balance.currencyType.displayCode,
                fee.shortDisplayString,
                balance.currencyType.name
            )
        case .insufficientFunds:
            text = localizedInsufficientFundsMessage(action: action)
        case .belowMinimumLimit:
            text = localizedBelowMinimumLimitMessage(action: action)
        case .overMaximumSourceLimit:
            text = localizedOverMaxSourceLimitMessage(action: action)
        case .overMaximumPersonalLimit:
            text = localizedOverMaxPersonalLimitMessage(action: action)
        case .nabuError(let error):
            text = transactionErrorDescription(for: error.code, action: action)
        case .fatalError(let fatalTransactionError):
            text = transactionErrorDescription(for: fatalTransactionError, action: action)
        case .unknownError:
            text = Localization.unknownErrorDescription
        default:
            text = String(describing: self)
        }
        return text
    }

    func recoveryWarningCallouts(for action: AssetAction) -> [ErrorRecoveryState.Callout] {
        let callouts: [ErrorRecoveryState.Callout]
        switch self {
        case .belowFees(let fees, let balance) where action == .send:
            callouts = [
                ErrorRecoveryState.Callout(
                    id: ErrorRecoveryCalloutIdentifier.buy.rawValue,
                    image: fees.currency.image,
                    title: String.localizedStringWithFormat(
                        Localization.belowFeesRecoveryCalloutTitle_send,
                        fees.displayCode
                    ),
                    message: String.localizedStringWithFormat(
                        Localization.belowFeesRecoveryCalloutMessage_send,
                        balance.displayString
                    ),
                    callToAction: Localization.belowFeesRecoveryCalloutCTA_send
                )
            ]
        case .insufficientFunds(_, let desiredAmount, let sourceCurrency, let targetCurrency) where action == .send:
            callouts = [
                ErrorRecoveryState.Callout(
                    id: ErrorRecoveryCalloutIdentifier.buy.rawValue,
                    image: targetCurrency.image,
                    title: String.localizedStringWithFormat(
                        Localization.overMaximumSourceLimitRecoveryCalloutTitle_send,
                        sourceCurrency.displayCode
                    ),
                    message: String.localizedStringWithFormat(
                        Localization.overMaximumSourceLimitRecoveryCalloutMessage_send,
                        desiredAmount.displayString
                    ),
                    callToAction: Localization.overMaximumSourceLimitRecoveryCalloutCTA_send
                )
            ]
        case .overMaximumSourceLimit(let availableAmount, _, let desiredAmount) where action == .send:
            callouts = [
                ErrorRecoveryState.Callout(
                    id: ErrorRecoveryCalloutIdentifier.buy.rawValue,
                    image: availableAmount.currency.image,
                    title: String.localizedStringWithFormat(
                        Localization.overMaximumSourceLimitRecoveryCalloutTitle_send,
                        availableAmount.displayCode
                    ),
                    message: String.localizedStringWithFormat(
                        Localization.overMaximumSourceLimitRecoveryCalloutMessage_send,
                        desiredAmount.displayString
                    ),
                    callToAction: Localization.overMaximumSourceLimitRecoveryCalloutCTA_send
                )
            ]
        case .overMaximumPersonalLimit(_, _, let suggestedUpgrade):
            let calloutTitle: String
            switch action {
            case .buy:
                calloutTitle = Localization.overMaximumPersonalLimitRecoveryCalloutTitle_buy
            case .swap:
                calloutTitle = Localization.overMaximumPersonalLimitRecoveryCalloutTitle_swap
            case .send:
                calloutTitle = Localization.overMaximumPersonalLimitRecoveryCalloutTitle_send
            default:
                calloutTitle = Localization.overMaximumPersonalLimitRecoveryCalloutTitle_other
            }
            callouts = suggestedUpgrade == nil ? [] : [
                ErrorRecoveryState.Callout(
                    id: ErrorRecoveryCalloutIdentifier.upgradeKYCTier.rawValue,
                    image: ImageResource.local(
                        name: "kyc-gold",
                        bundle: .main
                    ).image!,
                    title: calloutTitle,
                    message: Localization.overMaximumPersonalLimitRecoveryCalloutMessage,
                    callToAction: Localization.overMaximumPersonalLimitRecoveryCalloutCTA
                )
            ]
        default:
            callouts = []
        }
        return callouts
    }
}

// MARK: - Helpers

extension TransactionErrorState {

    private func transactionErrorDescription(for networkError: NabuNetworkError, action: AssetAction) -> String {
        let errorDescription: String
        switch networkError {
        case .nabuError(let error):
            errorDescription = transactionErrorDescription(for: error.code, action: action)
        case .communicatorError(let error):
            errorDescription = String(describing: error)
        }
        return errorDescription
    }

    private func transactionErrorDescription(for fatalError: FatalTransactionError, action: AssetAction) -> String {
        let errorDescription: String
        switch fatalError {
        case .generic(let error):
            if let error = error as? OrderConfirmationServiceError, case .nabu(let networkError) = error {
                errorDescription = transactionErrorDescription(for: networkError, action: action)
            } else if let networkError = error as? NabuNetworkError {
                errorDescription = transactionErrorDescription(for: networkError, action: action)
            } else if let validationError = error as? TransactionValidationFailure {
                errorDescription = validationError.state.mapToTransactionErrorState.recoveryWarningTitle(for: action)
            } else {
                errorDescription = Localization.unknownError
            }

        default:
            errorDescription = fatalError.localizedDescription
        }
        return errorDescription
    }

    private func transactionErrorTitle(for code: NabuErrorCode, action: AssetAction) -> String? {
        switch code {
        case .cardInsufficientFunds:
            return Localization.cardInsufficientFundsTitle
        case .cardBankDecline:
            return Localization.cardBankDeclineTitle
        case .cardDuplicate:
            return Localization.cardDuplicateTitle
        case .cardBlockchainDecline:
            return Localization.cardBankDeclineTitle
        case .cardAcquirerDecline:
            return Localization.cardAcquirerDeclineTitle
        case .cardPaymentNotSupported:
            return Localization.cardUnsupportedPaymentMethodTitle
        case .cardCreateFailed:
            return Localization.cardCreateFailedTitle
        case .cardPaymentFailed:
            return Localization.cardPaymentFailedTitle
        default:
            return nil
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func transactionErrorDescription(for code: NabuErrorCode, action: AssetAction) -> String {
        switch code {
        case .notFound:
            return Localization.notFound
        case .orderBelowMinLimit:
            return String(format: Localization.tradingBelowMin, action.name)
        case .orderAboveMaxLimit:
            return String(format: Localization.tradingAboveMax, action.name)
        case .dailyLimitExceeded:
            return String(format: Localization.tradingDailyExceeded, action.name)
        case .weeklyLimitExceeded:
            return String(format: Localization.tradingWeeklyExceeded, action.name)
        case .annualLimitExceeded:
            return String(format: Localization.tradingYearlyExceeded, action.name)
        case .tradingDisabled:
            return Localization.tradingServiceDisabled
        case .pendingOrdersLimitReached:
            return Localization.pendingOrderLimitReached
        case .invalidCryptoAddress:
            return Localization.tradingInvalidAddress
        case .invalidCryptoCurrency:
            return Localization.tradingInvalidCurrency
        case .invalidFiatCurrency:
            return Localization.tradingInvalidFiat
        case .orderDirectionDisabled:
            return Localization.tradingDirectionDisabled
        case .userNotEligibleForSwap:
            return Localization.tradingIneligibleForSwap
        case .invalidDestinationAddress:
            return Localization.tradingInvalidAddress
        case .notFoundCustodialQuote:
            return Localization.tradingQuoteInvalidOrExpired
        case .orderAmountNegative:
            return Localization.tradingInvalidDestinationAmount
        case .withdrawalForbidden:
            return Localization.pendingWithdraw
        case .withdrawalLocked:
            return Localization.withdrawBalanceLocked
        case .insufficientBalance:
            return String(format: Localization.tradingInsufficientBalance, action.name)
        case .albertExecutionError:
            return Localization.tradingAlbertError
        case .orderInProgress:
            return String(format: Localization.tooManyTransaction, action.name)
        case .cardInsufficientFunds:
            return Localization.cardInsufficientFunds
        case .cardBankDecline:
            return Localization.cardBankDecline
        case .cardDuplicate:
            return Localization.cardDuplicate
        case .cardBlockchainDecline:
            return Localization.cardBankDecline
        case .cardAcquirerDecline:
            return Localization.cardBankDecline
        case .cardPaymentNotSupported:
            return Localization.cardUnsupportedPaymentMethod
        case .cardCreateFailed:
            return Localization.cardCreateFailed
        case .cardPaymentFailed:
            return Localization.cardPaymentFailed
        default:
            return Localization.unknownError
        }
    }

    private func localizedInsufficientFundsMessage(action: AssetAction) -> String {
        guard case .insufficientFunds(let balance, _, let sourceCurrency, let targetCurrency) = self else {
            impossible("Developer error")
        }
        let text: String
        switch action {
        case .buy:
            text = String.localizedStringWithFormat(
                Localization.insufficientFundsRecoveryMessage_buy,
                targetCurrency.code,
                sourceCurrency.code,
                balance.displayString
            )
        case .sell:
            text = String.localizedStringWithFormat(
                Localization.insufficientFundsRecoveryMessage_sell,
                sourceCurrency.code,
                balance.displayString
            )
        case .swap:
            text = String.localizedStringWithFormat(
                Localization.insufficientFundsRecoveryMessage_swap,
                sourceCurrency.code,
                targetCurrency.code,
                balance.displayString
            )
        case .send,
             .interestTransfer:
            text = String.localizedStringWithFormat(
                Localization.insufficientFundsRecoveryMessage_send,
                sourceCurrency.code,
                balance.displayString
            )
        case .withdraw,
             .interestWithdraw:
            text = String.localizedStringWithFormat(
                Localization.insufficientFundsRecoveryMessage_withdraw,
                sourceCurrency.code,
                balance.displayString
            )
        case .receive,
             .deposit,
             .sign,
             .viewActivity:
            impossible("This message should not be needed for \(action)")
        }
        return text
    }

    private func localizedBelowMinimumLimitMessage(action: AssetAction) -> String {
        guard case .belowMinimumLimit(let minimum) = self else {
            impossible("Developer error")
        }
        let text: String
        switch action {
        case .buy:
            text = String.localizedStringWithFormat(
                Localization.belowMinimumLimitRecoveryMessage_buy,
                minimum.displayString
            )
        case .sell:
            text = String.localizedStringWithFormat(
                Localization.belowMinimumLimitRecoveryMessage_sell,
                minimum.displayString
            )
        case .swap:
            text = String.localizedStringWithFormat(
                Localization.belowMinimumLimitRecoveryMessage_swap,
                minimum.displayString
            )
        case .send,
             .interestTransfer:
            text = String.localizedStringWithFormat(
                Localization.belowMinimumLimitRecoveryMessage_send,
                minimum.displayString
            )
        case .deposit:
            text = String.localizedStringWithFormat(
                Localization.belowMinimumLimitRecoveryMessage_deposit,
                minimum.displayString
            )
        case .withdraw,
             .interestWithdraw:
            text = String.localizedStringWithFormat(
                Localization.belowMinimumLimitRecoveryMessage_withdraw,
                minimum.displayString
            )
        case .receive,
             .sign,
             .viewActivity:
            impossible("This message should not be needed for \(action)")
        }
        return text
    }

    private func localizedOverMaxSourceLimitMessage(action: AssetAction) -> String {
        guard case .overMaximumSourceLimit(let availableAmount, let accountLabel, let desiredAmount) = self else {
            impossible("Developer error")
        }
        let text: String
        switch action {
        case .buy:
            let format: String
            if accountLabel.contains(availableAmount.displayCode) {
                format = Localization.overMaximumSourceLimitRecoveryMessage_buy_funds
            } else {
                format = Localization.overMaximumSourceLimitRecoveryMessage_buy
            }
            text = String.localizedStringWithFormat(
                format,
                accountLabel,
                availableAmount.shortDisplayString,
                desiredAmount.shortDisplayString
            )
        case .sell:
            text = String.localizedStringWithFormat(
                Localization.overMaximumSourceLimitRecoveryMessage_sell,
                availableAmount.shortDisplayString,
                desiredAmount.shortDisplayString
            )
        case .swap:
            text = String.localizedStringWithFormat(
                Localization.overMaximumSourceLimitRecoveryMessage_swap,
                availableAmount.shortDisplayString,
                desiredAmount.shortDisplayString
            )
        case .send:
            text = String.localizedStringWithFormat(
                Localization.overMaximumSourceLimitRecoveryMessage_send,
                availableAmount.shortDisplayString,
                desiredAmount.shortDisplayString
            )
        case .deposit:
            text = String.localizedStringWithFormat(
                Localization.overMaximumSourceLimitRecoveryMessage_deposit,
                accountLabel,
                availableAmount.shortDisplayString,
                desiredAmount.shortDisplayString
            )
        case .withdraw:
            text = String.localizedStringWithFormat(
                Localization.overMaximumSourceLimitRecoveryMessage_withdraw,
                availableAmount.shortDisplayString,
                desiredAmount.shortDisplayString
            )
        case .receive,
             .interestTransfer,
             .interestWithdraw,
             .sign,
             .viewActivity:
            impossible("This message should not be needed for \(action)")
        }
        return text
    }

    private func localizedOverMaxPersonalLimitMessage(action: AssetAction) -> String {
        guard case .overMaximumPersonalLimit(let limit, let available, let suggestedUpgrade) = self else {
            impossible("Developer error")
        }
        let text: String
        switch action {
        case .buy:
            text = localizedOverMaxPersonalLimitMessageForBuy(
                effectiveLimit: limit,
                availableAmount: available,
                suggestedUpgrade: suggestedUpgrade
            )
        case .sell:
            text = localizedOverMaxPersonalLimitMessageForSell(
                effectiveLimit: limit,
                availableAmount: available,
                suggestedUpgrade: suggestedUpgrade
            )
        case .swap:
            text = localizedOverMaxPersonalLimitMessageForSwap(
                effectiveLimit: limit,
                availableAmount: available,
                suggestedUpgrade: suggestedUpgrade
            )
        case .send:
            text = localizedOverMaxPersonalLimitMessageForSend(
                effectiveLimit: limit,
                availableAmount: available,
                suggestedUpgrade: suggestedUpgrade
            )
        case .withdraw:
            text = localizedOverMaxPersonalLimitMessageForWithdraw(
                effectiveLimit: limit,
                availableAmount: available,
                suggestedUpgrade: suggestedUpgrade
            )
        case .receive,
             .deposit,
             .interestTransfer,
             .interestWithdraw,
             .sign,
             .viewActivity:
            impossible("This message should not be needed for \(action)")
        }
        return text
    }

    private func localizedOverMaxPersonalLimitMessageForBuy(
        effectiveLimit: EffectiveLimit,
        availableAmount: MoneyValue,
        suggestedUpgrade: SuggestedLimitsUpgrade?
    ) -> String {
        let format: String
        if effectiveLimit.timeframe == .single {
            format = Localization.overMaximumPersonalLimitRecoveryMessage_buy_single
        } else if suggestedUpgrade?.requiredTier == .tier2 {
            format = Localization.overMaximumPersonalLimitRecoveryMessage_buy_gold
        } else {
            format = Localization.overMaximumPersonalLimitRecoveryMessage_buy_other
        }
        return String.localizedStringWithFormat(
            format,
            localized(effectiveLimit, availableAmount: availableAmount),
            availableAmount.displayString
        )
    }

    private func localizedOverMaxPersonalLimitMessageForSell(
        effectiveLimit: EffectiveLimit,
        availableAmount: MoneyValue,
        suggestedUpgrade: SuggestedLimitsUpgrade?
    ) -> String {
        let format: String
        if effectiveLimit.timeframe == .single {
            format = Localization.overMaximumPersonalLimitRecoveryMessage_sell_single
        } else if suggestedUpgrade?.requiredTier == .tier2 {
            format = Localization.overMaximumPersonalLimitRecoveryMessage_sell_gold
        } else {
            format = Localization.overMaximumPersonalLimitRecoveryMessage_sell_other
        }
        return String.localizedStringWithFormat(
            format,
            localized(effectiveLimit, availableAmount: availableAmount),
            availableAmount.displayString
        )
    }

    private func localizedOverMaxPersonalLimitMessageForSwap(
        effectiveLimit: EffectiveLimit,
        availableAmount: MoneyValue,
        suggestedUpgrade: SuggestedLimitsUpgrade?
    ) -> String {
        let format: String
        if effectiveLimit.timeframe == .single {
            format = Localization.overMaximumPersonalLimitRecoveryMessage_swap_single
        } else if suggestedUpgrade?.requiredTier == .tier2 {
            format = Localization.overMaximumPersonalLimitRecoveryMessage_swap_gold
        } else {
            format = Localization.overMaximumPersonalLimitRecoveryMessage_swap_other
        }
        return String.localizedStringWithFormat(
            format,
            localized(effectiveLimit, availableAmount: availableAmount),
            availableAmount.displayString
        )
    }

    private func localizedOverMaxPersonalLimitMessageForSend(
        effectiveLimit: EffectiveLimit,
        availableAmount: MoneyValue,
        suggestedUpgrade: SuggestedLimitsUpgrade?
    ) -> String {
        let format: String
        if effectiveLimit.timeframe == .single {
            format = Localization.overMaximumPersonalLimitRecoveryMessage_send_single
        } else if suggestedUpgrade?.requiredTier == .tier2 {
            format = Localization.overMaximumPersonalLimitRecoveryMessage_send_gold
        } else {
            format = Localization.overMaximumPersonalLimitRecoveryMessage_send_other
        }
        return String.localizedStringWithFormat(
            format,
            localized(effectiveLimit, availableAmount: availableAmount),
            availableAmount.displayString
        )
    }

    private func localizedOverMaxPersonalLimitMessageForWithdraw(
        effectiveLimit: EffectiveLimit,
        availableAmount: MoneyValue,
        suggestedUpgrade: SuggestedLimitsUpgrade?
    ) -> String {
        String.localizedStringWithFormat(
            Localization.overMaximumPersonalLimitRecoveryMessage_withdraw,
            localized(effectiveLimit, availableAmount: availableAmount),
            availableAmount.displayString
        )
    }

    private func localized(_ effectiveLimit: EffectiveLimit, availableAmount: MoneyValue) -> String {
        let localizedEffectiveLimit: String
        switch effectiveLimit.timeframe {
        case .daily:
            localizedEffectiveLimit = String.localizedStringWithFormat(
                Localization.overMaximumSourceLimitRecoveryValueTimeFrameDay,
                effectiveLimit.value.shortDisplayString
            )
        case .monthly:
            localizedEffectiveLimit = String.localizedStringWithFormat(
                Localization.overMaximumSourceLimitRecoveryValueTimeFrameMonth,
                effectiveLimit.value.shortDisplayString
            )
        case .yearly:
            localizedEffectiveLimit = String.localizedStringWithFormat(
                Localization.overMaximumSourceLimitRecoveryValueTimeFrameYear,
                effectiveLimit.value.shortDisplayString
            )
        case .single:
            localizedEffectiveLimit = availableAmount.shortDisplayString
        }
        return localizedEffectiveLimit
    }
}

enum ErrorRecoveryCalloutIdentifier: String {
    case buy
    case upgradeKYCTier
}
