// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import RxSwift

/// Fetches the supported pairs
protocol SupportedPairsClientAPI: class {
    /// Fetch the supported pairs according to a given fetch-option
    func supportedPairs(with option: SupportedPairsFilterOption) -> Single<SupportedPairsResponse>
}
