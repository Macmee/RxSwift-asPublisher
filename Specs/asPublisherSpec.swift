//
//  ObservableAsPublisherSpec.swift
//  ObservableAsPublisherSpec
//
//  Created by David Zorychta on 1/14/22.
//

import Combine
import Foundation
import Nimble
import Quick
import RxSwift
import RxCocoa

class InspectableObservable<T> {
  
  private let subject = PublishSubject<T>()
  private(set) var didComplete = false
  private(set) var fireCount = 0
  
  func onNext(_ element: T) {
    subject.onNext(element)
  }
  
  func onError(_ error: Error) {
    subject.onError(error)
  }
  
  func onComplete() {
    subject.onCompleted()
  }
  
  func asObservable() -> Observable<T> {
    subject
      .asObservable()
      .do(onNext: { [weak self] _ in
        self?.fireCount += 1
      }, onCompleted: { [weak self] in
        self?.didComplete = false
      })
  }
  
}

class InspectableSubscriber<T>: Subscriber {
  typealias Input = T
  typealias Failure = Error
  private var subscription: Subscription?
  private(set) var didComplete = false
  private(set) var didCompleteWithError: Error?
  private(set) var allValues: [T] = []
  private let subject = PublishSubject<T>()
  var onNextReceiveDemand: Subscribers.Demand?
  init(_ publisher: AnyPublisher<T, Error>) {
    publisher.subscribe(self)
  }
  func receive(subscription: Subscription) {
    self.subscription = subscription
  }
  func receive(_ input: T) -> Subscribers.Demand {
    subject.onNext(input)
    allValues += [input]
    defer { onNextReceiveDemand = nil }
    return onNextReceiveDemand ?? .max(0)
  }
  func receive(completion: Subscribers.Completion<Error>) {
    didComplete = true
    if case let .failure(error) = completion {
      didCompleteWithError = error
    }
  }
  func asObservable() -> Observable<T> {
    subject.asObservable()
  }
  func demand(_ demand: Subscribers.Demand) {
    subscription?.request(demand)
  }
}

struct FakeError: Error {}

class ObservableAsPublisherSpec: QuickSpec {
  
  override func spec() {
    describe("An Observable") {
      context("When converted to a publisher") {

        it("should produce events observable to a sink call") {
          let beforeDeinitCount = combineSubscriptionDeinitCount
          var bag = Set<AnyCancellable>()
          let chain = InspectableObservable<Int>()
          var gotValue: Int?
          var finished = false
          chain
            .asObservable()
            .asPublisher()
            .sink(receiveCompletion: { _ in
              finished = true
            }, receiveValue: { value in
              gotValue = value
            })
            .store(in: &bag)
          chain.onNext(1)
          expect(gotValue).toEventually(equal(1), timeout: .seconds(3))
          expect(finished).to(equal(false))
          chain.onNext(2)
          expect(gotValue).toEventually(equal(2), timeout: .seconds(3))
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            chain.onNext(3)
          }
          expect(gotValue).toEventually(equal(3), timeout: .seconds(3))
          expect(finished).to(equal(false))
          chain.onComplete()
          expect(finished).toEventually(equal(true), timeout: .seconds(3))
          expect(chain.fireCount).to(equal(3))
          bag = Set()
          expect(beforeDeinitCount + 1).toEventually(equal(combineSubscriptionDeinitCount), timeout: .seconds(1))
        }
        
        it("should produce detectable errors from the combine side") {
          var bag = Set<AnyCancellable>()
          let chain = InspectableObservable<Int>()
          var gotValue: Int?
          var finished = false
          chain
            .asObservable()
            .asPublisher()
            .sink(receiveCompletion: { _ in
              finished = true
            }, receiveValue: { value in
              gotValue = value
            })
            .store(in: &bag)
          let beforeDeinitCount = combineSubscriptionDeinitCount
          chain.onError(FakeError())
          expect(finished).toEventually(equal(true), timeout: .seconds(3))
          expect(gotValue).to(beNil())
          expect(chain.fireCount).to(equal(0))
          expect(beforeDeinitCount + 1).toEventually(equal(combineSubscriptionDeinitCount), timeout: .seconds(3))
        }
        
        it("should dispose on completion") {
          var bag = Set<AnyCancellable>()
          let chain = InspectableObservable<Int>()
          var gotValue: Int?
          var finished = false
          chain
            .asObservable()
            .asPublisher()
            .sink(receiveCompletion: { _ in
              finished = true
            }, receiveValue: { value in
              gotValue = value
            })
            .store(in: &bag)
          let beforeDeinitCount = combineSubscriptionDeinitCount
          chain.onNext(1)
          chain.onComplete()
          expect(finished).toEventually(equal(true))
          expect(gotValue).toEventually(equal(1))
          expect(chain.fireCount).to(equal(1))
          expect(beforeDeinitCount + 1).toEventually(equal(combineSubscriptionDeinitCount), timeout: .seconds(1))
        }
        
        it("should not propagate values after completion") {
          var bag = Set<AnyCancellable>()
          let chain = InspectableObservable<Int>()
          var gotValue: Int?
          var finished = false
          chain
            .asObservable()
            .asPublisher()
            .sink(receiveCompletion: { _ in
              finished = true
            }, receiveValue: { value in
              gotValue = value
            })
            .store(in: &bag)
          let beforeDeinitCount = combineSubscriptionDeinitCount
          chain.onComplete()
          chain.onNext(1)
          expect(finished).toEventually(equal(true))
          expect(gotValue).to(beNil())
          expect(chain.fireCount).to(equal(0))
          expect(beforeDeinitCount + 1).toEventually(equal(combineSubscriptionDeinitCount), timeout: .seconds(1))
        }
        
        it("should respect demand both .max(Int) and .unlimited") {
          let chain = InspectableObservable<Int>()
          var subscription: InspectableSubscriber<Int>? = InspectableSubscriber(chain.asObservable().asPublisher())
          // make sure the internal buffer releases elements as demand changes
          chain.onNext(1)
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            chain.onNext(2)
          }
          subscription?.demand(.max(1))
          expect(subscription?.allValues).toEventually(equal([1]), timeout: .seconds(1))
          subscription?.demand(.max(1))
          expect(subscription?.allValues).toEventually(equal([1, 2]), timeout: .seconds(3))
          subscription?.demand(.max(3))
          // make sure no values get duplicated after we increase demand even more and wait abit
          var deferred = [Int]()
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            deferred = subscription?.allValues ?? []
          }
          expect(deferred).toEventually(equal([1, 2]), timeout: .seconds(1))
          // blast 5 elements and make sure we only get the first 3 since thats how much demand increased
          chain.onNext(3)
          chain.onNext(4)
          chain.onNext(5)
          chain.onNext(6)
          chain.onNext(7)
          expect(subscription?.allValues).toEventually(equal([1, 2, 3, 4, 5]))
          // and the last two should come once we set ourselves to unlimited mode
          subscription?.demand(.unlimited)
          expect(subscription?.allValues).toEventually(equal([1, 2, 3, 4, 5, 6, 7]))
        }

      }
    }
  }
  
}
