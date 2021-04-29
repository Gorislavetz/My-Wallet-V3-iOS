// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Foundation

@objc protocol WalletTransferAllDelegate: class {

    /// Method invoked when calculation of total amount to transfer is completed
    func updateTransferAll(amount: NSNumber, fee: NSNumber, addressesUsed: [Any])

    /// Method invoked when a user is ready to transfer all
    func showSummaryForTransferAll()

    /// Method invoked when user confirms to transfer all
    func sendDuringTransferAll(secondPassword: String?)

    /// Method invoked when an error occurs while transferring all
    func didErrorDuringTransferAll(error: String, secondPassword: String?)
}
