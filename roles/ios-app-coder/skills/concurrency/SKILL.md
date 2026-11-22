---
name: concurrency
description: "Use when writing or fixing async code, actors, tasks, Sendable errors or anything shared across threads in Swift 6: read the project's settings first, the bug patterns agents write, and what never silences an error."
---

# Swift 6 concurrency

## First, read the settings

Read the language mode, the strict-concurrency level, the default isolation (`defaultIsolation(MainActor.self)` in Package.swift, `SWIFT_DEFAULT_ACTOR_ISOLATION` in the project) and whether `NonisolatedNonsendingByDefault` is on. Read them from the repo, never guess, never ask. They decide whether a type is already `@MainActor` and where a nonisolated `async` function runs. With nonisolated-nonsending, it runs on the caller's actor, so CPU work in it blocks the UI.

## Where work runs

- UI state lives on the main actor. Heavy work goes off it: mark it `@concurrent`, or run it in an actor that owns the resource (a model, a database connection). Use `Task.detached` only with a comment saying why.
- Never fix an error with a blanket `@MainActor` on a type that does real work. The error is telling you that work and state are on the wrong side.
- A resource with one owner is an actor: a loaded `MLModel`, an SQLite connection, a file being written. Callers await it. Load it once and share the instance.
- Many items in parallel go through a `TaskGroup` (or `withDiscardingTaskGroup`) with a bound on how many run at once, never a `Task {}` per item in a loop. Many full-size images decoded at once exhaust memory.

## Bugs agents write

- **Reentrancy:** an actor method that checks state, `await`s, then acts on what it checked. The state may have changed during the `await`. Check again after it, or do the check and the act with no `await` between.
- **Continuations:** a `withCheckedContinuation` must resume exactly once on every path, including errors and cancellation.
- **Swallowed errors:** a `Task { try … }` whose error nobody reads. Handle the error inside the task, or keep the task and await its value.
- **Cancellation ignored:** long loops call `try Task.checkCancellation()` (or check `Task.isCancelled`) between items, so a background expiration or a dismissed screen actually stops the work.
- **Unbounded streams:** an `AsyncStream` fed faster than it is read needs a `bufferingPolicy`.
- **GCD mixed with async:** no `DispatchQueue` or semaphores in new code. Old interop code keeps it only behind one function.

## Never, to silence the checker

`@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency import`, lowering the language mode or the strict-concurrency level, `MainActor.assumeIsolated` where you are not sure. When one is truly right (a lock-protected type, an Apple type not yet annotated), it carries a comment stating the invariant that makes it safe, and a test that exercises it from several tasks.
