//
//  GetReddit.swift
//  TestRxWithSwiftUI
//
//  Created by David Zorychta on 1/4/22.
//

import Foundation

import RxCocoa
import RxSwift

struct RedditPost: Decodable, Identifiable {
  let title: String
  let url: String?
  let permalink: String
  let author: String
  let created_utc: Int
  let id: String
  
}

struct Subreddit: Decodable {
  let kind: String
  let data: SubredditData
  
}

struct SubredditData: Decodable {
  let children: [SubredditChild]
}

struct SubredditChild: Decodable {
  let data: RedditPost
}

func getReddit(_ subreddit: String) -> Observable<[RedditPost]> {
  let request = URLRequest(url: URL(string: "https://www.reddit.com/r/\(subreddit).json")!)
  return URLSession.shared.rx.data(request: request)
    .map { try JSONDecoder().decode(Subreddit.self, from: $0) }
    .map { $0.data.children.map { $0.data } }
    .observe(on: MainScheduler.asyncInstance)
}
