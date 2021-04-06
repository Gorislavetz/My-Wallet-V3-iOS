//
//  TransactionConfirmation.Model.swift
//  TransactionKit
//
//  Created by Paulo on 17/12/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import Localization
import PlatformKit

extension TransactionConfirmation {
    public enum Model { }
}

extension TransactionConfirmation.Model {
    private typealias LocalizedString = LocalizationConstants.Transaction.Confirmation

    public struct ExchangePriceOption: TransactionConfirmationModelable {
        public let money: MoneyValue
        public let currency: CryptoCurrency
        public let type: TransactionConfirmation.Kind = .readOnly

        public var formatted: (String, String)? {
            (String(format: LocalizedString.price, currency.displayCode),
             money.displayString)
        }
    }

    public struct FeedTotal: TransactionConfirmationModelable {
        public let amount: MoneyValue
        public let amountInFiat: MoneyValue
        public let fee: MoneyValue
        public let feeInFiat: MoneyValue
        public let type: TransactionConfirmation.Kind = .readOnly

        public var formatted: (String, String)? {
            (LocalizedString.total, amountString)
        }
        public init(
            amount: MoneyValue,
            amountInFiat: MoneyValue,
            fee: MoneyValue,
            feeInFiat: MoneyValue
        ) {
            self.amount = amount
            self.amountInFiat = amountInFiat
            self.fee = fee
            self.feeInFiat = feeInFiat
        }

        private var amountString: String {
            if amount.currency == fee.currency {
                return amountStringSameCurrency
            } else {
                return amountStringDifferentCurrencies
            }
        }

        private var amountStringSameCurrency: String {
            guard let total = try? amount + fee else {
                return ""
            }
            guard let totalFiat = try? amountInFiat + feeInFiat else {
                return ""
            }
            return "\(total.displayString) (\(totalFiat.displayString))"
        }

        private var amountStringDifferentCurrencies: String {
            "\(amount.displayString) (\(amountInFiat.displayString))\n\(fee.displayString) (\(feeInFiat.displayString))"
        }
    }

    public struct Total: TransactionConfirmationModelable {
        public let total: MoneyValue
        public let exchange: MoneyValue?
        public let type: TransactionConfirmation.Kind = .readOnly

        public init(total: MoneyValue, exchange: MoneyValue? = nil) {
            self.total = total
            self.exchange = exchange
        }

        public var formatted: (String, String)? {
            var value: String = total.displayString
            if let exchange = exchange,
               let converted = try? total.convert(using: exchange) {
                value = converted.displayString
            }
            return (LocalizedString.total, value)
        }
    }

    public struct Destination: TransactionConfirmationModelable {
        public let value: String
        public let type: TransactionConfirmation.Kind = .readOnly

        public var formatted: (String, String)? {
            (LocalizedString.to, value)
        }

        public init(value: String) {
            self.value = value
        }
    }

    public struct Source: TransactionConfirmationModelable {
        public let value: String
        public let type: TransactionConfirmation.Kind = .readOnly

        public var formatted: (String, String)? {
            (LocalizedString.from, value)
        }

        public init(value: String) {
            self.value = value
        }
    }

    public struct FeeSelection: TransactionConfirmationModelable {
        public let feeState: FeeState
        public let selectedLevel: FeeLevel
        public let fee: MoneyValue?
        public let type: TransactionConfirmation.Kind = .feeSelection
        public var formatted: (String, String)? {
            ("Transaction Fee", fee?.toDisplayString(includeSymbol: true) ?? "")
        }

        public init(feeState: FeeState, selectedLevel: FeeLevel, fee: MoneyValue?) {
            self.feeState = feeState
            self.selectedLevel = selectedLevel
            self.fee = fee
        }
    }

    public struct BitPayCountdown: TransactionConfirmationModelable {
        public let secondsRemaining: TimeInterval
        public let type: TransactionConfirmation.Kind = .invoiceCountdown

        public var formatted: (String, String)? {
            nil
        }
    }

    public struct ErrorNotice: TransactionConfirmationModelable {
        public let validationState: TransactionValidationState
        public let type: TransactionConfirmation.Kind = .errorNotice
        public let moneyValue: MoneyValue?

        public init(validationState: TransactionValidationState, moneyValue: MoneyValue?) {
            self.validationState = validationState
            self.moneyValue = moneyValue
        }

        // By the time we are on the confirmation screen most of these possible error should have been
        // filtered out. A few remain possible, because BE failures or BitPay invoices, thus:
        public var formatted: (String, String)? {
            switch validationState {
            case .canExecute, .uninitialized:
                return nil
            case .belowMinimumLimit:
                let message: String
                if let value = moneyValue {
                    message = String(
                        format: LocalizedString.Error.underMinLimit,
                        value.toDisplayString(includeSymbol: true)
                    )
                } else {
                    message = LocalizedString.Error.underMinBitcoinFee
                }
                return (LocalizedString.Error.title, message)
            case .insufficientFunds:
                return (LocalizedString.Error.title, LocalizedString.Error.insufficientFunds)
            case .insufficientGas:
                return (LocalizedString.Error.title, LocalizedString.Error.insufficientGas)
            case .invalidAmount:
                return (LocalizedString.Error.title, LocalizedString.Error.invalidAmount)
            case .invoiceExpired:
                return (LocalizedString.Error.title, LocalizedString.Error.invoiceExpired)
            case .transactionInFlight:
                return (LocalizedString.Error.title, LocalizedString.Error.transactionInFlight)
            case .addressIsContract,
                 .invalidAddress,
                 .insufficientFundsForFees,
                 .optionInvalid,
                 .overGoldTierLimit,
                 .overMaximumLimit,
                 .overSilverTierLimit,
                 .pendingOrdersLimitReached,
                 .unknownError:
                return (LocalizedString.Error.title, LocalizedString.Error.generic)
            }
        }
    }

    public struct Description: TransactionConfirmationModelable {
        public let value: String
        public let type: TransactionConfirmation.Kind = .description
        
        public var formatted: (String, String)? {
            (LocalizedString.description, value)
        }
        
        public init(value: String = "") {
            self.value = value
        }
    }

    public struct Memo: TransactionConfirmationModelable {
        public enum Value: Equatable {
            case text(String)
            case identifier(Int)

            public static func ==(lhs: Value, rhs: Value) -> Bool {
                switch (lhs, rhs) {
                case let (.text(lhs), .text(rhs)):
                    return lhs == rhs
                case let (.identifier(lhs), .identifier(rhs)):
                    return lhs == rhs
                default:
                    return false
                }
            }

            var string: String {
                switch self {
                case .text(let string):
                    return string
                case .identifier(let identifier):
                    return String(identifier)
                }
            }
        }
        public let value: Value?
        public let required: Bool
        public let type: TransactionConfirmation.Kind = .memo

        public var formatted: (String, String)? {
            (LocalizedString.memo, value?.string ?? "")
        }

        public init(textMemo: String?, required: Bool) {
            self.value = textMemo.flatMap { Value.text($0) }
            self.required = required
        }
    }

    public struct SwapSourceValue: TransactionConfirmationModelable {
        public let cryptoValue: CryptoValue
        public let type: TransactionConfirmation.Kind = .readOnly

        public var formatted: (String, String)? {
            (LocalizationConstants.Transaction.Swap.swap, cryptoValue.displayString)
        }
    }

    public struct SwapDestinationValue: TransactionConfirmationModelable {
        public let cryptoValue: CryptoValue
        public let type: TransactionConfirmation.Kind = .readOnly

        public var formatted: (String, String)? {
            (LocalizationConstants.Transaction.receive, cryptoValue.displayString)
        }
    }

    public struct SwapExchangeRate: TransactionConfirmationModelable {
        public let baseValue: MoneyValue
        public let resultValue: MoneyValue
        public let type: TransactionConfirmation.Kind = .readOnly

        public var formatted: (String, String)? {
            (LocalizedString.exchangeRate, "\(baseValue.displayString) = \(resultValue.displayString)")
        }
    }

    public struct NetworkFee: TransactionConfirmationModelable {
        public enum FeeType {
            case depositFee
            case withdrawalFee
        }
        public let fee: MoneyValue
        public let feeType: FeeType
        public let asset: CryptoCurrency
        public let type: TransactionConfirmation.Kind = .networkFee

        public var formatted: (String, String)? {
            (String(format: LocalizedString.networkFee, asset.displayCode),
             fee.displayString)
        }
    }

    public struct AnyBoolOption<T: Equatable>: TransactionConfirmationModelable {
        public let data: T?
        public let value: Bool
        public let type: TransactionConfirmation.Kind

        public var formatted: (String, String)? {
            ("\(value) Data", "\(data.debugDescription)")
        }

        public init(value: Bool, type: TransactionConfirmation.Kind, data: T? = nil) {
            self.value = value
            self.data = data
            self.type = type
        }
    }
}
