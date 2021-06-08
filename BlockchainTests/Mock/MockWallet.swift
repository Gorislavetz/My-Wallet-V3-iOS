// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Foundation

@testable import Blockchain

class MockWallet: Wallet {

    var mockIsInitialized: Bool = false

    override func isInitialized() -> Bool {
        mockIsInitialized
    }

    var guid: String = ""
    var sharedKey: String?
    private var password: String?

    /// When called, invokes the delegate's walletDidDecrypt and walletDidFinishLoad methods
    override func load(withGuid guid: String, sharedKey: String?, password: String?) {
        self.delegate?.walletDidDecrypt?(withSharedKey: sharedKey, guid: guid)
        self.delegate?.walletDidFinishLoad?()
    }

    var fetchCalled = false
    override func fetch(with password: String) {
        fetchCalled = true
        self.password = password
        load(withGuid: guid, sharedKey: sharedKey, password: password)
    }
}
