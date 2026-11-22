---
name: current-swiftui
description: "Use when writing or reviewing SwiftUI views, navigation, previews, formatting or Swift Testing tests: the deprecated APIs agents keep writing (many give no warning) and their replacements, and the scan that finds them."
---

# Current SwiftUI and Swift Testing

A clean build proves nothing here: many of these APIs are soft-deprecated and Xcode does not warn. Before you hand in, run `scan.sh <source dirs>` from this skill's directory over the files you changed, and fix what it prints. It is a grep, so a hit in a comment or in an `#available` fallback may be correct. Say why in your hand-in when you keep one.

## Replace on sight (in code you are writing)

| Not this | This |
|---|---|
| `NavigationView` | `NavigationStack` + `navigationDestination(for:)` |
| `.foregroundColor(` | `.foregroundStyle(` |
| `.cornerRadius(` | `.clipShape(.rect(cornerRadius:))` |
| `.tabItem {` | `Tab("…", systemImage:) { }` in `TabView` |
| `onChange(of: x) { new in` (one parameter) | `onChange(of: x) { old, new in }` or `{ }` |
| `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject` | `@Observable` with `@State` / `@Bindable` / `@Environment` |
| `PreviewProvider` | `#Preview` |
| `Task.sleep(nanoseconds:)` | `Task.sleep(for: .seconds(…))` |
| `String(format:` for display | `Text(value, format: .number…)` / `FormatStyle` |
| `UIScreen.main.bounds` | `containerRelativeFrame`, `onGeometryChange` |
| `GeometryReader` as a first resort | `containerRelativeFrame`, `visualEffect`, `onGeometryChange` |
| `AnyView` | `@ViewBuilder`, `some View`, an enum switch |
| `.onTapGesture` for an action | `Button` (VoiceOver and keyboard get it for free) |
| `DispatchQueue.main.async` | `@MainActor`, `await MainActor.run` (see skill concurrency) |

## SwiftUI rules

- `@State` is `private` and set in one place.
- In `ForEach`, identity is stable: never `.indices`, `\.offset`, or ids made inside `body`.
- `@Entry` defaults are stable values: never `Model()`, `Date()` or `UUID()`. Don't put closures in the environment.
- `body` computes nothing heavy: no sorting, filtering, formatting of large collections, or image decoding. Do that work in the model.

## Swift Testing rules

- `@Test` functions are not named `test…`. Use `@Suite` only when it carries traits or shared setup. Setup goes in `init`, not `setUp()`.
- Write `#expect(x == false)`, not `#expect(!x)`, so the failure shows the value.
- Use `#require` to unwrap and stop the test. Use `#expect` for the checks.
- `@Test(arguments: a, b)` makes a Cartesian product. Use `zip(a, b)` when cases pair up.
