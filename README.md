1. we have an `Observable<[RedditPost]>` feed of /r/earthporn
2. we have a SwiftUI component `SubredditView(redditFeed:)` where `redditFeed` is expected to be a publisher in Combine
3. we create `Observable+asPublisher.swift` that creates a new publisher out of an observable

**NOTE**: Source code lives in the `Shared/` folder

![demo](https://i.imgur.com/0iC55e9.png)
