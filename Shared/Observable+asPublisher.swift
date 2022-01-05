//
//  Observable+asPublisher.swift
//  TestRxWithSwiftUI
//
//  Created by David Zorychta on 1/5/22.
//

import Foundation
import Combine
import RxSwift

extension Observable {
  
  class CombineSubscription<Target: Subscriber>: Subscription where Target.Input == Element {
    var disposeBag = DisposeBag()
    func request(_ demand: Subscribers.Demand) {}
    func cancel() {
      disposeBag = DisposeBag()
    }
  }

  struct CombinePublisher: Publisher {
    
    typealias Output = Element
    typealias Failure = Error
    
    let observable: Observable<Element>
    
    func receive<S>(subscriber: S) where S : Subscriber, Error == S.Failure, Element == S.Input {
      let subscription = CombineSubscription<S>()
      subscriber.receive(subscription: subscription)
      observable
        .subscribe(
          onNext: { subscriber.receive($0) },
          onError: {
            subscriber.receive(completion: .failure($0))
            subscription.disposeBag = DisposeBag()
          },
          onCompleted: {
            subscriber.receive(completion: .finished)
            subscription.disposeBag = DisposeBag()
          }
        )
        .disposed(by: subscription.disposeBag)
        
    }
    
  }
  
  public func asPublisher() -> AnyPublisher<Element, Error> {
    CombinePublisher(observable: self.asObservable()).eraseToAnyPublisher()
  }
  
}
