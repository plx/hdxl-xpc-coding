import Foundation

// MARK: - IPC Message Types

/// A request message for IPC benchmarks.
struct BenchmarkRequest: Codable, Equatable, Sendable {
  let requestId: UUID
  let timestamp: Date
  let operation: String
  let payload: Data

  static func example(payloadSize: Int = 1000) -> BenchmarkRequest {
    BenchmarkRequest(
      requestId: UUID(),
      timestamp: Date(),
      operation: "benchmark_roundtrip",
      payload: Data(repeating: 0xAA, count: payloadSize)
    )
  }
}

/// A response message for IPC benchmarks.
struct BenchmarkResponse: Codable, Equatable, Sendable {
  let requestId: UUID
  let timestamp: Date
  let success: Bool
  let result: Data

  static func forRequest(_ request: BenchmarkRequest, resultSize: Int = 1000) -> BenchmarkResponse {
    BenchmarkResponse(
      requestId: request.requestId,
      timestamp: Date(),
      success: true,
      result: Data(repeating: 0xBB, count: resultSize)
    )
  }
}

// MARK: - Message Size Variants

enum MessageSize: String, CaseIterable {
  case tiny = "tiny"     // ~100 bytes
  case small = "small"   // ~1KB
  case medium = "medium" // ~10KB
  case large = "large"   // ~100KB

  var payloadSize: Int {
    switch self {
    case .tiny: return 100
    case .small: return 1_000
    case .medium: return 10_000
    case .large: return 100_000
    }
  }
}

// MARK: - Complex IPC Message

/// A more complex message type that mimics real-world IPC scenarios.
struct IPCCommand: Codable, Equatable, Sendable {
  let commandId: UUID
  let timestamp: Date
  let source: SenderInfo
  let command: CommandType
  let arguments: [String: ArgumentValue]
  let data: Data?
}

struct SenderInfo: Codable, Equatable, Sendable {
  let pid: Int32
  let name: String
  let bundleId: String?
}

enum CommandType: String, Codable, Sendable {
  case query
  case execute
  case subscribe
  case unsubscribe
  case ping
}

enum ArgumentValue: Codable, Equatable, Sendable {
  case string(String)
  case int(Int)
  case double(Double)
  case bool(Bool)
  case data(Data)
  case array([ArgumentValue])
}

extension IPCCommand {
  static func pingCommand() -> IPCCommand {
    let processInfo = Foundation.ProcessInfo.processInfo
    return IPCCommand(
      commandId: UUID(),
      timestamp: Date(),
      source: SenderInfo(
        pid: processInfo.processIdentifier,
        name: processInfo.processName,
        bundleId: Bundle.main.bundleIdentifier
      ),
      command: .ping,
      arguments: [:],
      data: nil
    )
  }

  static func queryCommand(withDataSize size: Int) -> IPCCommand {
    let processInfo = Foundation.ProcessInfo.processInfo
    return IPCCommand(
      commandId: UUID(),
      timestamp: Date(),
      source: SenderInfo(
        pid: processInfo.processIdentifier,
        name: processInfo.processName,
        bundleId: Bundle.main.bundleIdentifier
      ),
      command: .query,
      arguments: [
        "filter": .string("active"),
        "limit": .int(100),
        "includeMetadata": .bool(true)
      ],
      data: Data(repeating: 0xCC, count: size)
    )
  }
}

struct IPCResponse: Codable, Equatable, Sendable {
  let commandId: UUID
  let timestamp: Date
  let status: ResponseStatus
  let result: ResultData?
  let error: ErrorInfo?
}

enum ResponseStatus: String, Codable, Sendable {
  case success
  case failure
  case pending
}

struct ResultData: Codable, Equatable, Sendable {
  let type: String
  let value: Data
  let metadata: [String: String]
}

struct ErrorInfo: Codable, Equatable, Sendable {
  let code: Int
  let message: String
  let domain: String
}

extension IPCResponse {
  static func successResponse(for command: IPCCommand, resultSize: Int) -> IPCResponse {
    IPCResponse(
      commandId: command.commandId,
      timestamp: Date(),
      status: .success,
      result: ResultData(
        type: "benchmark",
        value: Data(repeating: 0xDD, count: resultSize),
        metadata: ["processed": "true", "version": "1.0"]
      ),
      error: nil
    )
  }
}
