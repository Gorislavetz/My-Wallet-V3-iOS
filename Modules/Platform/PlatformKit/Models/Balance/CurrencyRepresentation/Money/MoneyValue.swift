// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BigInt
import ToolKit

public enum MoneyValueError: Error {
    case invalidInput
    case invalidFiatAmount
    case invalidCryptoAmount
}

public struct MoneyValue: Money, Hashable, Equatable {
    
    private enum Value: Hashable, Equatable {
        case fiat(FiatValue)
        case crypto(CryptoValue)
        
        init(major amount: String, fiat fiatCurrency: FiatCurrency) throws {
            guard let fiatValue = FiatValue.create(major: amount, currency: fiatCurrency) else {
                throw MoneyValueError.invalidCryptoAmount
            }
            self = .fiat(fiatValue)
        }
        
        init(major amount: String, crypto cryptoCurrency: CryptoCurrency) throws {
            guard let cryptoValue = CryptoValue.create(major: amount, currency: cryptoCurrency) else {
                throw MoneyValueError.invalidCryptoAmount
            }
            self = .crypto(cryptoValue)
        }
        
        init(minor amount: String, fiat fiatCurrency: FiatCurrency) throws {
            guard let fiatValue = FiatValue.create(minor: amount, currency: fiatCurrency) else {
                throw MoneyValueError.invalidFiatAmount
            }
            self = .fiat(fiatValue)
        }
        
        init(minor amount: String, crypto cryptoCurrency: CryptoCurrency) throws {
            guard let cryptoValue = CryptoValue.create(minor: amount, currency: cryptoCurrency) else {
                throw MoneyValueError.invalidCryptoAmount
            }
            self = .crypto(cryptoValue)
        }
    }
    
    // MARK: - Public properties
    
    public var isCrypto: Bool {
        switch _value {
        case .crypto:
            return true
        case .fiat:
            return false
        }
    }
    
    public var isFiat: Bool {
        !isCrypto
    }
    
    public var amount: BigInt {
        switch _value {
        case .crypto(let cryptoValue):
            return cryptoValue.amount
        case .fiat(let fiatValue):
            return fiatValue.amount
        }
    }

    public var fiatValue: FiatValue? {
        guard case Value.fiat(let value) = _value else {
            return nil
        }
        return value
    }
    
    public var cryptoValue: CryptoValue? {
        guard case Value.crypto(let value) = _value else {
            return nil
        }
        return value
    }
    
    public var currencyType: CurrencyType {
        switch _value {
        case .crypto(let cryptoValue):
            return cryptoValue.currency
        case .fiat(let fiatValue):
            return fiatValue.currency
        }
    }
    
    public var value: MoneyValue {
        self
    }
    
    // MARK: - Private properties
    
    private let _value: Value
    
    // MARK: - Setup
    
    public init(cryptoValue: CryptoValue) {
        self._value = .crypto(cryptoValue)
    }
    
    public init(fiatValue: FiatValue) {
        self._value = .fiat(fiatValue)
    }
    
    fileprivate init(major amount: String, currencyCode: String, locale: Locale = .current) throws {
        let currency = try CurrencyType(code: currencyCode)
        switch currency {
        case .crypto(let cryptoCurrency):
            self._value = try Value(major: amount, crypto: cryptoCurrency)
        case .fiat(let fiatCurrency):
            self._value = try Value(major: amount, fiat: fiatCurrency)
        }
    }
    
    fileprivate init(minor amount: String, currencyCode: String) throws {
        let currency = try CurrencyType(code: currencyCode)
        switch currency {
        case .crypto(let cryptoCurrency):
            self._value = try Value(minor: amount, crypto: cryptoCurrency)
        case .fiat(let fiatCurrency):
            self._value = try Value(minor: amount, fiat: fiatCurrency)
        }
    }
    
    public init(amount: BigInt, currency: CurrencyType) {
        switch currency {
        case .crypto(let cryptoCurrency):
            self._value = .crypto(CryptoValue(amount: amount, currency: cryptoCurrency))
        case .fiat(let fiatCurrency):
            self._value = .fiat(FiatValue(amount: amount, currency: fiatCurrency))
        }
    }
    
    // MARK: - Public methods
    
    public func toDisplayString(includeSymbol: Bool, locale: Locale) -> String {
        switch _value {
        case .crypto(let cryptoValue):
            return cryptoValue.toDisplayString(includeSymbol: includeSymbol, locale: locale)
        case .fiat(let fiatValue):
            return fiatValue.toDisplayString(includeSymbol: includeSymbol, locale: locale)
        }
    }
    
    public func value(before percentageChange: Double) -> MoneyValue {
        switch _value {
        case .fiat(let value):
            return MoneyValue(fiatValue: value.value(before: percentageChange))
        case .crypto(let value):
            return MoneyValue(cryptoValue: value.value(before: percentageChange))
        }
    }
    
    // MARK: - Public factory methods
    
    public static func zero(currency: CryptoCurrency) -> MoneyValue {
        MoneyValue(cryptoValue: CryptoValue.zero(currency: currency))
    }
    
    public static func zero(currency: FiatCurrency) -> MoneyValue {
        MoneyValue(fiatValue: FiatValue.zero(currency: currency))
    }
    
    public static func one(currency: CryptoCurrency) -> MoneyValue {
        let one = BigInt.one.toMinor(maxDecimalPlaces: currency.maxDecimalPlaces)
        return MoneyValue(cryptoValue: CryptoValue.create(minor: one, currency: currency))
    }
    
    public static func one(currency: FiatCurrency) -> MoneyValue {
        let one = BigInt.one.toMinor(maxDecimalPlaces: currency.maxDecimalPlaces)
        return MoneyValue(fiatValue: FiatValue.create(minor: one, currency: currency))
    }

    /// Use this method when you want to convert a `MoneyValue` in `A` currency into `B` currency and your exchange rate is in `B` currency.
    /// - Parameter exchangeRate:The `MoneyValue` representing one major unit of `Self.CurrencyType` in destination's `CurrencyType`.
    /// - Returns: `MoneyValue` of this instance value converted into the given `exchangeRate.currencyType`.
    public func convert(using exchangeRate: MoneyValue) throws -> MoneyValue {
        let exchangeRateAmount = exchangeRate.displayMajorValue
        let majorDecimal = displayMajorValue * exchangeRateAmount
        let major = "\(majorDecimal)"
        return try MoneyValue(major: major, currencyCode: exchangeRate.currencyType.code)
    }

    /// Use this method when you want to convert a `MoneyValue` in `A` currency into `B` currency and your exchange rate is in `A` currency.
    /// - Parameter exchangeRate: The `MoneyValue` representing one major unit of the destination `CurrencyType` in `Self.CurrencyType`.
    /// - Parameter currencyType: The destination `CurrencyType`.
    /// - Returns: `MoneyValue` of this instance value converted into the given `CurrencyType`, using the inverse of the given exchange rate.
    public func convert(usingInverse exchangeRate: MoneyValue, currencyType: CurrencyType) throws -> MoneyValue {
        guard !isZero else {
            return MoneyValue.zero(currency: currencyType)
        }
        guard !exchangeRate.isZero else {
            return MoneyValue.zero(currency: currencyType)
        }
        let exchangeRateAmount = exchangeRate.displayMajorValue
        let majorDecimal = displayMajorValue / exchangeRateAmount
        let major = "\(majorDecimal)"
        return try MoneyValue(major: major, currencyCode: currencyType.code)
    }
}

extension MoneyValue: MoneyOperating {}

extension MoneyValue {
    static func from(major amount: String, currencyCode: String) -> Result<MoneyValue, MoneyValueError> {
        Result { try MoneyValue(major: amount, currencyCode: currencyCode) }
            .mapError { _ in MoneyValueError.invalidInput }
    }
}

extension CryptoValue {
    public var moneyValue: MoneyValue {
        MoneyValue(cryptoValue: self)
    }
}

extension FiatValue {
    public var moneyValue: MoneyValue {
        MoneyValue(fiatValue: self)
    }
}
