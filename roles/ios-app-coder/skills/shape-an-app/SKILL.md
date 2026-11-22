---
name: shape-an-app
description: "Use before writing code for a new screen, a new kind of data, a new model or pipeline stage, or a change to what an iOS app stores: where logic, views, models and the store go."
---

# Shaping an app

## Logic apart from views

- The logic lives in a local Swift package of the repo whose platforms include macOS, and which imports no SwiftUI or UIKit. Foundation, Core ML, Vision, Accelerate, CoreImage, ImageIO and SQLite3 are fine there: they all run on the host. The app target depends on the package and adds only views, the app's entry point and the iOS-only edges (PhotoKit, `BGTaskScheduler`, Background Assets), each behind a protocol the package defines. A new repo starts this way. An existing repo moves logic out only as far as its issue needs.
- A module earns its place by depth: much deciding behind few public types. Ask: if it were gone, would every caller re-decide what it decides? If not, fold it in.
- Pass in what varies: the date as a clock, randomness as a generator, the store as a value its caller makes, model files as a directory URL. A function that reads `Date.now` itself cannot be tested at midnight.
- A screen with state worth testing gets one `@Observable` model, `@MainActor` (unless the target's default isolation already is). It is owned with `@State` at the screen that creates it and passed down with `@Bindable` or `@Environment`. Its methods are the intents the view sends, each one line in the view's button or gesture. A screen that only shows a value needs no model. Why: the model is the seam a host test reaches, and a model with nothing to decide is ceremony.
- A rule the app keeps (a count never negative, a name never empty) is a type whose only initializer checks it, so nothing past the edge has to check it again.

## Data on the device

- Storing is one module's job. Pick the least that holds the issue's data, and record the choice in an ADR when it is new:
  - SwiftData for records the app queries through views;
  - a `Codable` file in Application Support for a small document;
  - SQLite (the system `SQLite3` module) for large indexes, progress tables or anything the spec names it for;
  - a memory-mapped flat file for vectors;
  - `@AppStorage` for a setting.
- A write is whole: a file is written with `.atomic` or written beside the old one and renamed, a SwiftData change is saved in one context save, an SQLite change is made in one transaction. A kill leaves the old data or the new.
- The store opens in memory, or in a temporary directory, for tests and previews, through the same code path the app uses. It is the real store, not a mock.
- Data a user kept survives every update. A store is versioned from its first release: a SwiftData `VersionedSchema` with a `SchemaMigrationPlan`, a `user_version` and migrations for SQLite, a format version field in a file. A changed type is a new version with a migration, and a test opens a store written by the version before. Never change a stored type in place.
- What a user did by hand (named, merged, corrected) is kept apart from what the app computed, and no recomputation overwrites it.

## The project

- A new app target uses folder-synchronized groups, so a new Swift file needs no edit to the project file. The project file changes only for a target, a setting or a scheme, and is committed with the change that needs it.
- Use one main type per file, with files in folders by feature. The shared scheme the gate builds is committed, and its test action lists every test target the gate must run, a local package's too, since xcodebuild runs only the tests its scheme names.
- Keep the deployment target and Swift version as the project has them. A newer API goes behind `#available` or waits for the issue that raises the target.
