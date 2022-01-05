//
//  SubredditView.swift
//  Shared
//
//  Created by David Zorychta on 1/4/22.
//

import Combine
import SwiftUI
import RxSwift

struct PostRow: View {
  let post: RedditPost
  var body: some View {
    HStack(alignment: .center, spacing: 15) {
      if let urlStr = post.url, let url = URL(string: urlStr) {
        AsyncImage(url: url) { phase in
          switch phase {
          case .empty:
            ProgressView()
              .frame(width: 64, height: 64)
          case .failure:
            Image(systemName: "photo")
              .frame(width: 64, height: 64)
          case .success(let image):
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: 64, height: 64)
              .cornerRadius(10)
          @unknown default:
            Image(systemName: "photo")
          }
        }
      }
      Text(post.title)
    }.onTapGesture {
      UIApplication.shared.open(URL(string: "https://reddit.com\(post.permalink)")!)
    }
  }
}

struct SubredditView: View {
  var redditFeed: AnyPublisher<[RedditPost], Error>
  @State private var posts = [RedditPost]()
    var body: some View {
      List(posts) {
        PostRow(post: $0)
      }
      .onReceive(redditFeed.assertNoFailure()) {
        posts = $0
      }
      .onAppear() {
        UITableView.appearance().contentInset.top = -35
      }
    }
}
