// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import PlatformKit

enum TransactionUIKitError: Error {
    case emptySourceExchangeRate
    case emptyDestinationExchangeRate
    case emptySourceDestinationExchangeRate
    case emptySourceAccount
    case emptyDestinationAccount
    case unexpectedDestinationAccountType
    case unexpectedMoneyValueType(MoneyValue)
    case unexpectedCurrencyType(CurrencyType)
}
