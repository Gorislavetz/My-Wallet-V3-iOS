// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
import CombineExt
import DIKit
import RxRelay
import RxSwift
import ToolKit

final class EligibilityService: EligibilityServiceAPI {

    // MARK: - Properties

    var isEligiblePublisher: AnyPublisher<Bool, Never> {
        isEligible
            .asPublisher()
            .replaceError(with: false)
            .eraseToAnyPublisher()
    }

    var isEligible: Single<Bool> {
        isEligibileValue
            .valueSingle
    }

    private let isEligibileValue: CachedValue<Bool>
    private let client: EligibilityClientAPI
    private let reactiveWallet: ReactiveWalletAPI
    private let fiatCurrencyService: FiatCurrencySettingsServiceAPI

    // MARK: - Setup

    init(
        client: EligibilityClientAPI = resolve(),
        reactiveWallet: ReactiveWalletAPI = resolve(),
        fiatCurrencyService: FiatCurrencySettingsServiceAPI = resolve()
    ) {
        self.client = client
        self.reactiveWallet = reactiveWallet
        self.fiatCurrencyService = fiatCurrencyService
        isEligibileValue = CachedValue(
            configuration: .periodic(
                seconds: 30,
                schedulerIdentifier: "EligibilityService"
            )
        )

        isEligibileValue.setFetch(weak: self) { (self) in
            self.reactiveWallet.waitUntilInitializedSingle
                .flatMap(weak: self) { (self, _) -> Single<Bool> in
                    self.fiatCurrencyService.fiatCurrency
                        .flatMap { currency -> Single<EligibilityResponse> in
                            self.client.isEligible(
                                for: currency.code,
                                methods: [
                                    PaymentMethodPayloadType.bankTransfer.rawValue,
                                    PaymentMethodPayloadType.card.rawValue
                                ]
                            )
                            .asSingle()
                        }
                        .map(\.eligible)
                }
        }
    }

    func fetch() -> Single<Bool> {
        isEligibileValue.fetchValue
    }
}
