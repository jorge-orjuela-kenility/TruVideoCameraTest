//
//  PublisherListener.swift
//  TruVideoExample
//
//  Created by Jorge Orjuela on 6/16/23.
//

import Combine
import SwiftUI

extension Publisher {
    typealias Result<T> = (previous: T?, current: T)

    /// Includes the current element as well as the previous element from the upstream publisher in a tuple where the previous element is optional.
    /// The first time the upstream publisher emits an element, the previous element will be `nil`.
    ///
    /// ```
    /// let range = (1...5)
    /// let subscription = range.publisher
    ///   .pairwise()
    ///   .sink { print("(\($0.previous), \($0.current))", terminator: " ") }
    /// ```
    /// Prints: "(nil, 1) (Optional(1), 2) (Optional(2), 3) (Optional(3), 4) (Optional(4), 5)".
    ///
    /// - Returns: A publisher of a tuple of the previous and current elements from the upstream publisher.
    /// - Note: Based on <https://stackoverflow.com/a/67133582/3532505>.
    func pairwise() -> AnyPublisher<Result<Output>, Failure> {
        scan(nil) { previous, current -> Result<Output>? in
            Result(previous: previous?.current, current: current)
        }
        .compactMap { $0 }
        .eraseToAnyPublisher()
    }
}

struct PublisherListener<P, V, C>: View where P: Publisher<V, Never>, V: Equatable, C: View {
    /// Callback definition for the  `builder`  which takes the  `state` and is responsible
    /// for returning a `View` which is to be rendered.
    typealias BuilderCallback = (V) -> C

    /// Callback definition for the  `listener`  which takes the  `value`
    typealias ListenerCallback = (V) -> Void

    /// Callback definition for the `buildWhen` function which takes the previous `value`
    /// and the current `state` and is responsible for returning a bool which
    /// determines whether or not to call  the  `ViewModelListener` with the current `value`.
    typealias BuilderConditionCallback = (V, V) -> Bool

    /// Callback definition for the `listenWhen` function which takes the previous `value`
    /// and the current `state` and is responsible for returning a bool which
    /// determines whether or not to call  the  `ViewModelListener` with the current `value`.
    typealias ListenerConditionCallback = (V, V) -> Bool

    /// The builder which will be called on every `value` change if needed.
    private let builder: BuilderCallback

    /// The  builder which will be called on every `value` change.
    private let buildWhen: BuilderConditionCallback?

    /// The listener which will be called on every `value` change if needed.
    private let listener: ListenerCallback?

    /// The  listener which will be called on every `value` change.
    private let listenWhen: ListenerConditionCallback?

    /// The  value used to force the view redrawing.
    @State private var value: V

    /// The associated publisher
    private let publisher: P

    /// The content and behavior of the view.
    var body: some View {
        builder(value)
            .onReceive(publisher.pairwise()) { value in
                guard let previous = value.previous else { return }
                
                if listenWhen?(previous, value.current) ?? (value.previous != value.current) {
                    listener?(value.current)
                }

                if buildWhen?(previous, value.current) ?? (previous != value.current) {
                    self.value = value.current
                }
            }
    }

    // MARK: Initializers

    /// Creates a new instance of the `PublisherListener`.
    ///
    /// - Parameters:
    ///    - initialValue: The initial value to publish.
    ///    - publisher: The publisher to listen.
    ///    - buildWhen: The  builder which will be called on every `value` change.
    ///    - listenWhen: The  listener which will be called on every `value` change.
    ///    - builder: The builder which will be called on every `value` change if needed.
    private init(
        initialValue: P.Output,
        publisher: P,
        buildWhen: BuilderConditionCallback?,
        listenWhen: ListenerConditionCallback?,
        listener: ListenerCallback?,
        @ViewBuilder builder: @escaping BuilderCallback
    ) {

        self._value = .init(wrappedValue: initialValue)
        self.builder = builder
        self.buildWhen = buildWhen
        self.listener = listener
        self.listenWhen = listenWhen
        self.publisher = publisher
    }

    /// Creates a new instance of the `PublisherListener`.
    ///
    /// - Parameters:
    ///    - initialValue: The initial value to publish.
    ///    - publisher: The publisher to listen.
    ///    - buildWhen: The  builder which will be called on every `state` change.
    ///    - builder: The builder which will be called on every `state` change if needed.
    init(
        initialValue: P.Output,
        publisher: P,
        buildWhen: BuilderConditionCallback? = nil,
        @ViewBuilder builder: @escaping BuilderCallback
    ) {

        self.init(
            initialValue: initialValue,
            publisher: publisher,
            buildWhen: buildWhen,
            listenWhen: nil,
            listener: nil,
            builder: builder
        )
    }

    // MARK: Instance methods

    /// Adds a listener which will be called on every `value` change if needed.
    ///
    /// - Parameters:
    ///    - listenWhen: The listener condition callback managing when the `listener` wiill be called
    ///    - listener: The callback to invoke when the state changes
    /// - Returns: A new instance of `ViewModelListener`
    func listen(when listenWhen: @escaping ListenerConditionCallback, listener: @escaping ListenerCallback) -> Self {
        .init(
            initialValue: value,
            publisher: publisher,
            buildWhen: buildWhen,
            listenWhen: listenWhen,
            listener: listener,
            builder: builder
        )
    }
}
