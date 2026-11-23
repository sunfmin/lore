---
name: on-device-ml
description: "Use when an iOS app runs models or processes the photo library: converting and loading Core ML models, Vision requests, PhotoKit, BGProcessingTask, memory and thermal limits, and measuring speed and memory with numbers."
---

# On-device ML

## Models

- **Licenses.** Only weights whose own license, and whose training data's terms, allow commercial use. The repo's ADR lists which are allowed. A model not on it you add to that list in the same change, quoting its license and its training data's terms; one whose terms you cannot find is not used.
- **Conversion.** Use `coremltools` to a `.mlpackage`, scripted under the repo's experiments with `uv run`, the source revision pinned. Compare the Core ML output with the original framework's on the same inputs (cosine, or max probability difference) and write the number down. Measured pitfalls on ModernBERT-style encoders:
  - Never use full `int8` on the Neural Engine (outputs drift, predictions flip). Use weight-only or `int8-gather` quantization, and verify it.
  - Never run them through ONNX Runtime's CoreMLExecutionProvider: the graph splits into hundreds of partitions, runs 3-10x slower and fails above batch 1.
- **Loading.** Use `MLModel.load(contentsOf:configuration:)` asynchronously, once, from a directory passed in (downloaded assets, not the bundle, when the spec says so). Compile once with `MLModel.compileModel(at:)` and keep the `.mlmodelc` by model version. Release the model on a memory warning or when the background task ends. A missing or corrupt model is an error the caller shows, never a crash.
- **Compute units.** Choose them deliberately (`.cpuAndNeuralEngine` for encoders, `.cpuOnly` in tests). Check where operations actually land with `MLComputePlan` before claiming the Neural Engine runs them.
- **Tokenizers.** A tokenizer read from a large `tokenizer.json` can cost hundreds of MiB of peak memory (a 256k-vocabulary one measured 298 MiB). That is fine in the app's foreground process, but never in an extension.

## Vision

- Requests run off the main actor, one `VNImageRequestHandler` per image, with several requests in one `perform`. On iOS 18+ prefer Vision's Swift API (`DetectFaceRectanglesRequest`, `RecognizeTextRequest`, `CoreMLRequest`) to hand-written preprocessing.
- Coordinates are normalized with the origin at the bottom left. Convert once, in one function, with a test.
- Set recognition languages explicitly for OCR (`zh-Hans`, `en-US`, `ja-JP`, …) and `.accurate` for indexing.

## PhotoKit

- Ask for the least access that works (`PhotosPicker` when the app doesn't need the library). Handle `.limited` as a normal state.
- Never decode full resolution to index: request a sized image, or downsample with `CGImageSource` and `kCGImageSourceThumbnailMaxPixelSize`. A 48 MP photo is over 200 MB decoded. Process a bounded number at a time.
- Index incrementally from `PHPhotoLibraryChangeObserver` and persistent change tokens. Store the progress so a kill or an expiration resumes, never restarts.

## Background processing

- Every identifier goes in `BGTaskSchedulerPermittedIdentifiers`, with `UIBackgroundModes` including `processing`. Register in `App.init()`, before launch ends.
- Heavy work goes in a `BGProcessingTaskRequest` with `requiresExternalPower = true`. The handler schedules the next request, sets `expirationHandler` to cancel the work, and calls `setTaskCompleted(success:)` exactly once on every path.
- The work is a loop of small steps, each saved before the next. It checks cancellation between steps and checks `ProcessInfo.processInfo.thermalState` too: slow down at `.serious`, stop at `.critical`, and resume when it falls. Keep the policy in the package as a plain function of the state, so it is tested on the host.
- Models never run in an app extension (share, widget, keyboard). Extensions pass small metadata through the App Group.

## Measuring

- The simulator proves control flow only. Speed and memory are measured on the host (Apple silicon, same Core ML) or on a device:
  - latency as the median of repeated calls after a warm-up, with cold load measured separately;
  - peak memory with `/usr/bin/time -l` on a command-line run, or Instruments on a device.
- Post them where the issue asks (usually a comment on it).
