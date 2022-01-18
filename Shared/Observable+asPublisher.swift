//
//  Observable+asPublisher.swift
//  TestRxWithSwiftUI
//
//  Created by David Zorychta on 1/5/22.
//
// Apple Documentation for this was useful:
// https://developer.apple.com/documentation/combine/processing-published-elements-with-subscribers

import Foundation
import Combine
import RxSwift

// MARK: - asPublisher Extension

/// We want to turn an observable into a combine publisher. We do this by passing our observable into a new class we make in this file
/// called `CombinePublisher`. Combine has this concept of subscribers (think `.subscribe` or `.drive` in rx) and
/// subscriptions (think observables in rx). Combine is interesting in that it has both Publishers and Subscriptions BUT it is
/// important to note that a Publisher is not a subscription on its own, but we can use a Publisher to connect a
/// subscriber to a subscription.
///
/// What we're doing here is taking our observable, turning it into a subscription, and then turning the subscription into a publisher.
/// `Observable` -> `CombineSubscription` -> `CombinePublisher` -> `AnyPublisher<Element, Error>`

public extension ObservableConvertibleType {

  func asPublisher() -> AnyPublisher<Element, Swift.Error> {
    CombinePublisher(observable: self.asObservable()).eraseToAnyPublisher()
  }

  func receive<S>(subscriber: S) -> some Subscription
    where S : Subscriber, Swift.Error == S.Failure, Element == S.Input {
    CombineSubscription(subscriber: subscriber, observable: self.asObservable())
  }

}

// MARK: - Custom Publisher Implementation

/// Even though this class is the actual publisher that combine talks to, it's really just the glue that connects a subscriber
/// (downstream call like `sink` to a `Subscription`. A Subscription is the actual thing that wraps our
/// `Observable`, buffers it and sends its events to a subscriber

fileprivate final class CombinePublisher<Element>: Publisher {
  
  // Internal Types
  
  public typealias Output = Element
  public typealias Failure = Swift.Error
  
  // Privates
  
  private let observable: Observable<Element>
  
  // Lifecycle
  
  init(observable: Observable<Element>) {
    self.observable = observable
  }
  
  public func receive<S>(subscriber: S) where S : Subscriber, Swift.Error == S.Failure, Element == S.Input {
    _ = CombineSubscription(subscriber: subscriber, observable: observable)
  }
  
}

// MARK: - Custom Subscription Implementation

/// This wraps an Observable as a Subscription. Subscriptions in combine have a control flow mechanism called demand. A subscriber can
/// ask the subscription for more elements. This is actually kind of cool because it lets the consumer (subscriber) control when it runs.
/// Imagine a subscriber that performs some very expensive operation, and it wants to restrict itself to consuming and processing
/// just one element at a time. The subscriber can accomplish that by calling `subscription.request(.max(1))` and
/// if the subscription behaves, it will only emit 1 more element and stop generating or hold onto the remaining elements
/// until the subscriber asks for more. In reality I think this functionality isn't really used all that much, most subscribers
/// seem to always use `.unlimited` demand, but even so this wrapper supports it since it may be useful.
///
/// Note that we only begin emitting elements from our subscription (`subscriber.receive`) AFTER our subscriber tells us its ready
/// to receive them. In other words, we wait for an initial call from the subscriber to `subscription.request(_)` before
/// emitting anything. iOS 13 actually throws an exception if we were to call receive before the subscriber calls request!
///
/// We take an intentional performance hit here to make the wrapper thread safe with a serial queue. It's setup in such a way where
/// we always emit elements with the subscriber on the same thread as what the given observable is receiving on.

fileprivate let serial = DispatchQueue(label: "com.rx.combineSubscription")

#if DEBUG || TEST
public var combineSubscriptionDeinitCount: Int = 0 // Exposed for Tests
#endif

final class CombineSubscription<Target: Subscriber, Element>: Subscription
  where Target.Input == Element, Target.Failure == Swift.Error {
  
  // Privates
  
  private let observable: Observable<Element>
  private var disposeBag = DisposeBag()
  private var subscriber: Target
  
  private var subscriberDemand: Subscribers.Demand?
  private var subscriberStartedRequesting = false
  private var requestedElements: Int = 0
  private var buffer: [Element] = []
  
  // Lifecycle
  
  init(subscriber: Target, observable: Observable<Element>) {
    self.subscriber = subscriber
    self.observable = observable
    subscriber.receive(subscription: self)
    observable
      .subscribe(
        onNext: { [weak self] element in
          serial.sync { self?.buffer += [element] }
          self?.consumeFromBuffer(nil)
        },
        onError: { [weak self] in
          self?.subscriber.receive(completion: .failure($0))
          self?.cancel()
        },
        onCompleted: { [weak self] in
          self?.subscriber.receive(completion: .finished)
          self?.cancel()
        }
      )
      .disposed(by: disposeBag)
  }
  
  public func request(_ demand: Subscribers.Demand) {
    if !subscriberStartedRequesting {
      subscriberStartedRequesting = true
    }
    consumeFromBuffer(demand)
  }
  
  private func consumeFromBuffer(_ demand: Subscribers.Demand?) {
    var toReceive: [Element]?
    serial.sync {
      // each time the subscriber talks to us, track how many elements it asked us for
      if let demand = demand {
        subscriberDemand = demand
        requestedElements += demand.max ?? 0
      }
      // if the subscriber wants elements that we have in the buffer, lets prepare to give it to him!
      let receiveCount = subscriberDemand == .unlimited ? buffer.count : requestedElements
      if subscriberStartedRequesting && receiveCount > 0 && buffer.count > 0 {
        toReceive = Array(buffer.prefix(receiveCount))
        requestedElements = max(0, requestedElements - (toReceive?.count ?? 0))
        buffer = Array(buffer.suffix(max(0, buffer.count - receiveCount)))
      }
    }
    // now we give the above elements to the subscriber. Each time we give a subscriber elements, the subscriber
    // is allowed to tell us that it wants even more elements. We keep track of the count and call consume.
    // We also allow the subscriber to change its mind and tell us it now wants `.unlimited` elements.
    var newDemand = 0
    var demandedUnlimited = false
    toReceive?.forEach { element in
      let demand = subscriber.receive(element)
      demandedUnlimited = demandedUnlimited || demand == .unlimited
      newDemand += demand.max ?? 0
    }
    if (demandedUnlimited && subscriberDemand != .unlimited) || newDemand > 0 {
      serial.sync {
        if demandedUnlimited {
          subscriberDemand = .unlimited
        }
        requestedElements += newDemand
      }
      consumeFromBuffer(nil)
    }
  }
  
  public func cancel() {
    disposeBag = DisposeBag()
  }

  #if DEBUG || TEST
  deinit {
    combineSubscriptionDeinitCount += 1 // Exposed for Tests
  }
  #endif
  
}
