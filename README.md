As Combine and SwiftUI both mature, projects that want to embrace these frameworks may need to bridge between RxSwift Observables and Combine Publishers. This repository adds such a bridge by adding an `asPublisher()` extension onto `ObservableConvertibleType`.

1. The problem: You're building a reddit client that shows a feed of /r/pics posts, and you have an `postsObservable` RxObservable of type `Observable<[RedditPost]>` 
2. you have a SwiftUI component `SubredditView(redditFeed:)` where `redditFeed` is expected to be a Combine Publisher
3. you can now create your component using `SubredditView(redditFeed: postsObservable.asPublisher())`

**NOTE**: Source code for this project lives in the `Shared/` folder.

![demo](https://i.imgur.com/0iC55e9.png)
