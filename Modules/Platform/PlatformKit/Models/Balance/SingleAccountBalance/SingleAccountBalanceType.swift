// Copyright © Blockchain Luxembourg S.A. All rights reserved.

@available(*, deprecated, message: "We need to shift to using models returned by Coincore.")
public protocol SingleAccountBalanceType {
    var available: MoneyValue { get }
}
