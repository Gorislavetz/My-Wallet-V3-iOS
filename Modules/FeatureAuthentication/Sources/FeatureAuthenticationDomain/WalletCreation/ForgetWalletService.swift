// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
import ToolKit
import WalletPayloadKit

public struct ForgetWalletService {
    /// Clears the in-memory wallet state and removes values from `WalletRepo`
    public var forget: () -> Void
}

extension ForgetWalletService {
    public static func live(
        forgetWallet: ForgetWalletAPI
    ) -> ForgetWalletService {
        ForgetWalletService(
            forget: {
                forgetWallet.forget()
            }
        )
    }
}
