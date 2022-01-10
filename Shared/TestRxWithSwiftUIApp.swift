//
//  TestRxWithSwiftUIApp.swift
//  Shared
//
//  Created by David Zorychta on 1/4/22.
//

import SwiftUI

@main
struct TestRxWithSwiftUIApp: App {
  var body: some Scene {
    WindowGroup {
      SubredditView(
        viewModel: SubredditViewModel(startingSubreddit: "EarthPorn")
      )
    }
  }
}
