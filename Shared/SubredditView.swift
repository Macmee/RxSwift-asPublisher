//
//  SubredditView.swift
//  Shared
//
//  Created by David Zorychta on 1/4/22.
//

import Combine
import SwiftUI
import RxCocoa
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

class SubredditViewModel: ObservableObject {
  
  // MARK: - Inputs
  @Published var subredditInput: String
  
  // MARK: - Outputs
  @Published var postsOutput: [RedditPost] = []
  
  // MARK: - Privates
  private var cancellableSet = Set<AnyCancellable>()
  
  init(startingSubreddit: String) {
    subredditInput = startingSubreddit
    $subredditInput
      .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
      .map { subreddit in
        getReddit(subreddit).asPublisher()
      }
      .switchToLatest()
      .replaceError(with: [])
      .assign(to: \.postsOutput, on: self)
      .store(in: &self.cancellableSet)
  }
  
}

struct SubredditView: View {
  
  private enum Constant {
    static let titlePrefix = "/r/"
    static let titlePlaceholder = "Subreddit"
    static let titleBackground = Color(red: 43/255, green: 53/255, blue: 53/255)
  }

  @ObservedObject var viewModel: SubredditViewModel
  
  init(viewModel: SubredditViewModel) {
    self.viewModel = viewModel
  }
  
  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .center, spacing: 0) {
        Spacer()
        Text(Constant.titlePrefix).foregroundColor(.white)
        TextField(Constant.titlePlaceholder, text: $viewModel.subredditInput)
          .foregroundColor(.white)
          .frame(maxWidth: 100)
        Spacer()
      }.frame(minHeight: 40)
        .background(Constant.titleBackground)
      List(viewModel.postsOutput) {
        PostRow(post: $0)
      }
      .onAppear() {
        UITableView.appearance().contentInset.top = -20
      }
    }
  }
}
