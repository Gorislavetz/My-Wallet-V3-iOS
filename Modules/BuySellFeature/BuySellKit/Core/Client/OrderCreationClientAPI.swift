// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import RxSwift

protocol OrderCreationClientAPI: class {
    
    /// Creates a buy order using the given data
    func create(order: OrderPayload.Request, createPendingOrder: Bool) -> Single<OrderPayload.Response>
}

